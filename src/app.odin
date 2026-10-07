#+feature dynamic-literals

package png_tuber

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:net"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:thread"
import ma "vendor:miniaudio"
import rl "vendor:raylib"
import "rlui"

PORT := 9001
command_mutex: sync.Mutex

IpcCommand :: struct {
	command: string,
	content: string,
}

ipc_commands: [dynamic]IpcCommand

AppScene :: enum {
	Menu,
	Png_Tuber,
	Editor,
}

AppRigData :: struct {
	sections: map[string]AppSectionData,
}

clear_rig_data :: proc(rd: ^AppRigData) {
	clear(&rd.sections)
}

delete_rig_data :: proc(rd: ^AppRigData) {
	delete(rd.sections)
}

AppSectionData :: struct {
	cur_transformer:        Transformer,
	cur_velocities:         TransformerVelocities,
	rand_transformers:      [2]Transformer,
	cur_volume_transformer: Transformer,
	cur_volume_velocities:  TransformerVelocities,
	tint:                   rl.Color,
	total_velocities:       TransformerVelocities, // current velocity speed
}

App :: struct {
	scene:       AppScene,
	settings:    ^Settings,
	muted:       bool,
	running:     bool,
	rig_data:    AppRigData,
	rig_status:  RigStatus,
	frame_lib:   TextureLib,
	loaded_rig:  ^Rig,
	time_speed:  f32,
	editor_data: EditorData,
}

new_app :: proc() -> ^App {
	app: ^App = new(App)
	app.scene = .Menu
	app.running = true
	app.time_speed = 1.0
	app.rig_status = default_rig_status()
	app.settings = default_settings()
	return app
}

delete_app :: proc(app: ^App) {
	if app.settings != nil {
		delete_settings(app.settings)
	}
	if app.loaded_rig != nil {
		delete_rig(app.loaded_rig)
		delete_rig_data(&app.rig_data)
	}
	delete_frame_lib(&app.frame_lib)
	delete_rig_status(&app.rig_status)
	delete_editor_data(&app.editor_data)
	free(app)
}

AppCommand :: enum {
	Load_Rig,
	Save_Rig,
	Increment_Save_Rig,
	Change_Scene,
	Rig_Command,
	Edit_Select_Section,
	Mute,
	Unmute,
	Toggle_Mute,
}

app_command :: proc(app: ^App, command: AppCommand, payload: string) {
	switch command {
	case .Load_Rig:
		app_load_rig(app, payload)
	case .Save_Rig:
		app_save_rig(app, payload)
	case .Increment_Save_Rig:
		app_incremental_save(app, payload)
	case .Change_Scene:
		app_change_scene(app, payload)
	case .Rig_Command:
		app_rig_command(app, payload)
	case .Edit_Select_Section:
		app_edit_select_section(app, payload)
	case .Mute:
		app.muted = true
	case .Unmute:
		app.muted = false
	case .Toggle_Mute:
		app.muted = !app.muted
	}
}

app_load_rig :: proc(app: ^App, path: string) {
	rig, ok := load_rig(path)
	if !ok {
		return
	}
	if app.loaded_rig != nil {
		delete_rig(app.loaded_rig)
		clear_frame_lib(&app.frame_lib)
		clear_rig_data(&app.rig_data)
		clear_rig_status(&app.rig_status)
	}
	app.loaded_rig = rig
	load_textures(&app.frame_lib, rig)
	prepare_rig_status(&app.rig_status, app.loaded_rig)
	for section_name, _ in app.loaded_rig.sections {
		app.rig_data.sections[section_name] = AppSectionData{}
	}
	fix_rig_frames(app.loaded_rig, &app.frame_lib.textures)
	#partial switch app.scene {
	case .Png_Tuber:
		rig_rect := get_rig_rect(app.loaded_rig)
		rl.SetWindowSize(math.max(i32(rig_rect.width), 100), math.max(i32(rig_rect.height), 100))
	case .Editor:
		rig_rect := get_rig_rect(app.loaded_rig)
		rl.SetWindowSize(
			math.max(i32(rig_rect.width) + 200, 100),
			math.max(i32(rig_rect.height) + 50, 100),
		)

		clear_editor_data(&app.editor_data)
		prepare_editor_data(app.loaded_rig, &app.editor_data)
	}
}

app_save_rig :: proc(app: ^App, path: string) {
	if app.loaded_rig != nil {
		save_rig(app.loaded_rig, path)
	}
}

app_incremental_save :: proc(app: ^App, path: string) {
	if app.loaded_rig != nil {
		incremental_save_rig(app.loaded_rig, path)
	}
}

app_change_scene :: proc(app: ^App, scene: string) {
	scene_enum, ok := reflect.enum_from_name(AppScene, scene)

	if ok {
		app.scene = scene_enum

		#partial switch scene_enum {
		case .Png_Tuber:
			if app.loaded_rig == nil {
				break
			}
			rig_rect := get_rig_rect(app.loaded_rig)
			rl.SetWindowSize(
				math.max(i32(rig_rect.width), 100),
				math.max(i32(rig_rect.height), 100),
			)
		case .Editor:
			if app.loaded_rig == nil {
				break
			}
			rig_rect := get_rig_rect(app.loaded_rig)
			rl.SetWindowSize(
				math.max(i32(rig_rect.width) + 200, 100),
				math.max(i32(rig_rect.height) + 50, 100),
			)

			clear_editor_data(&app.editor_data)
			prepare_editor_data(app.loaded_rig, &app.editor_data)
		}

		reload_textures(&app.rig_status)
	}
}

app_edit_select_section :: proc(app: ^App, section: string) {
	ok := section in app.loaded_rig.sections
	if ok {
		if rl.IsKeyDown(.LEFT_SHIFT) {
			if !slice.contains(app.editor_data.selected_sections[:], section) {
				append(&app.editor_data.selected_sections, section)
			}
		} else {
			clear(&app.editor_data.selected_sections)
			append(&app.editor_data.selected_sections, section)
		}
	}
}
/*app_edit_center_over_selection :: proc(app: ^App){
	section_name := app.editor_data.selected_section
	section, ok := app.loaded_rig.sections[section_name]
	if !ok || len(section.frames) == 0{
		return
	}

	frame_id := app.editor_data.cur_frame[section_name]
	
	frame_name := section.frames[frame_id]
	frame, f_ok := app.loaded_rig.frames[frame_name]

	if !f_ok{
		return
	}

	frame_position := frame.transform.position

	already_transformed := make([]string, len(app.loaded_rig.frames))
	i := 0

	for s_name, section in app.loaded_rig.sections{
		if is_section_following_section(app.loaded_rig, s_name, section_name){
			continue
		}
		for f_name in section.frames{
			if slice.contains(already_transformed, f_name){
				continue
			}
			frame, ok := &app.loaded_rig.frames[f_name]
			frame.transform.position -= frame_position
		}
	}

	for f_name, &frame in app.loaded_rig.frames{
		frame.transform.position -= frame_position
	}
}*/

app_rig_command :: proc(app: ^App, command: string) {
	commands := parse_command(command)
	defer delete_rig_commands(&commands)
	for &command in commands {
		run_rig_command(app.loaded_rig, &app.rig_status, &command)
	}
}

app_process :: proc(app: ^App, delta: f32) {
	switch app.scene {
	case .Menu:
	case .Png_Tuber:
		app_process_png_tuber(app, delta)
	case .Editor:
		app_process_editor(app, delta)
	}
}

app_process_png_tuber :: proc(app: ^App, delta: f32) {
	changed_sections := process_rig_status(&app.rig_status, app.loaded_rig, delta)
	defer {
		delete(changed_sections)
	}
	for section_name in changed_sections {
		section := &app.rig_data.sections[section_name]

		cur_frame, frame_ok := get_frame(
			app.loaded_rig,
			section_name,
			app.rig_status.cur_frame[section_name],
		)

		if !frame_ok {
			continue
		}

		next_frame, _ := get_frame(
			app.loaded_rig,
			section_name,
			app.rig_status.cur_frame[section_name] + 1,
		)

		app_data_section := &app.rig_data.sections[section_name]

		app_data_section.rand_transformers[0] = app_data_section.rand_transformers[1]
		app_data_section.rand_transformers[1] = colapse_rand_transformer(
			&next_frame.rand_transform,
		)
	}
}

app_process_editor :: proc(app: ^App, delta: f32) {
	// Collect all required data
	f_ok: bool = false

	mouse_position := rl.GetMousePosition()
	if len(app.editor_data.selected_sections) == 1 {
		section_name := app.editor_data.selected_sections[0]
		section, s_ok := &app.loaded_rig.sections[section_name]
		section_frame_id := app.editor_data.cur_frame[section_name]
		frame_name: string = ""
		frame: ^Frame = nil
		position_anchor: la.Vector2f32
		editor_anchor_offset: la.Vector2f32

		if s_ok && len(section.frames) != 0 {
			frame_name = section.frames[section_frame_id]
			frame, f_ok = &app.loaded_rig.frames[frame_name]

			position_anchor :=
				math_anchor_position(
					f32(rl.GetScreenWidth()),
					f32(rl.GetScreenHeight()),
					section.window_anchor,
				) -
				math_anchor_position(
					frame.transform.width,
					frame.transform.height,
					section.transform_anchor,
				) +
				section.window_anchor_offset

			editor_anchor_offset :=
				la.Vector2f32{1.0, 1.0} - math_anchor_position(1.0, 1.0, section.transform_anchor)

			parent_transform := get_section_follow_position(
				app.loaded_rig,
				section_name,
				&app.editor_data.cur_frame,
			)

			position_anchor +=
				editor_anchor_offset * app.editor_data.editor_border + parent_transform

			app.editor_data.frame_rect = rl.Rectangle {
				frame.transform.position.x + position_anchor.x,
				frame.transform.position.y + position_anchor.y,
				frame.transform.width,
				frame.transform.height,
			}

			if app.editor_data.is_frame_moving {
				app.editor_data.frame_rect.x += app.editor_data.mouse_transform.x
				app.editor_data.frame_rect.y += app.editor_data.mouse_transform.y
			}
		}
	} else if len(app.editor_data.selected_sections) > 1 {
		min_x, min_y, max_x, max_y: f32 = 9999, 9999, 0, 0

		for section_name in app.editor_data.selected_sections {
			section, s_ok := &app.loaded_rig.sections[section_name]
			section_frame_id := app.editor_data.cur_frame[section_name]
			frame_name: string = ""
			frame: ^Frame = nil
			position_anchor: la.Vector2f32
			editor_anchor_offset: la.Vector2f32

			if s_ok && len(section.frames) != 0 {
				frame_name = section.frames[section_frame_id]
				new_f_ok: bool
				frame, new_f_ok = &app.loaded_rig.frames[frame_name]
				f_ok = f_ok | new_f_ok

				position_anchor :=
					math_anchor_position(
						f32(rl.GetScreenWidth()),
						f32(rl.GetScreenHeight()),
						section.window_anchor,
					) -
					math_anchor_position(
						frame.transform.width,
						frame.transform.height,
						section.transform_anchor,
					) +
					section.window_anchor_offset

				editor_anchor_offset :=
					la.Vector2f32{1.0, 1.0} -
					math_anchor_position(1.0, 1.0, section.transform_anchor)

				parent_transform := get_section_follow_position(
					app.loaded_rig,
					section_name,
					&app.editor_data.cur_frame,
				)

				position_anchor +=
					editor_anchor_offset * app.editor_data.editor_border + parent_transform

				f_min_x := frame.transform.position.x + position_anchor.x
				f_min_y := frame.transform.position.y + position_anchor.y
				f_max_x := f_min_x + frame.transform.width
				f_max_y := f_min_y + frame.transform.height

				if app.editor_data.is_frame_moving {
					f_min_x += app.editor_data.mouse_transform.x
					f_min_y += app.editor_data.mouse_transform.y
				}

				if f_min_x < min_x {min_x = f_min_x}
				if f_min_y < min_y {min_y = f_min_y}
				if f_max_x > max_x {max_x = f_max_x}
				if f_max_y > max_y {max_y = f_max_y}
			}
		}

		app.editor_data.frame_rect = {min_x, min_y, max_x - min_x, max_y - min_y}
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		if f_ok &&
		   mouse_position.x > app.editor_data.editor_border.x &&
		   mouse_position.y > app.editor_data.editor_border.y &&
		   !app.editor_data.is_anchor_moving {

			if is_position_in_rect(mouse_position, app.editor_data.frame_rect) {
				app.editor_data.is_frame_moving = true
			} else {
				clear(&app.editor_data.selected_sections)
			}
		}
	}

	if rl.IsMouseButtonPressed(.RIGHT) &&
	   f_ok &&
	   mouse_position.x > app.editor_data.editor_border.x &&
	   mouse_position.y > app.editor_data.editor_border.y &&
	   !app.editor_data.is_frame_moving &&
	   len(app.editor_data.selected_sections) == 1 {

		if is_position_in_rect(mouse_position, app.editor_data.frame_rect) {
			app.editor_data.is_anchor_moving = true
		}
	}

	if app.editor_data.is_frame_moving {
		app.editor_data.mouse_transform += rl.GetMouseDelta()
	}
	if app.editor_data.is_anchor_moving {
		app.editor_data.mouse_transform = rl.GetMousePosition()
	}

	if (rl.IsMouseButtonReleased(.LEFT) ||
		   mouse_position.x <= app.editor_data.editor_border.x ||
		   mouse_position.y <= app.editor_data.editor_border.y) &&
	   app.editor_data.is_frame_moving {

		action: MoveFramesAction = MoveFramesAction{}
		for section_name in app.editor_data.selected_sections {
			is_child := false

			for checked_section in app.editor_data.selected_sections {
				if is_section_following_section(app.loaded_rig, section_name, checked_section) {
					is_child = true
					break
				}
			}

			if is_child {
				continue
			}

			if rl.IsKeyDown(.LEFT_CONTROL) {
				section := app.loaded_rig.sections[section_name]
				for frame_name in section.frames {
					action.frames[frame_name] = app.editor_data.mouse_transform
				}
				app_data_section := &app.rig_data.sections[section_name]
				app_data_section.cur_transformer.position += app.editor_data.mouse_transform
			} else {
				section_frame_id := app.editor_data.cur_frame[section_name]
				rig_section := app.loaded_rig.sections[section_name]
				frame_name := rig_section.frames[section_frame_id]
				action.frames[frame_name] = app.editor_data.mouse_transform
				app_data_section := &app.rig_data.sections[section_name]
				app_data_section.cur_transformer.position += app.editor_data.mouse_transform
			}
		}
		make_action(app, action)
		app.editor_data.mouse_transform = {0.0, 0.0}
		app.editor_data.is_frame_moving = false
	}

	if rl.IsMouseButtonReleased(.RIGHT) &&
	   app.editor_data.is_anchor_moving &&
	   len(app.editor_data.selected_sections) == 1 {
		frame, ok := get_frame(
			app.loaded_rig,
			app.editor_data.selected_sections[0],
			app.editor_data.cur_frame[app.editor_data.selected_sections[0]],
		)

		if ok {
			section_name := app.editor_data.selected_sections[0]
			section := &app.loaded_rig.sections[section_name]

			editor_anchor_offset :=
				la.Vector2f32{1.0, 1.0} - math_anchor_position(1.0, 1.0, section.transform_anchor)

			offset := editor_anchor_offset * app.editor_data.editor_border

			cur_frame_id := app.editor_data.cur_frame[app.editor_data.selected_sections[0]]

			transform_anchor_position, ok := get_frame_anchor_position(
				app,
				app.editor_data.selected_sections[0],
				u32(cur_frame_id),
				offset,
			)

			if ok {
				difference := app.editor_data.mouse_transform - transform_anchor_position
				section.transform_anchor_offset += difference
			}
		}

		app.editor_data.mouse_transform = {0.0, 0.0}
		app.editor_data.is_anchor_moving = false
	}

	mouse_wheel := rl.GetMouseWheelMove()
	if mouse_wheel != 0 {
		if is_position_in_rect(mouse_position, app.editor_data.frame_lib_rect) {
			app.editor_data.frame_lib_offset = math.max(
				app.editor_data.frame_lib_offset - mouse_wheel * app.settings.scroll_speed,
				0,
			)
		}

		if is_position_in_rect(mouse_position, app.editor_data.sections_rect) {
			app.editor_data.sections_offset = math.max(
				app.editor_data.sections_offset - mouse_wheel * app.settings.scroll_speed,
				0,
			)
		}
	}

	if rl.IsKeyDown(.LEFT_CONTROL) {
		if rl.IsKeyPressed(.Z) {
			undo_action(app)
		} else if rl.IsKeyPressed(.Y) {
			redo_action(app)
		}

		if rl.IsKeyDown(.LEFT_SHIFT) {
			if rl.IsKeyPressed(.S) {
				app_incremental_save(app, app.loaded_rig.rig_path)
			}
		}
	}
}

app_draw :: proc(app: ^App, delta: f32) {
	switch app.scene {
	case .Menu:
		draw_menu(app)
	case .Png_Tuber:
		draw_png_tuber(app, delta)
	case .Editor:
		draw_editor(app, delta)
	}
}

draw_menu :: proc(app: ^App) {
	start_rect := rl.Rectangle{f32(rl.GetScreenWidth()) / 2.0 - 75, 20, 150, 40}
	editor_rect := rl.Rectangle{f32(rl.GetScreenWidth()) / 2.0 - 75, 80, 150, 40}

	rl.BeginTextureMode(app.rig_status.final_texture)
	start_button := rl.GuiButton(start_rect, "Start")
	editor_button := rl.GuiButton(editor_rect, "Editor")
	rl.EndTextureMode()

	if start_button {
		app_command(app, .Change_Scene, "Png_Tuber")
	} else if editor_button {
		app_command(app, .Change_Scene, "Editor")
	}
}

draw_png_tuber :: proc(app: ^App, delta: f32) {

	if app.loaded_rig == nil {
		// load_rig_popup
		return
	}

	for _, texture in app.rig_status.z_textures {
		rl.BeginTextureMode(texture)
		rl.ClearBackground(rl.ColorAlpha(rl.WHITE, 0.0))
		rl.EndTextureMode()
	}

	for priority in app.rig_status.priorities {
		for section_name, &section in app.loaded_rig.sections {
			// skip overlays
			if section.priority != priority || !section.visible {
				continue
			}

			cur_frame, frame_ok := get_frame(
				app.loaded_rig,
				section_name,
				app.rig_status.cur_frame[section_name],
			)

			if !frame_ok {
				continue
			}


			cur_transform := get_section_transform(app, section_name, delta)

			width_jiggle :=
				(app.rig_data.sections[section_name].total_velocities.x -
					app.rig_data.sections[section_name].total_velocities.y)
			height_jiggle :=
				(app.rig_data.sections[section_name].total_velocities.y -
					app.rig_data.sections[section_name].total_velocities.x)

			position_anchor :=
				math_anchor_position(
					f32(rl.GetScreenWidth()),
					f32(rl.GetScreenHeight()),
					app.loaded_rig.sections[section_name].window_anchor,
				) -
				math_anchor_position(
					cur_transform.width,
					cur_transform.height,
					app.loaded_rig.sections[section_name].window_anchor,
				) +
				{cur_transform.width / 2.0, cur_transform.height / 2.0} +
				app.loaded_rig.sections[section_name].window_anchor_offset
			transform_anchor :=
				math_anchor_position(
					cur_transform.width,
					cur_transform.height,
					app.loaded_rig.sections[section_name].transform_anchor,
				) +
				app.loaded_rig.sections[section_name].transform_anchor_offset

			//fmt.println(transform_anchor)

			frame_tint: rl.Color
			if cur_frame.overwrite_tint {
				frame_tint = cur_frame.tint
			} else {
				frame_tint = rl.WHITE
			}

			texture, texture_ok := app.frame_lib.textures[cur_frame.src]

			frame_position := cur_transform.position + app.loaded_rig.position_offset

			min_x: f32 = 0
			min_y: f32 = 0
			max_x := min_x + cur_transform.width
			max_y := min_y + cur_transform.height

			min_x_anchor_distance := math.abs(min_x - transform_anchor.x)
			max_x_anchor_distance := math.abs(max_x - transform_anchor.x)
			min_y_anchor_distance := math.abs(min_y - transform_anchor.y)
			max_y_anchor_distance := math.abs(max_y - transform_anchor.y)

			min_x_jiggle_scale :=
				(min_x_anchor_distance / cur_transform.width) * section.x_softness
			max_x_jiggle_scale :=
				(max_x_anchor_distance / cur_transform.width) * section.x_softness
			min_y_jiggle_scale :=
				(min_y_anchor_distance / cur_transform.height) * section.y_softness
			max_y_jiggle_scale :=
				(max_y_anchor_distance / cur_transform.height) * section.y_softness


			//fmt.println(min_x, max_x, min_y, max_y)

			/*fmt.println(
				min_x_anchor_distance,
				max_x_anchor_distance,
				min_y_anchor_distance,
				max_y_anchor_distance,
			)*/

			/*fmt.println(
				min_x_jiggle_scale,
				max_x_jiggle_scale,
				min_y_jiggle_scale,
				max_y_jiggle_scale,
			)*/

			min_x = min_x + width_jiggle * min_x_jiggle_scale
			max_x = max_x - width_jiggle * max_x_jiggle_scale
			min_y = min_y + height_jiggle * min_y_jiggle_scale
			max_y = max_y - height_jiggle * max_y_jiggle_scale

			//fmt.println(min_x, max_x, min_y, max_y)

			min_x += frame_position.x + position_anchor.x - cur_transform.width / 2.0
			max_x += frame_position.x + position_anchor.x - cur_transform.width / 2.0
			min_y += frame_position.y + position_anchor.y - cur_transform.height / 2.0
			max_y += frame_position.y + position_anchor.y - cur_transform.height / 2.0

			//fmt.println(min_x, max_x, min_y, max_y)

			if texture_ok {
				z_texture := app.rig_status.z_textures[section.z_index]


				source_width := f32(texture.width)
				source_height := f32(texture.height)

				if cur_frame.flip_horizontal {
					source_width *= -1
				}
				if cur_frame.flip_vertical {
					source_width *= -1
				}

				rl.BeginTextureMode(z_texture)
				rl.DrawTexturePro(
					texture,
					{0, 0, source_width, source_height},
					{
						min_x + transform_anchor.x,
						min_y + transform_anchor.y,
						max_x - min_x,
						max_y - min_y,
					},
					transform_anchor,
					cur_transform.rotation,
					frame_tint,
				)
				rl.EndTextureMode()
			}
		}
	}

	rl.BeginTextureMode(app.rig_status.final_texture)
	{
		for z_index in app.rig_status.z_layers {
			texture := app.rig_status.z_textures[z_index].texture
			rl.DrawTextureRec(
				texture,
				{0, 0, f32(texture.width), -f32(texture.height)},
				{0, 0},
				rl.WHITE,
			)
		}
	}
	rl.EndTextureMode()
}

draw_editor :: proc(app: ^App, delta: f32) {
	if app.loaded_rig == nil {
		// load_rig_popup
		return
	}

	for _, texture in app.rig_status.z_textures {
		rl.BeginTextureMode(texture)
		rl.ClearBackground(rl.ColorAlpha(rl.WHITE, 0.0))
		rl.EndTextureMode()
	}

	for priority in app.rig_status.priorities {
		for section_name, &section in app.loaded_rig.sections {
			// skip overlays
			if section.priority != priority || !section.visible {
				continue
			}

			cur_frame, frame_ok := get_frame(
				app.loaded_rig,
				section_name,
				app.editor_data.cur_frame[section_name],
			)

			if !frame_ok {
				continue
			}

			cur_transform := get_section_transform(app, section_name, delta)

			width_jiggle :=
				(app.rig_data.sections[section_name].total_velocities.x -
					app.rig_data.sections[section_name].total_velocities.y)
			height_jiggle :=
				(app.rig_data.sections[section_name].total_velocities.y -
					app.rig_data.sections[section_name].total_velocities.x)

			position_anchor :=
				math_anchor_position(
					f32(rl.GetScreenWidth()),
					f32(rl.GetScreenHeight()),
					app.loaded_rig.sections[section_name].window_anchor,
				) -
				math_anchor_position(
					cur_transform.width,
					cur_transform.height,
					app.loaded_rig.sections[section_name].window_anchor,
				) +
				{cur_transform.width / 2.0, cur_transform.height / 2.0} +
				app.loaded_rig.sections[section_name].window_anchor_offset
			transform_anchor :=
				math_anchor_position(
					cur_transform.width,
					cur_transform.height,
					app.loaded_rig.sections[section_name].transform_anchor,
				) +
				app.loaded_rig.sections[section_name].transform_anchor_offset

			//fmt.println(transform_anchor)

			frame_tint: rl.Color
			if cur_frame.overwrite_tint {
				frame_tint = cur_frame.tint
			} else {
				frame_tint = rl.WHITE
			}

			texture, texture_ok := app.frame_lib.textures[cur_frame.src]

			editor_anchor_offset :=
				la.Vector2f32{1.0, 1.0} -
				math_anchor_position(
					1.0,
					1.0,
					app.loaded_rig.sections[section_name].transform_anchor,
				)

			frame_position :=
				cur_transform.position +
				app.loaded_rig.position_offset +
				app.editor_data.editor_border * editor_anchor_offset
			is_section_following := false
			for selected_section in app.editor_data.selected_sections {
				is_section_following =
					is_section_following |
					is_section_following_section(app.loaded_rig, section_name, selected_section)
			}
			if app.editor_data.is_frame_moving &&
			   (slice.contains(app.editor_data.selected_sections[:], section_name) ||
					   (is_section_following)) {
				frame_position += app.editor_data.mouse_transform
			}

			min_x: f32 = 0
			min_y: f32 = 0
			max_x := min_x + cur_transform.width
			max_y := min_y + cur_transform.height

			min_x_anchor_distance := math.abs(min_x - transform_anchor.x)
			max_x_anchor_distance := math.abs(max_x - transform_anchor.x)
			min_y_anchor_distance := math.abs(min_y - transform_anchor.y)
			max_y_anchor_distance := math.abs(max_y - transform_anchor.y)

			min_x_jiggle_scale :=
				(min_x_anchor_distance / cur_transform.width) * section.x_softness
			max_x_jiggle_scale :=
				(max_x_anchor_distance / cur_transform.width) * section.x_softness
			min_y_jiggle_scale :=
				(min_y_anchor_distance / cur_transform.height) * section.y_softness
			max_y_jiggle_scale :=
				(max_y_anchor_distance / cur_transform.height) * section.y_softness


			//fmt.println(min_x, max_x, min_y, max_y)

			/*fmt.println(
				min_x_anchor_distance,
				max_x_anchor_distance,
				min_y_anchor_distance,
				max_y_anchor_distance,
			)*/

			/*fmt.println(
				min_x_jiggle_scale,
				max_x_jiggle_scale,
				min_y_jiggle_scale,
				max_y_jiggle_scale,
			)*/

			min_x = min_x + width_jiggle * min_x_jiggle_scale
			max_x = max_x - width_jiggle * max_x_jiggle_scale
			min_y = min_y + height_jiggle * min_y_jiggle_scale
			max_y = max_y - height_jiggle * max_y_jiggle_scale

			//fmt.println(min_x, max_x, min_y, max_y)

			min_x += frame_position.x + position_anchor.x - cur_transform.width / 2.0
			max_x += frame_position.x + position_anchor.x - cur_transform.width / 2.0
			min_y += frame_position.y + position_anchor.y - cur_transform.height / 2.0
			max_y += frame_position.y + position_anchor.y - cur_transform.height / 2.0

			//fmt.println(min_x, max_x, min_y, max_y)

			if texture_ok {
				z_texture := app.rig_status.z_textures[section.z_index]

				source_width := f32(texture.width)
				source_height := f32(texture.height)

				if cur_frame.flip_horizontal {
					source_width *= -1
				}
				if cur_frame.flip_vertical {
					source_width *= -1
				}

				rl.BeginTextureMode(z_texture)
				rl.DrawTexturePro(
					texture,
					{0, 0, source_width, source_height},
					{
						min_x + transform_anchor.x,
						min_y + transform_anchor.y,
						max_x - min_x,
						max_y - min_y,
					},
					transform_anchor,
					cur_transform.rotation,
					frame_tint,
				)
				rl.EndTextureMode()
			}
		}
	}

	rl.BeginTextureMode(app.rig_status.final_texture)

	bar_box: rlui.Box

	bar_box.width = 0.9
	bar_box.is_parent_relative_width = true
	bar_box.h_anchor = .Right
	bar_box.height = 30.0
	bar_box.color = rl.BLACK

	button: rlui.Button

	button.width = 0.3
	button.is_parent_relative_width = true
	button.height = 1.0
	button.is_parent_relative_height = true
	button.h_anchor = .Center
	button.color = rl.GRAY
	button.hover_color = rl.WHITE
	button.active_color = rl.RED

	text: rlui.Text
	text.content = "Button"
	text.color = rl.BLUE
	text.font_size = 16
	text.h_anchor = .Center
	text.v_anchor = .Center

	text_widget := rlui.Widget(text)

	button.child = &text_widget

	button_widget := rlui.Widget(button)

	bar_box.child = &button_widget

	bar_widget := rlui.Widget(bar_box)

	screen_rect := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

	rlui.widget_draw(&bar_widget, screen_rect)

	fmt.println(rlui.is_pressed(&button_widget))

	{
		for z_index in app.rig_status.z_layers {
			texture := app.rig_status.z_textures[z_index].texture
			rl.DrawTextureRec(
				texture,
				{0, 0, f32(texture.width), -f32(texture.height)},
				{0, 0},
				rl.WHITE,
			)
		}

		if len(app.editor_data.selected_sections) == 1 {
			selected_section, s_ok := app.loaded_rig.sections[app.editor_data.selected_sections[0]]
			if s_ok {
				if len(app.loaded_rig.frames) < 0 {
					return
				}
				if app.editor_data.is_anchor_moving {
					transform_anchor_position := app.editor_data.mouse_transform

					rl.DrawCircleLinesV(transform_anchor_position.xy, 5.0, rl.BLUE)
					rl.DrawLineEx(
						transform_anchor_position.xy - {10, 10},
						transform_anchor_position.xy + {10, 10},
						1.0,
						rl.BLUE,
					)
					rl.DrawLineEx(
						transform_anchor_position.xy - {10, -10},
						transform_anchor_position.xy + {10, -10},
						1.0,
						rl.BLUE,
					)
				} else {

					editor_anchor_offset :=
						la.Vector2f32{1.0, 1.0} -
						math_anchor_position(1.0, 1.0, selected_section.transform_anchor)

					offset :=
						editor_anchor_offset * app.editor_data.editor_border +
						app.editor_data.mouse_transform

					cur_frame_id := app.editor_data.cur_frame[app.editor_data.selected_sections[0]]

					transform_anchor_position, ok := get_frame_anchor_position(
						app,
						app.editor_data.selected_sections[0],
						u32(cur_frame_id),
						offset,
					)

					if ok {
						rl.DrawCircleLinesV(transform_anchor_position.xy, 5.0, rl.BLUE)
						rl.DrawLineEx(
							transform_anchor_position.xy - {10, 10},
							transform_anchor_position.xy + {10, 10},
							1.0,
							rl.BLUE,
						)
						rl.DrawLineEx(
							transform_anchor_position.xy - {10, -10},
							transform_anchor_position.xy + {10, -10},
							1.0,
							rl.BLUE,
						)
					}
				}


			}

			if s_ok {
				draw_frame_controll(app, la.Vector2f32{10, 320})
			}
		}

		if len(app.editor_data.selected_sections) != 0 {
			draw_edit_rect(app.editor_data.frame_rect)
		}

		pressed_frame := draw_avilable_frames(app)
		pressed_section := draw_sections(app)
		if len(pressed_section) != 0 {
			app_edit_select_section(app, pressed_section)
		}

		if len(app.editor_data.selected_sections) > 0 {
			draw_cur_section_transform(app, app.editor_data.selected_sections[0], {10, 300})
		}

		rl.DrawRectangleRec(
			rl.Rectangle {
				app.editor_data.frame_lib_rect.x,
				app.editor_data.frame_lib_rect.y + app.editor_data.frame_lib_rect.height,
				app.editor_data.frame_lib_rect.width,
				app.editor_data.sections_rect.y -
				(app.editor_data.frame_lib_rect.y + app.editor_data.frame_lib_rect.height),
			},
			rl.BLACK,
		)
	}

	rl.EndTextureMode()

	/*rl.DrawText(
		strings.clone_to_cstring(app.editor_data.selected_section, context.temp_allocator),
		10,
		60,
		24,
		rl.BLACK,
	)

	if app.editor_data.selected_section != "" {

		editor_cur_frame := fmt.tprint(app.editor_data.cur_frame[app.editor_data.selected_section])
		max := uint(len(app.loaded_rig.sections[app.editor_data.selected_section].frames))

		rl.DrawText(
			strings.clone_to_cstring(editor_cur_frame, context.temp_allocator),
			10,
			120,
			24,
			rl.BLACK,
		)
		button_up := rl.GuiButton(rl.Rectangle{40, 110, 30, 20}, "+")
		button_down := rl.GuiButton(rl.Rectangle{40, 130, 30, 20}, "-")
		if button_up {
			app.editor_data.cur_frame[app.editor_data.selected_section] =
				(max + app.editor_data.cur_frame[app.editor_data.selected_section] + 1) % max
		}

		if button_down {
			app.editor_data.cur_frame[app.editor_data.selected_section] =
				(max + app.editor_data.cur_frame[app.editor_data.selected_section] + 1) % max
		}
	}*/
}

get_section_transform :: proc(app: ^App, section_name: string, delta: f32) -> Transformer {
	section, ok := app.loaded_rig.sections[section_name]

	if !ok {
		return Transformer{}
	}

	cur_frame: ^Frame
	frame_ok: bool
	switch app.scene {
	case .Menu, .Png_Tuber:
		cur_frame, frame_ok = get_frame(
			app.loaded_rig,
			section_name,
			app.rig_status.cur_frame[section_name],
		)
	case .Editor:
		cur_frame, frame_ok = get_frame(
			app.loaded_rig,
			section_name,
			app.editor_data.cur_frame[section_name],
		)
	}

	if !frame_ok {
		return Transformer{}
	}

	sec_len := len(section.frames)

	db := get_db() //decibels

	frame_factor: f32
	switch app.scene {
	case .Menu, .Png_Tuber:
		frame_factor = get_frame_factor(
			app.loaded_rig,
			section_name,
			app.rig_status.cur_frame[section_name],
			app.rig_status.frame_time[section_name],
		)
	case .Editor:
		frame_factor = get_frame_factor(
			app.loaded_rig,
			section_name,
			app.editor_data.cur_frame[section_name],
			0.0,
		)
	}

	rig_data_section := &app.rig_data.sections[section_name]

	prev_transform := add_transformers(
		&rig_data_section.cur_transformer,
		&rig_data_section.cur_volume_transformer,
	)

	cur_frame_transform := add_transformers(
		&cur_frame.transform,
		&rig_data_section.rand_transformers[0],
	)

	volume_tranform := solve_volume_transformers(&section.volume_transforms, db)
	lerp_transformers(
		&rig_data_section.cur_volume_transformer,
		&volume_tranform,
		&rig_data_section.cur_volume_transformer,
		0.0,
		section.final_vt_lerp_data,
		delta,
		&rig_data_section.cur_volume_velocities,
	)

	next_frame_id: int = 0

	#partial switch app.scene {
	case .Png_Tuber:
		switch section.loop_mode {
		case .Loop:
			next_frame_id =
				(int(app.rig_status.cur_frame[section_name]) +
					app.rig_status.frame_direction[section_name]) %
				sec_len
		case .None:
			next_frame_id = math.min(
				len(section.frames) - 1,
				int(app.rig_status.cur_frame[section_name]) +
				app.rig_status.frame_direction[section_name],
			)
		case .Revert:
			next_frame_id =
				(int(app.rig_status.cur_frame[section_name]) +
					app.rig_status.frame_direction[section_name])
			if next_frame_id >= len(section.frames) {
				next_frame_id = (len(section.frames) - 1) * 2 - next_frame_id
			} else if next_frame_id < 0 {
				next_frame_id *= -1
			}
		}
	case .Editor:
		next_frame_id = int(app.editor_data.cur_frame[section_name])
	}


	next_frame, _ := get_frame(app.loaded_rig, section_name, uint(next_frame_id))

	next_frame_transform := add_transformers(
		&next_frame.transform,
		&rig_data_section.rand_transformers[1],
	)

	cur_transform: Transformer
	lerp_transformers(
		&cur_frame_transform,
		&next_frame_transform,
		&cur_transform,
		frame_factor,
		cur_frame_transform.lerp_data,
	)

	if len(section.connect_to_section) != 0 {
		conn_section_ok := section.connect_to_section in app.loaded_rig.sections
		if conn_section_ok {
			connected_section, ok := app.rig_data.sections[section.connect_to_section]
			if ok {
				cur_transform.position += connected_section.cur_transformer.position
				cur_transform.position += connected_section.cur_volume_transformer.position
				cur_transform.position += connected_section.cur_transformer.rotation
				cur_transform.position += connected_section.cur_volume_transformer.rotation
			}
		}
	}

	lerp_transformers(
		&rig_data_section.cur_transformer,
		&cur_transform,
		&rig_data_section.cur_transformer,
		frame_factor,
		section.final_lerp_data,
		delta,
		&rig_data_section.cur_velocities,
	)

	cur_transform = add_transformers(
		&rig_data_section.cur_transformer,
		&rig_data_section.cur_volume_transformer,
	)

	cur_total_velocity := div_transformer(
		subtract_transformers(&cur_transform, &prev_transform),
		delta,
	)
	rig_data_section.total_velocities = TransformerVelocities {
		cur_total_velocity.position.x,
		cur_total_velocity.position.y,
		cur_total_velocity.width,
		cur_total_velocity.height,
		cur_total_velocity.rotation,
	}

	return cur_transform
}

WorkerData :: struct {
	app: ^App,
	//wait_group: ^sync.Wait_Group,
}

ipc_worker :: proc(t: ^thread.Thread) {
	listener, err := net.listen_tcp(net.Endpoint{net.IP4_Address{127, 0, 0, 1}, PORT})
	worker_data := (cast(^WorkerData)t.data)

	if err != nil {
		fmt.eprintln("Failed to run ipc listener", err)
		return
	}
	defer net.close(listener)

	fmt.println("Ipc worker started on port", PORT)

	for worker_data.app.running {
		conn, end, err := net.accept_tcp(listener)
		if err != nil {
			fmt.eprintln("Accept failed:", err)
			continue
		}
		defer net.close(conn)

		buffer: [1024]byte
		n, err2 := net.recv(conn, buffer[:])
		if err2 != nil {
			fmt.printfln("Recive failed:", err)
			return
		}

		message := string(buffer[:n])

		command: string
		content: string

		first_space := strings.index(message, " ")
		if first_space == -1 {
			command = message
		} else {
			command = message[:first_space]
			content = message[first_space + 1:]
		}

		sync.mutex_lock(&command_mutex)
		append(&ipc_commands, IpcCommand{command, content})
		sync.mutex_unlock(&command_mutex)
	}

	//sync.wait_group_done(worker_data.wait_group)
}

send_ipc :: proc(args_start: int) {
	sender, err := net.dial_tcp(net.Endpoint{net.IP4_Address{127, 0, 0, 1}, PORT})

	if err != nil {
		fmt.eprintln("Failed to run ipc sender", err)
		return
	}
	defer net.close(sender)

	joined_command := strings.join(os.args[args_start:], " ")
	defer delete(joined_command)

	net.send_tcp(sender, transmute([]u8)joined_command)
}

app_run :: proc() {
	// Initialize audio
	device_config := ma.device_config_init(.capture)
	device_config.capture.format = .f32
	device_config.dataCallback = data_callback

	device: ma.device
	result := ma.device_init(nil, &device_config, &device)

	if result != .SUCCESS {
		fmt.eprintln("failed to initialize audio device:", result)
		os.exit(1)
	}
	defer ma.device_uninit(&device)

	result = ma.device_start(&device)
	if result != .SUCCESS {
		fmt.eprintln("failed to start audio device:", result)
		os.exit(1)
	}
	defer ma.device_stop(&device)

	// Initialize window

	rl.SetConfigFlags(rl.ConfigFlags{.WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})

	rl.SetTargetFPS(60)

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)

	app: ^App = new_app()
	defer {
		delete_app(app)
	}

	//wg: sync.Wait_Group

	ipc_thread := thread.create(ipc_worker)
	ipc_thread.init_context = context
	ipc_thread.user_index = 1
	ipc_thread.data = &WorkerData{app}
	thread.start(ipc_thread)
	defer thread.destroy(ipc_thread)

	//sync.wait_group_add(&wg, 1)


	//app_command(app, .Load_Rig, "./data/example")
	//app_command(app, .Load_Rig, "./data/multi_section")
	app_command(app, .Load_Rig, "./data/anime_test")
	//app_command(app, .Change_Scene, "Png_Tuber")
	//app_command(app, .Edit_Select_Section, "face")

	//fmt.printfln("%#v", app.loaded_rig)

	for app.running {
		sync.mutex_lock(&command_mutex)

		if len(ipc_commands) > 0 {

			for command in ipc_commands {
				command_enum, ok := reflect.enum_from_name(AppCommand, command.command)
				if ok {
					app_command(app, command_enum, command.content)
				}
			}

			clear(&ipc_commands)
		}

		sync.mutex_unlock(&command_mutex)

		if rl.WindowShouldClose() {
			switch app.scene {
			case .Editor, .Png_Tuber:
				app_command(app, .Change_Scene, "Menu")
			case .Menu:
				app.running = false
			}
		}
		if !app.muted {
			analyze_audio()
		}

		if rl.IsWindowResized() {
			reload_textures(&app.rig_status)
		}

		delta := rl.GetFrameTime() * app.time_speed

		app_process(app, delta)

		rl.BeginTextureMode(app.rig_status.final_texture)
		rl.ClearBackground(app.settings.background_color)
		rl.EndTextureMode()

		app_draw(app, delta)

		rl.BeginDrawing()
		rl.DrawTextureRec(
			app.rig_status.final_texture.texture,
			{
				0,
				0,
				f32(app.rig_status.final_texture.texture.width),
				-f32(app.rig_status.final_texture.texture.height),
			},
			{0, 0},
			rl.WHITE,
		)
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	rl.CloseWindow()

	//sync.wait_group_done(&wg)
	thread.terminate(ipc_thread, 0)

	delete(ipc_commands)
}

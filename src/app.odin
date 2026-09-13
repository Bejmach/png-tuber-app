package png_tuber

import "core:fmt"
import "core:math"
import "core:reflect"
import rl "vendor:raylib"

AppScene :: enum {
	Menu,
	Png_Tuber,
}

AppRigData :: struct {
	transformers:           [2]Transformer,
	cur_volume_transformer: Transformer,
	tint:                   rl.Color,
	frame_changed:          bool,
}

App :: struct {
	scene:      AppScene,
	settings:   ^Settings,
	muted:      bool,
	running:    bool,
	rig_data:   AppRigData,
	rig_status: RigStatus,
	frame_lib:  TextureLib,
	loaded_rig: ^Rig,
	time_speed: f32,
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
	}
	delete_frame_lib(&app.frame_lib)
	free(app)
}

AppCommand :: enum {
	Load_Rig,
	Change_Scene,
}

app_command :: proc(app: ^App, command: AppCommand, payload: string) {
	switch command {
	case .Load_Rig:
		app_load_rig(app, payload)
	case .Change_Scene:
		app_change_scene(app, payload)
	}
}

app_load_rig :: proc(app: ^App, path: string) {
	if app.loaded_rig != nil {
		delete_rig(app.loaded_rig)
		delete_frame_lib(&app.frame_lib)
	}
	rig, ok := load_rig(path)
	if ok {
		app.loaded_rig = rig
		load_textures(&app.frame_lib, rig)
	}
	app.rig_data.cur_volume_transformer.lerp_mode = app.loaded_rig.vt_lerp_mode
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
		}
	}
}

app_process :: proc(app: ^App, delta: f32) {
	switch app.scene {
	case .Menu:
	case .Png_Tuber:
		app_process_png_tuber(app, delta)
	}
}

app_process_png_tuber :: proc(app: ^App, delta: f32) {
	app.rig_data.frame_changed = process_rig_status(&app.rig_status, app.loaded_rig, delta)
}

app_draw :: proc(app: ^App, delta: f32) {
	switch app.scene {
	case .Menu:
		draw_menu(app)
	case .Png_Tuber:
		draw_png_tuber(app, delta)
	}
}

draw_menu :: proc(app: ^App) {

}

draw_png_tuber :: proc(app: ^App, delta: f32) {
	cur_frame, frame_ok := get_frame(
		app.loaded_rig,
		app.rig_status.state,
		app.rig_status.cur_frame,
	)
	if !frame_ok {
		return
	}

	next_frame, _ := get_frame(app.loaded_rig, app.rig_status.state, app.rig_status.cur_frame + 1) // if cur frame is ok then next frame WILL BE ok

	texture, texture_ok := app.frame_lib.textures[cur_frame.src]
	if !texture_ok {
		return
	}

	db := get_db() //decibels

	if app.rig_data.frame_changed {
		app.rig_data.frame_changed = false

		app.rig_data.transformers[0] = app.rig_data.transformers[1]
		app.rig_data.transformers[1] = colapse_rand_transformer(&next_frame.rand_transform)
	}

	frame_factor := get_texture_factor(
		app.loaded_rig,
		app.rig_status.state,
		app.rig_status.cur_frame,
		app.rig_status.frame_time,
	)

	cur_frame_transform := add_transformers(&cur_frame.transform, &app.rig_data.transformers[0])
	next_frame_transform := add_transformers(&next_frame.transform, &app.rig_data.transformers[1])

	volume_tranform := solve_volume_transformers(&cur_frame.volume_transforms, db)
	if !app.loaded_rig.lerp_vt {
		app.rig_data.cur_volume_transformer = volume_tranform
	} else {
		app.rig_data.cur_volume_transformer = lerp_transformers(
			&app.rig_data.cur_volume_transformer,
			&volume_tranform,
			delta * app.loaded_rig.vt_lerp_strength,
			app.loaded_rig.vt_lerp_mode,
		)
	}

	cur_transform := lerp_transformers(
		&cur_frame_transform,
		&next_frame_transform,
		frame_factor,
		cur_frame_transform.lerp_mode,
	)
	cur_transform = add_transformers(&cur_transform, &app.rig_data.cur_volume_transformer)

	position_anchor :=
		math_anchor_position(
			f32(rl.GetScreenWidth()),
			f32(rl.GetScreenHeight()),
			app.loaded_rig.window_anchor,
		) -
		math_anchor_position(
			cur_transform.width,
			cur_transform.height,
			app.loaded_rig.window_anchor,
		) +
		{cur_transform.width / 2.0, cur_transform.height / 2.0} +
		app.loaded_rig.window_anchor_offset
	rotation_anchor :=
		math_anchor_position(
			cur_transform.width,
			cur_transform.height,
			app.loaded_rig.rotation_anchor,
		) +
		app.loaded_rig.rotation_anchor_offset

	frame_tint: rl.Color
	if cur_frame.overwrite_tint {
		frame_tint = cur_frame.tint
	} else {
		frame_tint = rl.WHITE
	}

	frame_position := cur_transform.position + app.loaded_rig.position_offset

	rl.DrawTexturePro(
		texture,
		{0, 0, f32(texture.width), f32(texture.height)},
		{
			frame_position.x + position_anchor.x + rotation_anchor.x - cur_transform.width / 2.0,
			frame_position.y + position_anchor.y + rotation_anchor.y - cur_transform.height / 2.0,
			cur_transform.width,
			cur_transform.height,
		},
		rotation_anchor,
		cur_transform.rotation,
		frame_tint,
	)
}

package png_tuber

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:net"
import "core:os"
import "core:reflect"
import "core:strings"
import "core:sync"
import "core:thread"
import ma "vendor:miniaudio"
import rl "vendor:raylib"


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
	free(app)
}

AppCommand :: enum {
	Load_Rig,
	Change_Scene,
	Rig_Command,
}

app_command :: proc(app: ^App, command: AppCommand, payload: string) {
	switch command {
	case .Load_Rig:
		app_load_rig(app, payload)
	case .Change_Scene:
		app_change_scene(app, payload)
	case .Rig_Command:
		app_rig_command(app, payload)
	}
}

app_load_rig :: proc(app: ^App, path: string) {
	if app.loaded_rig != nil {
		delete_rig(app.loaded_rig)
		clear_frame_lib(&app.frame_lib)
		clear_rig_data(&app.rig_data)
		clear_rig_status(&app.rig_status)
	}
	rig, ok := load_rig(path)
	if ok {
		app.loaded_rig = rig
		load_textures(&app.frame_lib, rig)
	}
	prepare_rig_status(&app.rig_status, app.loaded_rig)
	for section_name, _ in app.loaded_rig.sections {
		app.rig_data.sections[section_name] = AppSectionData{}
	}
	#partial switch app.scene {
	case .Png_Tuber, .Editor:
		rig_rect := get_rig_rect(app.loaded_rig)
		rl.SetWindowSize(math.max(i32(rig_rect.width), 100), math.max(i32(rig_rect.height), 100))
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
		}
	}
}

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

app_process_editor :: proc(app: ^App, delta: f32){
	if rl.IsMouseButtonDown(.LEFT){
		app.editor_data.mouse_transform += rl.GetMouseDelta()
	} else if rl.IsMouseButtonReleased(.LEFT) {
		section, ok := &app.loaded_rig.sections[app.editor_data.selected_section]
		cur_frame := &app.loaded_rig.frames[section.frames[app.editor_data.cur_frame]]
		cur_frame.transform.position += app.editor_data.mouse_transform 
		app_data_section := &app.rig_data.sections[app.editor_data.selected_section]
		app_data_section.cur_transformer.position += app.editor_data.mouse_transform
		app.editor_data.mouse_transform = {0.0, 0.0}
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

}

draw_png_tuber :: proc(app: ^App, delta: f32) {
	for zi in app.rig_status.z_layers {
		for section_name, &section in app.loaded_rig.sections {
			// skip overlays
			if section.z_index != zi || !section.visible {
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

			cur_transform := get_section_transform(
				app.loaded_rig,
				&app.rig_status,
				app.rig_data,
				section_name,
				delta,
			)

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
				rl.DrawTexturePro(
					texture,
					{0, 0, f32(texture.width), f32(texture.height)},
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
			}
		}
	}
}

draw_editor :: proc(app: ^App, delta: f32) {
	for zi in app.rig_status.z_layers {
		for section_name, &section in app.loaded_rig.sections {
			// skip overlays
			if section.z_index != zi || !section.visible {
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

			cur_transform := get_section_transform(
				app.loaded_rig,
				&app.rig_status,
				app.rig_data,
				section_name,
				delta,
			)

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
			if section_name == app.editor_data.selected_section || section.connect_to_section == app.editor_data.selected_section {
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
				rl.DrawTexturePro(
					texture,
					{0, 0, f32(texture.width), f32(texture.height)},
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
			}
		}
	}

	selected_section, ok := app.loaded_rig.sections[app.editor_data.selected_section]
	if ok {
		if len(app.loaded_rig.frames) < 0 {
			return
		}
		cur_frame_id := 0

		cur_frame := app.loaded_rig.frames[selected_section.frames[cur_frame_id]]
		position_anchor :=
			math_anchor_position(
				f32(rl.GetScreenWidth()),
				f32(rl.GetScreenHeight()),
				selected_section.window_anchor,
			) -
			math_anchor_position(
				cur_frame.transform.width,
				cur_frame.transform.height,
				selected_section.transform_anchor,
			) +
			selected_section.window_anchor_offset
		draw_edit_rect(
			rl.Rectangle {
				cur_frame.transform.position.x + position_anchor.x + app.editor_data.mouse_transform.x,
				cur_frame.transform.position.y + position_anchor.y + app.editor_data.mouse_transform.y,
				cur_frame.transform.width,
				cur_frame.transform.height,
			},
		)
	}
}

get_section_transform :: proc(
	r: ^Rig,
	rs: ^RigStatus,
	ard: AppRigData,
	section_name: string,
	delta: f32,
) -> Transformer {
	section, ok := r.sections[section_name]

	if !ok {
		return Transformer{}
	}

	cur_frame, frame_ok := get_frame(r, section_name, rs.cur_frame[section_name])

	if !frame_ok {
		return Transformer{}
	}

	sec_len := len(section.frames)

	db := get_db() //decibels

	frame_factor := get_texture_factor(
		r,
		section_name,
		rs.cur_frame[section_name],
		rs.frame_time[section_name],
	)

	rig_data_section := &ard.sections[section_name]

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

	next_frame_id: int

	switch section.loop_mode {
	case .Loop:
		next_frame_id =
			(int(rs.cur_frame[section_name]) + rs.frame_direction[section_name]) % sec_len
	case .None:
		next_frame_id = math.min(
			len(section.frames) - 1,
			int(rs.cur_frame[section_name]) + rs.frame_direction[section_name],
		)
	case .Revert:
		next_frame_id = (int(rs.cur_frame[section_name]) + rs.frame_direction[section_name])
		if next_frame_id >= len(section.frames) {
			next_frame_id = (len(section.frames) - 1) * 2 - next_frame_id
		} else if next_frame_id < 0 {
			next_frame_id *= -1
		}
	}


	next_frame, _ := get_frame(r, section_name, uint(next_frame_id))

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

	if len(section.connect_to_section) != 0 {
		conn_section_ok := section.connect_to_section in r.sections
		if conn_section_ok {
			connected_section, ok := ard.sections[section.connect_to_section]
			if ok {
				cur_transform.position +=
					connected_section.cur_transformer.position +
					connected_section.cur_volume_transformer.position
				cur_transform.rotation +=
					connected_section.cur_transformer.rotation +
					connected_section.cur_volume_transformer.rotation
			}
		}
	}

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
	app_command(app, .Load_Rig, "./data/multi_section")
	app_command(app, .Change_Scene, "Editor")
	app.editor_data.selected_section = "face"

	fmt.println(app.scene)

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
			app.running = false
			break
		}
		if !app.muted {
			analyze_audio()
		}

		delta := rl.GetFrameTime() * app.time_speed

		app_process(app, delta)

		rl.BeginDrawing()
		rl.ClearBackground(app.settings.background_color)
		{
			app_draw(app, delta)
		}
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	rl.CloseWindow()

	//sync.wait_group_done(&wg)
	thread.terminate(ipc_thread, 0)

	delete(ipc_commands)
}

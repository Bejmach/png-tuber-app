package png_tuber

import "core:math"
import "core:reflect"
import rl "vendor:raylib"

AppScene :: enum {
	Menu,
	Png_Tuber,
}

AppRigData :: struct {
	rotation:      f32,
	tint:          rl.Color,
	frame_changed: bool,
}

App :: struct {
	scene:      AppScene,
	settings:   ^Settings,
	muted:      bool,
	running:    bool,
	rig_data:   AppRigData,
	rig_status: RigStatus,
	frame_lib:  FrameLib,
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
			size := get_rig_size(app.loaded_rig)
			rl.SetWindowSize(math.max(i32(size.x), 100), math.max(i32(size.y), 100))
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

app_draw :: proc(app: ^App) {
	switch app.scene {
	case .Menu:
		draw_menu(app)
	case .Png_Tuber:
		draw_png_tuber(app)
	}
}

draw_menu :: proc(app: ^App) {

}

draw_png_tuber :: proc(app: ^App) {
	frame, frame_ok := get_frame(&app.rig_status, app.loaded_rig)
	if !frame_ok {
		return
	}

	texture, texture_ok := app.frame_lib.frames[frame.src]
	if !texture_ok {
		return
	}

	if app.rig_data.frame_changed {
		app.rig_data.rotation = get_frame_rotation(frame, app.loaded_rig)
		app.rig_data.tint = get_frame_tint(frame, app.loaded_rig)
	}

	frame_size: [2]f32
	if frame.overwrite_size || app.loaded_rig.overwrite_size {
		frame_size = get_frame_size(frame, app.loaded_rig)
	} else {
		frame_size = {f32(texture.width), f32(texture.height)}
	}

	position_anchor :=
		math_anchor_position(
			f32(rl.GetScreenWidth()),
			f32(rl.GetScreenHeight()),
			app.loaded_rig.window_anchor,
		) -
		math_anchor_position(frame_size[0], frame_size[1], app.loaded_rig.window_anchor) +
		{frame_size[0] / 2.0, frame_size[1] / 2.0}
	rotation_anchor := math_anchor_position(
		frame_size[0],
		frame_size[1],
		app.loaded_rig.rotation_anchor,
	)

	frame_position := get_position(&frame.position) + app.loaded_rig.position_offset

	rl.DrawTexturePro(
		texture,
		{0, 0, f32(texture.width), f32(texture.height)},
		{
			frame_position.x + position_anchor.x,
			frame_position.y + position_anchor.y,
			frame_size[0],
			frame_size[1],
		},
		rotation_anchor,
		app.rig_data.rotation,
		app.rig_data.tint,
	)
}

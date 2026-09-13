package png_tuber

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strings"

import ma "vendor:miniaudio"
import rl "vendor:raylib"

WINDOW_WIDTH: i32 = 800
WINDOW_HEIGHT: i32 = 600
WINDOW_TITLE: cstring = "png-tuber studio"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

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

	rl.SetConfigFlags(rl.ConfigFlags{.VSYNC_HINT, .WINDOW_RESIZABLE})

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)

	/*rig, ok := load_rig("./data/example")
	defer {
		delete_rig(rig)
	}

	if ok {
		fmt.println(rig)
	}
	rig_status := default_rig_status()

	frame_lib: FrameLib = FrameLib{{}}
	defer {
		delete_frame_lib(&frame_lib)
	}

	load_textures(&frame_lib, rig)

	fmt.println(frame_lib)*/

	app: ^App = new_app()
	defer {
		delete_app(app)
	}

	app_command(app, .Load_Rig, "./data/lerp_rig")
	app_command(app, .Change_Scene, "Png_Tuber")

	for app.running {
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
}

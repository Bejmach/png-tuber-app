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
	window: ^Window = new_window(500, 500, "png-tuber studio")
	defer {
		delete_window(window)
	}

	rl.SetConfigFlags(rl.ConfigFlags{.VSYNC_HINT})

	init_window(window)

	rig, ok := load_rig("./data/example")
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

	fmt.println(frame_lib)

	frame_rotation: f32
	frame_tint: rl.Color = rl.WHITE

	for window.running {
		if rl.WindowShouldClose() {
			window.running = false
			break
		}
		analyze_audio()

		delta := rl.GetFrameTime()

		frame_change := process_rig_status(&rig_status, rig, delta)

		//fmt.println(rig_status.state, rig_status.frame_time, rig_status.cur_frame, rig_status.cur_frame_name)

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{0, 255, 0, 255})
		{
			/*rl.DrawText(
				strings.clone_to_cstring(rig_status.cur_frame_name, context.temp_allocator),
				0,
				0,
				24,
				rl.RED,
			)*/

			frame, frame_ok := get_frame(&rig_status, rig)

			if frame_ok {
				texture, ok := frame_lib.frames[frame.src]

				if ok {
					if frame_change {
						frame_rotation = get_frame_rotation(&frame, rig)
						frame_tint = get_frame_tint(&frame, rig)
					}

					frame_size: [2]f32
					if frame.overwrite_size || rig.overwrite_size {
						frame_size = get_frame_size(&frame, rig)
					} else {
						frame_size = {f32(texture.width), f32(texture.height)}
					}

					position_anchor :=
						math_anchor_position(window.width, window.height, rig.window_anchor) -
						math_anchor_position(frame_size[0], frame_size[1], rig.window_anchor) +
						{frame_size[0] / 2.0, frame_size[1] / 2.0}
					rotation_anchor := math_anchor_position(
						frame_size[0],
						frame_size[1],
						rig.rotation_anchor,
					)

					frame_position := get_position(&frame.position) + rig.position_offset

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
						frame_rotation,
						frame_tint,
					)
				}
			}
		}
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}

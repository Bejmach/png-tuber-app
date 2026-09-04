package png_tuber

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os"
import "core:mem"

import ma "vendor:miniaudio"
import rl "vendor:raylib"

MAX_SAMPLES :: 512

AudioData :: struct {
	samples:      [MAX_SAMPLES]f32,
	sample_count: int,
}

AudioAnalysis :: struct {
	rms:  f32,
	peak: f32,
}

audio_data: AudioData
audio_analysis: AudioAnalysis

data_callback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frame_count: u32) {
	context = runtime.default_context()

	samples := cast([^]f32)input
	sample_count := min(int(frame_count), MAX_SAMPLES)

	copy(audio_data.samples[:sample_count], samples[:sample_count])

	audio_data.sample_count = sample_count
}

analyze_audio :: proc() {
	audio_analysis = {}

	for i in 0 ..< audio_data.sample_count {
		sample := audio_data.samples[i]
		audio_analysis.rms += sample * sample
		audio_analysis.peak = math.max(audio_analysis.peak, math.abs(sample))
	}
	if audio_data.sample_count > 0 {
		audio_analysis.rms = math.sqrt(audio_analysis.rms / f32(audio_data.sample_count))
	}
}

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
	window: ^Window = new_window(1280, 720, "png-tuber studio")
	defer{
		delete_window(window)
	}

	rl.SetConfigFlags(rl.ConfigFlags{.VSYNC_HINT})

	init_window(window)

	rig, ok := load_rig("./data/example/rig.json")
	defer {
		delete_rig(rig)
	}

	if ok{
		fmt.println(rig)
	}

	for window.running{
		if rl.WindowShouldClose(){
			window.running = false
			break
		}
		analyze_audio()
		db := 20.0 * math.log10(audio_analysis.rms)
		//fmt.println(db)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		{
			if db > -50 {
				rl.DrawRectangle(100, 100, 1080, 520, rl.WHITE)
			}
		}
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}

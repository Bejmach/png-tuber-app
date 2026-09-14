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

print_help :: proc(){
	lines := []string{
		"Usage: {executable} <[flags]> [params]",
		"",
		"Flags:",
		"    -h, --help                shows this message",
		"",
		"Params:",
		"    run (default)             runs the app",
		"    ipc [app_command]         sends command to running instance"
	}

	for line in lines{
		fmt.println(line)
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

	for i:=1; i<len(os.args); i+=1{
		arg := os.args[i]
		switch arg{
		case "-h", "--help":
			print_help()
			return
		case "ipc":
			if i+1 < len(os.args){
				send_ipc(os.args[i+1])
			} else {
				fmt.println("No command for ipc provided")
			}
			return
		}
	}
	

	app_run()
}

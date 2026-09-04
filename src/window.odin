package png_tuber

import rl "vendor:raylib"
import la "core:math/linalg"

Window :: struct {
	width, height: f32,
	title:         cstring,
	running:       bool,
}

new_window :: proc(width: i32, height: i32, title: cstring) -> ^Window{
	w: ^Window = new(Window)
	running := true
	w^ = Window{f32(width), f32(height), title, running}

	return w
}

delete_window :: proc(w: ^Window) {
	free(w)
}

init_window :: proc(w: ^Window){
	rl.InitWindow(i32(w.width), i32(w.height), w.title)
}

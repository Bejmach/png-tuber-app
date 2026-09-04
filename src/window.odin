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

anchor_position :: proc(w: ^Window, anchor: Anchor) -> la.Vector2f32 {
	switch anchor{
		case .Top_Left:
			return {0.0, 0.0}
		case .Top_Center:
			return {w.width/2.0, 0.0}
		case .Top_Right:
			return {w.width, 0.0}
		case .Center_Left:
			return {0.0, w.height/2.0}
		case .Center_Center:
			return {w.width/2.0, w.height/2.0}
		case .Center_Right:
			return {w.width, w.height/2.0}
		case .Bottom_Left:
			return {0.0, w.height}
		case .Bottom_Center:
			return {w.width/2.0, w.height}
		case .Bottom_Right:
			return {w.width, w.height}
	}
	return {0.0, 0.0}
}

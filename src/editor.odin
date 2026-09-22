package png_tuber

import la "core:math/linalg"
import rl "vendor:raylib"

EditorData :: struct {
	selected_section: string,
	cur_frame: uint,
	mouse_transform: la.Vector2f32,
}

draw_edit_rect :: proc(rect: rl.Rectangle) {
	rl.DrawRectangleLinesEx(rect, 1.0, rl.WHITE)

	min_x := rect.x
	max_x := rect.x + rect.width
	min_y := rect.y
	max_y := rect.y + rect.height

	points := [8]la.Vector2f32 {
		{min_x, min_y},
		{min_x, (min_y + max_y) / 2.0},
		{min_x, max_y},
		{(min_x + max_x) / 2.0, min_y},
		{(min_x + max_x) / 2.0, max_y},
		{max_x, min_y},
		{max_x, (min_y + max_y) / 2.0},
		{max_x, max_y},
	}

	for point in points {
		rl.DrawCircleLinesV(point, 2.0, rl.WHITE)
	}
}

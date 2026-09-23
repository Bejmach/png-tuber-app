package png_tuber

import la "core:math/linalg"
import rl "vendor:raylib"

void :: struct {}

Anchor :: enum {
	Top_Left,
	Top_Center,
	Top_Right,
	Center_Left,
	Center_Center,
	Center_Right,
	Bottom_Left,
	Bottom_Center,
	Bottom_Right,
}

is_position_in_rect :: proc(pos: la.Vector2f32, rect: rl.Rectangle) -> bool {
	return(
		pos.x >= rect.x &&
		pos.x <= rect.x + rect.width &&
		pos.y >= rect.y &&
		pos.y <= rect.y + rect.height \
	)
}

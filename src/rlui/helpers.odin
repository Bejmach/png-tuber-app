package rlui

import rl "vendor:raylib"

VAnchor :: enum {
	Top,
	Center,
	Bottom,
}
HAnchor :: enum {
	Left,
	Center,
	Right,
}

is_position_in_rect :: proc(pos: rl.Vector2, rect: rl.Rectangle) -> bool {
	return(
		pos.x >= rect.x &&
		pos.x <= rect.x + rect.width &&
		pos.y >= rect.y &&
		pos.y <= rect.y + rect.height \
	)
}

package rlui

import rl "vendor:raylib"

Rectangle :: struct {
	is_parent_relative_width:  bool,
	width:                     f32,
	is_parent_relative_height: bool,
	height:                    f32,
	v_anchor:                  VAnchor,
	h_anchor:                  HAnchor,
	color:                     rl.Color,
}

rectangle_rect :: proc(rect: ^Rectangle, parent_rect: rl.Rectangle) -> rl.Rectangle {
	x := rectangle_x(rect, parent_rect)
	y := rectangle_y(rect, parent_rect)
	width := rectangle_width(rect, parent_rect)
	height := rectangle_height(rect, parent_rect)
	return rl.Rectangle{x, y, width, height}
}

rectangle_x :: proc(rect: ^Rectangle, parent_rect: rl.Rectangle) -> f32 {
	width := rectangle_width(rect, parent_rect)

	parent_width := parent_rect.width
	parent_x := parent_rect.x

	switch rect.h_anchor {
	case .Left:
		return parent_x
	case .Center:
		return parent_x + ((parent_width - width) / 2)
	case .Right:
		return parent_x + (parent_width - width)
	}
	return 0.0
}

rectangle_y :: proc(rect: ^Rectangle, parent_rect: rl.Rectangle) -> f32 {
	height := rectangle_height(rect, parent_rect)

	parent_height := parent_rect.height
	parent_y := parent_rect.y

	switch rect.v_anchor {
	case .Top:
		return parent_y
	case .Center:
		return parent_y + ((parent_height - height) / 2)
	case .Bottom:
		return parent_y + (parent_height - height)
	}
	return 0.0
}

rectangle_width :: proc(rect: ^Rectangle, parent_rect: rl.Rectangle) -> f32 {
	if rect.is_parent_relative_width {
		return rect.width * parent_rect.width
	} else {
		return rect.width
	}
}

rectangle_height :: proc(rect: ^Rectangle, parent_rect: rl.Rectangle) -> f32 {
	if rect.is_parent_relative_height {
		return rect.height * parent_rect.height
	} else {
		return rect.height
	}
}

rectangle_draw :: proc(rect: ^Rectangle, parent_rect: rl.Rectangle) {
	rl_rect := rectangle_rect(rect, parent_rect)
	rl.DrawRectangleRec(rl_rect, rect.color)
}

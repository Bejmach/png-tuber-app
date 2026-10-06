package rlui

import rl "vendor:raylib"

Box :: struct {
	parent:                    ^Widget,
	is_parent_relative_width:  bool,
	width:                     f32,
	is_parent_relative_height: bool,
	height:                    f32,
	v_anchor:                  VAnchor,
	h_anchor:                  HAnchor,
}

box_rect :: proc(box: ^Box) -> rl.Rectangle {
	x := box_x(box)
	y := box_y(box)
	width := box_width(box)
	height := box_height(box)
	return rl.Rectangle{x, y, width, height}
}

box_x :: proc(box: ^Box) -> f32 {
	width := box_width(box)

	parent_width: f32
	parent_x: f32

	if box.parent == nil {
		parent_width = f32(rl.GetScreenWidth())
		parent_x = 0.0
	} else {
		parent_width = get_width(box.parent)
		parent_x = get_x(box.parent)
	}

	switch box.h_anchor{
	case .Left:
		return parent_x
	case .Center:
		return parent_x + ((parent_width - width) / 2)
	case .Right:
		return parent_x + (parent_width - width)
	}
	return 0.0
}

box_y :: proc(box: ^Box) -> f32 {
	height := box_height(box)

	parent_height: f32
	parent_y: f32

	if box.parent == nil {
		parent_height = f32(rl.GetScreenHeight())
		parent_y = 0.0
	} else {
		parent_height = get_height(box.parent)
		parent_y = get_y(box.parent)
	}

	switch box.v_anchor{
	case .Top:
		return parent_y
	case .Center:
		return parent_y + ((parent_height - height) / 2)
	case .Bottom:
		return parent_y + (parent_height - height)
	}
	return 0.0
}

box_width :: proc(box: ^Box) -> f32 {
	if box.is_parent_relative_width {
		if box.parent != nil {
			return box.width * get_width(box.parent)
		} else {
			return box.width * f32(rl.GetScreenWidth())
		}
	} else {
		return box.width
	}
}

box_height :: proc(box: ^Box) -> f32 {
	if box.is_parent_relative_height {
		if box.parent != nil {
			return box.height * get_height(box.parent)
		} else {
			return box.height * f32(rl.GetScreenHeight())
		}
	} else {
		return box.height
	}
}

box_draw :: proc(box: ^Box, color: rl.Color) {
	rect := box_rect(box)
	rl.DrawRectangleRec(rect, color)
}

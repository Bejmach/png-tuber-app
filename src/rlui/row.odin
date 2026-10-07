package rlui

import "core:fmt"
import rl "vendor:raylib"

Row :: struct {
	children:                  []^Widget,
	is_parent_relative_height: bool,
	height:                    f32,
	h_anchor:                  HAnchor,
	v_anchor:                  VAnchor,
	pos:                       rl.Vector2,
	spacing:                   f32,
}

row_rect :: proc(row: ^Row, parent_rect: rl.Rectangle) -> rl.Rectangle {
	x := row_x(row, parent_rect)
	y := row_y(row, parent_rect)
	width := row_width(row)
	height := row_height(row, parent_rect)

	return rl.Rectangle{x, y, width, height}
}

row_width :: proc(row: ^Row) -> (width: f32) {
	for child in row.children {
		width += get_width(child, rl.Rectangle{0, 0, 0, 0})
	}
	width += row.spacing * f32((len(row.children) - 1))

	return width
}

row_height :: proc(row: ^Row, parent_rect: rl.Rectangle) -> f32 {
	if row.is_parent_relative_height {
		return row.height * parent_rect.height
	} else {
		return row.height
	}
}

row_x :: proc(row: ^Row, parent_rect: rl.Rectangle) -> f32 {
	width := row_width(row)

	parent_width := parent_rect.width
	parent_x := parent_rect.x

	switch row.h_anchor {
	case .Left:
		return parent_x + row.pos.x
	case .Center:
		return parent_x + row.pos.x + ((parent_width - width) / 2)
	case .Right:
		return parent_x + row.pos.x + (parent_width - width)
	}
	return 0.0
}

row_y :: proc(row: ^Row, parent_rect: rl.Rectangle) -> f32 {
	height := row_height(row, parent_rect)

	parent_height := parent_rect.height
	parent_y := parent_rect.y

	switch row.v_anchor {
	case .Top:
		return parent_y + row.pos.y
	case .Center:
		return parent_y + row.pos.y + ((parent_height - height) / 2)
	case .Bottom:
		return parent_y + row.pos.y + (parent_height - height)
	}
	return 0.0
}

row_draw :: proc(row: ^Row, parent_rect: rl.Rectangle) {
	rect := row_rect(row, parent_rect)

	cur_x: f32 = 0.0

	for child in row.children{
		fmt.println(cur_x)
		set_pos(child, rl.Vector2{cur_x, 0.0})
		child_rect := get_rect(child, rect)
		fmt.println(get_pos(child), child_rect)
		cur_x += child_rect.width + row.spacing

		widget_draw(child, rect)
	}
}

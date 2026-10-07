package rlui

import "core:fmt"
import rl "vendor:raylib"

Column :: struct {
	children:                 []^Widget,
	is_parent_relative_width: bool,
	width:                    f32,
	h_anchor:                 HAnchor,
	v_anchor:                 VAnchor,
	pos:                      rl.Vector2,
	spacing:                  f32,
}

column_rect :: proc(col: ^Column, parent_rect: rl.Rectangle) -> rl.Rectangle {
	x := column_x(col, parent_rect)
	y := column_y(col, parent_rect)
	width := column_width(col, parent_rect)
	height := column_height(col)

	return rl.Rectangle{x, y, width, height}
}

column_width :: proc(col: ^Column, parent_rect: rl.Rectangle) -> f32 {
	if col.is_parent_relative_width {
		return col.width * parent_rect.width
	} else {
		return col.width
	}
}

column_height :: proc(col: ^Column) -> (height: f32) {
	for child in col.children {
		height += get_height(child, rl.Rectangle{0, 0, 0, 0})
	}
	height += col.spacing * f32((len(col.children) - 1))

	return height
}

column_x :: proc(column: ^Column, parent_rect: rl.Rectangle) -> f32 {
	width := column_width(column, parent_rect)

	parent_width := parent_rect.width
	parent_x := parent_rect.x

	switch column.h_anchor {
	case .Left:
		return parent_x + column.pos.x
	case .Center:
		return parent_x + column.pos.x + ((parent_width - width) / 2)
	case .Right:
		return parent_x + column.pos.x + (parent_width - width)
	}
	return 0.0
}

column_y :: proc(column: ^Column, parent_rect: rl.Rectangle) -> f32 {
	height := column_height(column)

	parent_height := parent_rect.height
	parent_y := parent_rect.y

	switch column.v_anchor {
	case .Top:
		return parent_y + column.pos.y
	case .Center:
		return parent_y + column.pos.y + ((parent_height - height) / 2)
	case .Bottom:
		return parent_y + column.pos.y + (parent_height - height)
	}
	return 0.0
}

column_draw :: proc(column: ^Column, parent_rect: rl.Rectangle) {
	rect := column_rect(column, parent_rect)

	cur_y: f32 = 0.0

	for child in column.children {
		set_pos(child, rl.Vector2{0.0, cur_y})
		child_rect := get_rect(child, rect)
		cur_y += child_rect.height + column.spacing

		widget_draw(child, rect)
	}
}

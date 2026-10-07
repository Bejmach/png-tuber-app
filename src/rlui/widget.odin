package rlui

import rl "vendor:raylib"

Widget :: union {
	Rectangle,
	Box,
	Button,
	Text,
	Row,
	Column,
}

get_rect :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> rl.Rectangle {
	x := get_x(w, parent_rect)
	y := get_y(w, parent_rect)
	width := get_width(w, parent_rect)
	height := get_height(w, parent_rect)

	return rl.Rectangle{x, y, width, height}
}

get_x :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch &v in w {
	case Rectangle:
		return rectangle_x(&v, parent_rect)
	case Box:
		return rectangle_x(&v, parent_rect)
	case Button:
		return rectangle_x(&v, parent_rect)
	case Text:
		return text_x(&v, parent_rect)
	case Row:
		return row_x(&v, parent_rect)
	case Column:
		return column_x(&v, parent_rect)
	}

	return 0.0
}

get_y :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch &v in w {
	case Rectangle:
		return rectangle_y(&v, parent_rect)
	case Box:
		return rectangle_y(&v, parent_rect)
	case Button:
		return rectangle_y(&v, parent_rect)
	case Text:
		return text_y(&v, parent_rect)
	case Row:
		return row_y(&v, parent_rect)
	case Column:
		return column_y(&v, parent_rect)
	}

	return 0.0
}

get_width :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch &v in w {
	case Rectangle:
		return rectangle_width(&v, parent_rect)
	case Box:
		return rectangle_width(&v, parent_rect)
	case Button:
		return rectangle_width(&v, parent_rect)
	case Text:
		return f32(text_width(&v))
	case Row:
		return row_width(&v)
	case Column:
		return column_width(&v, parent_rect)
	}

	return 0.0
}

get_height :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch &v in w {
	case Rectangle:
		return rectangle_height(&v, parent_rect)
	case Box:
		return rectangle_height(&v, parent_rect)
	case Button:
		return rectangle_height(&v, parent_rect)
	case Text:
		return f32(text_height(&v))
	case Row:
		return row_height(&v, parent_rect)
	case Column:
		return column_height(&v)
	}

	return 0.0
}

widget_draw :: proc(w: ^Widget, parent_rect: rl.Rectangle) {
	switch &v in w {
	case Rectangle:
		rectangle_draw(&v, parent_rect)
	case Box:
		box_draw(&v, parent_rect)
	case Button:
		button_draw(&v, parent_rect)
	case Text:
		text_draw(&v, parent_rect)
	case Row:
		row_draw(&v, parent_rect)
	case Column:
		column_draw(&v, parent_rect)
	}
}

get_pos :: proc(w: ^Widget) -> rl.Vector2 {
	switch v in w {
	case Rectangle:
		return v.pos
	case Box:
		return v.pos
	case Button:
		return v.pos
	case Text:
		return v.pos
	case Row:
		return v.pos
	case Column:
		return v.pos
	}
	return rl.Vector2{0, 0}
}

set_pos :: proc(w: ^Widget, pos: rl.Vector2) {
	switch &v in w {
	case Rectangle:
		v.pos = pos
	case Box:
		v.pos = pos
	case Button:
		v.pos = pos
	case Text:
		v.pos = pos
	case Row:
		v.pos = pos
	case Column:
		v.pos = pos
	}
}

is_pressed :: proc(w: ^Widget) -> bool {
	switch v in w {
	case Rectangle, Box, Text, Row, Column:
		return false
	case Button:
		return v.pressed
	}
	return false
}

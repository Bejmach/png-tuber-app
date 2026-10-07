package rlui

import rl "vendor:raylib"

Widget :: union {
	Rectangle,
	Box,
	Button,
	Text,
}

get_x :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch _ in w {
	case Rectangle:
		return rectangle_x(&w.(Rectangle), parent_rect)
	case Box:
		return rectangle_x(&w.(Box), parent_rect)
	case Button:
		return rectangle_x(&w.(Button), parent_rect)
	case Text:
		return text_x(&w.(Text), parent_rect)
	}

	return 0.0
}

get_y :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32{
	switch _ in w {
	case Rectangle:
		return rectangle_y(&w.(Rectangle), parent_rect)
	case Box:
		return rectangle_y(&w.(Box), parent_rect)
	case Button:
		return rectangle_y(&w.(Button), parent_rect)
	case Text:
		return text_y(&w.(Text), parent_rect)
	}

	return 0.0
}

get_width :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch _ in w {
	case Rectangle:
		return rectangle_width(&w.(Rectangle), parent_rect)
	case Box:
		return rectangle_width(&w.(Box), parent_rect)
	case Button:
		return rectangle_width(&w.(Button), parent_rect)
	case Text:
		return f32(text_width(&w.(Text)))
	}

	return 0.0
}

get_height :: proc(w: ^Widget, parent_rect: rl.Rectangle) -> f32 {
	switch _ in w {
	case Rectangle:
		return rectangle_height(&w.(Rectangle), parent_rect)
	case Box:
		return rectangle_height(&w.(Box), parent_rect)
	case Button:
		return rectangle_height(&w.(Button), parent_rect)
	case Text:
		return f32(text_height(&w.(Text)))
	}

	return 0.0
}

widget_draw :: proc(w: ^Widget, parent_rect: rl.Rectangle){
	switch _ in w {
	case Rectangle:
		rectangle_draw(&w.(Rectangle), parent_rect)
	case Box:
		box_draw(&w.(Box), parent_rect)
	case Button:
		button_draw(&w.(Button), parent_rect)
	case Text:
		text_draw(&w.(Text), parent_rect)
	}
}

is_pressed :: proc(w: ^Widget) -> bool{
	switch _ in w{
	case Rectangle, Box, Text:
		return false
	case Button:
		return w.(Button).pressed
	}
	return false
}

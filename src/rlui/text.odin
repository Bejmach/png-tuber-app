package rlui

import rl "vendor:raylib"

Text :: struct {
	content:   cstring,
	font_size: i32,
	h_anchor:  HAnchor,
	v_anchor:  VAnchor,
	pos:       rl.Vector2,
	color:     rl.Color,
}

text_rect :: proc(text: ^Text, parent_rect: rl.Rectangle) -> rl.Rectangle {
	x := text_x(text, parent_rect)
	y := text_y(text, parent_rect)
	width := f32(text_width(text))
	height := f32(text_height(text))

	return rl.Rectangle{x, y, width, height}
}

text_width :: proc(text: ^Text) -> i32 {
	return rl.MeasureText(text.content, text.font_size)
}

text_height :: proc(text: ^Text) -> i32 {
	return text.font_size
}

text_x :: proc(text: ^Text, parent_rect: rl.Rectangle) -> f32 {
	width := f32(text_width(text))

	parent_width := parent_rect.width
	parent_x := parent_rect.x + text.pos.x

	switch text.h_anchor {
	case .Left:
		return parent_x + text.pos.x
	case .Center:
		return parent_x + text.pos.x + ((parent_width - width) / 2)
	case .Right:
		return parent_x + text.pos.x + (parent_width - width)
	}
	return 0.0
}

text_y :: proc(text: ^Text, parent_rect: rl.Rectangle) -> f32 {
	height := f32(text_height(text))

	parent_height := parent_rect.height
	parent_y := parent_rect.y + text.pos.y

	switch text.v_anchor {
	case .Top:
		return parent_y + text.pos.y
	case .Center:
		return parent_y + text.pos.y + ((parent_height - height) / 2)
	case .Bottom:
		return parent_y + text.pos.y + (parent_height - height)
	}
	return 0.0
}

text_draw :: proc(text: ^Text, parent_rect: rl.Rectangle) {
	x := text_x(text, parent_rect)
	y := text_y(text, parent_rect)

	rl.DrawText(text.content, i32(x), i32(y), text.font_size, text.color)
}

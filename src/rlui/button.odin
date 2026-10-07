package rlui

import rl "vendor:raylib"

Button :: struct {
	using box:    Box,
	hover_color:  rl.Color,
	active_color: rl.Color,

	pressed: bool,
}

button_draw :: proc(button: ^Button, parent_rect: rl.Rectangle) {
	rect := rectangle_rect(button, parent_rect)
	mouse_position := rl.GetMousePosition()

	color: rl.Color
	button.pressed = false

	if is_position_in_rect(mouse_position, rect) {
		if rl.IsMouseButtonDown(.LEFT) {
			color = button.active_color
		} else if rl.IsMouseButtonReleased(.LEFT) {
			color = button.active_color
			button.pressed = true
		} else {
			color = button.hover_color
		}
	} else {
		color = button.color
	}

	rl.DrawRectangleRec(rect, color)
	if button.child != nil{
		widget_draw(button.child, rect)
	}
}

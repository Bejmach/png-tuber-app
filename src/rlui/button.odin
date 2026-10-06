package rlui

import rl "vendor:raylib"

Button :: struct {
	using box: Box,
}

button_draw :: proc(button: ^Button, inactive_color: rl.Color, hover_color: rl.Color, active_color: rl.Color) -> bool{
	rect := box_rect(button)
	mouse_position := rl.GetMousePosition()
	
	color: rl.Color

	pressed := false

	if is_position_in_rect(mouse_position, rect){
		if rl.IsMouseButtonDown(.LEFT){
			color = active_color
		} else if rl.IsMouseButtonReleased(.LEFT) {
			color = active_color
			pressed = true
		} else {
			color = hover_color
		}
	} else {
		color = inactive_color
	}

	rl.DrawRectangleRec(rect, color)
	return pressed
}


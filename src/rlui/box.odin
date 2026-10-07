package rlui

import rl "vendor:raylib"

Box :: struct {
	using rectangle: Rectangle,
	child: ^Widget,
}

box_draw :: proc(box: ^Box, parent_rect: rl.Rectangle){
	rl_rect := rectangle_rect(box, parent_rect)
	rl.DrawRectangleRec(rl_rect, box.color)
	if box.child != nil{
		widget_draw(box.child, rl_rect)
	}
}


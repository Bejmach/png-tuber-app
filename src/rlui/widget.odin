package rlui

Widget :: union {
	Box,
	Button,
}

get_x :: proc(w: ^Widget) -> f32 {
	switch _ in w {
	case Box:
		return box_x(&w.(Box))
	case Button:
		return box_x(&w.(Button))
	}

	return 0.0
}

get_y :: proc(w: ^Widget) -> f32{
	switch _ in w {
	case Box:
		return box_y(&w.(Box))
	case Button:
		return box_y(&w.(Button))
	}

	return 0.0
}

get_width :: proc(w: ^Widget) -> f32 {
	switch _ in w {
	case Box:
		return box_width(&w.(Box))
	case Button:
		return box_width(&w.(Button))
	}

	return 0.0
}

get_height :: proc(w: ^Widget) -> f32 {
	switch _ in w {
	case Box:
		return box_height(&w.(Box))
	case Button:
		return box_height(&w.(Button))
	}

	return 0.0
}

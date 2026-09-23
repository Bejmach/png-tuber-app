package png_tuber

import "core:fmt"
import la "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

EditorData :: struct {
	selected_section: string,
	cur_frame:        map[string]uint,
	mouse_transform:  la.Vector2f32,
	frame_lib_rect:   rl.Rectangle,
	frame_lib_offset: f32,
	sections_rect:    rl.Rectangle,
	sections_offset:  f32,
}

prepare_editor_data :: proc(r: ^Rig, ed: ^EditorData) {
	for section_name in r.sections {
		ed.cur_frame[section_name] = 0
	}
	ed.frame_lib_rect = rl.Rectangle{0, 50, 150, 100}
	ed.frame_lib_offset = 0
	ed.sections_rect = rl.Rectangle{0, 190, 150, 100}
	ed.sections_offset = 0
}

clear_editor_data :: proc(ed: ^EditorData) {
	ed.selected_section = ""
	clear(&ed.cur_frame)
	ed.mouse_transform = {0.0, 0.0}
}

delete_editor_data :: proc(ed: ^EditorData) {
	delete(ed.cur_frame)
}

draw_edit_rect :: proc(rect: rl.Rectangle) {
	rl.DrawRectangleLinesEx(rect, 1.0, rl.WHITE)

	min_x := rect.x
	max_x := rect.x + rect.width
	min_y := rect.y
	max_y := rect.y + rect.height

	points := [8]la.Vector2f32 {
		{min_x, min_y},
		{min_x, (min_y + max_y) / 2.0},
		{min_x, max_y},
		{(min_x + max_x) / 2.0, min_y},
		{(min_x + max_x) / 2.0, max_y},
		{max_x, min_y},
		{max_x, (min_y + max_y) / 2.0},
		{max_x, max_y},
	}

	for point in points {
		rl.DrawCircleLinesV(point, 2.0, rl.WHITE)
	}
}

draw_avilable_frames :: proc(app: ^App) -> (pressed_frame: string) {
	rect := app.editor_data.frame_lib_rect
	rl.DrawRectangleLinesEx(rect, 2.0, rl.BLACK)

	pressed_frame = ""

	frame_rect := rl.Rectangle {
		rect.x + 2.0,
		rect.y - app.editor_data.frame_lib_offset,
		rect.width - 4,
		40,
	}
	for f_name, frame in app.loaded_rig.frames {
		fmt.println(frame_rect, rect)

		if frame_rect.y + frame_rect.height < rect.y || frame_rect.y > rect.y + rect.height {
			frame_rect.y += frame_rect.height
			continue
		}

		pressed := rl.GuiButton(frame_rect, "")

		if pressed {
			pressed_frame = f_name
		}

		image, ok := app.frame_lib.textures[frame.src]
		if ok {
			rl.DrawTexturePro(
				image,
				rl.Rectangle{0, 0, f32(image.width), f32(image.height)},
				rl.Rectangle{frame_rect.x + 2, frame_rect.y + 2, 36, 36},
				{0, 0},
				0,
				rl.WHITE,
			)
		}
		rl.DrawText(
			strings.clone_to_cstring(f_name, context.temp_allocator),
			i32(frame_rect.x) + 40,
			i32(frame_rect.y) + 2,
			12,
			rl.BLACK,
		)
		frame_rect.y += frame_rect.height
	}

	return pressed_frame
}

draw_sections :: proc(app: ^App) -> (pressed_section: string) {
	rect := app.editor_data.sections_rect
	rl.DrawRectangleLinesEx(rect, 2.0, rl.BLACK)

	pressed_section = ""

	frame_rect := rl.Rectangle {
		rect.x + 2.0,
		rect.y - app.editor_data.sections_offset,
		rect.width - 4,
		40,
	}
	for s_name, section in app.loaded_rig.sections {
		fmt.println(frame_rect, rect)

		if frame_rect.y + frame_rect.height < rect.y || frame_rect.y > rect.y + rect.height {
			frame_rect.y += frame_rect.height
			continue
		}

		pressed := rl.GuiButton(frame_rect, "")

		if pressed {
			pressed_section = s_name
		}

		if len(section.frames) > 0 {

			cur_frame_id, fi_ok := app.editor_data.cur_frame[s_name]
			cur_frame := section.frames[cur_frame_id]

			frame, f_ok := app.loaded_rig.frames[cur_frame]

			image, i_ok := app.frame_lib.textures[frame.src]
			if i_ok {
				rl.DrawTexturePro(
					image,
					rl.Rectangle{0, 0, f32(image.width), f32(image.height)},
					rl.Rectangle{frame_rect.x + 2, frame_rect.y + 2, 36, 36},
					{0, 0},
					0,
					rl.WHITE,
				)
			}
			text_color: rl.Color
			if s_name == app.editor_data.selected_section{
				text_color = rl.RED
			} else {
				text_color = rl.BLACK
			}
			rl.DrawText(
				strings.clone_to_cstring(s_name, context.temp_allocator),
				i32(frame_rect.x) + 40,
				i32(frame_rect.y) + 2,
				12,
				text_color,
			)
			frame_rect.y += frame_rect.height
		}
	}

	return pressed_section
}

draw_selected_section :: proc(app: ^App) {

}

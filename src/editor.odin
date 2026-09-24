package png_tuber

import "core:slice"
import "core:fmt"
import la "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

EditorData :: struct {
	selected_section: string,
	cur_frame:        map[string]uint,
	editor_border:    la.Vector2f32,
	mouse_transform:  la.Vector2f32,
	frame_lib_rect:   rl.Rectangle,
	frame_lib_offset: f32,
	sections_rect:    rl.Rectangle,
	sections_offset:  f32,
	is_holding:       bool,
	used_frames:      [dynamic]string,
}

prepare_editor_data :: proc(r: ^Rig, ed: ^EditorData) {
	for section_name in r.sections {
		ed.cur_frame[section_name] = 0
	}
	ed.frame_lib_rect = rl.Rectangle{0, 50, 150, 100}
	ed.frame_lib_offset = 0
	ed.sections_rect = rl.Rectangle{0, 190, 150, 100}
	ed.sections_offset = 0
	ed.editor_border = la.Vector2f32{150, 50}

	for s_name, section in r.sections{
		for f_name in section.frames{
			append(&ed.used_frames, f_name)
		}
	}
}

clear_editor_data :: proc(ed: ^EditorData) {
	ed.selected_section = ""
	clear(&ed.cur_frame)
	clear(&ed.used_frames)
	ed.mouse_transform = {0.0, 0.0}
}

delete_editor_data :: proc(ed: ^EditorData) {
	delete(ed.cur_frame)
	delete(ed.used_frames)
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
		if frame_rect.y + frame_rect.height < rect.y || frame_rect.y > rect.y + rect.height {
			frame_rect.y += frame_rect.height
			continue
		}

		pressed := rl.GuiButton(frame_rect, "")

		if pressed {
			pressed_frame = f_name
		}

		image, ok := app.frame_lib.textures[frame.src]
		text_color: rl.Color
		image_color: rl.Color
		if slice.contains(app.editor_data.used_frames[:], f_name){
			text_color = rl.RED
			image_color = rl.GRAY
		} else {
			text_color = rl.BLACK
			image_color = rl.WHITE
		}

		if ok {
			rl.DrawTexturePro(
				image,
				rl.Rectangle{0, 0, f32(image.width), f32(image.height)},
				rl.Rectangle{frame_rect.x + 2, frame_rect.y + 2, 36, 36},
				{0, 0},
				0,
				image_color,
			)
		}
		

		rl.DrawText(
			strings.clone_to_cstring(f_name, context.temp_allocator),
			i32(frame_rect.x) + 40,
			i32(frame_rect.y) + 2,
			12,
			text_color,
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
		rect.width - 42,
		40,
	}
	for s_name, &section in app.loaded_rig.sections {
		if frame_rect.y + frame_rect.height < rect.y || frame_rect.y > rect.y + rect.height {
			frame_rect.y += frame_rect.height
			continue
		}

		pressed := rl.GuiButton(frame_rect, "")

		if pressed {
			pressed_section = s_name
		}

		visible_text: cstring
		visible_color: rl.Color
		if section.visible{
			visible_text = "0"
			visible_color = rl.WHITE
		} else {
			visible_text = "-"
			visible_color = rl.GRAY
		}

		visible_pressed := rl.GuiButton(rl.Rectangle {frame_rect.x + frame_rect.width, frame_rect.y, 40, 40}, "")
		rl.DrawText(visible_text, i32(frame_rect.x + frame_rect.width + 10), i32(frame_rect.y + 2), 36, visible_color)

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
					visible_color,
				)
			}
			text_color: rl.Color
			if s_name == app.editor_data.selected_section {
				text_color = rl.RED
			} else {
				text_color = rl.BLACK
			}
			rl.ColorTint(text_color, visible_color)
			rl.DrawText(
				strings.clone_to_cstring(s_name, context.temp_allocator),
				i32(frame_rect.x) + 40,
				i32(frame_rect.y) + 2,
				12,
				text_color,
			)
			frame_rect.y += frame_rect.height
		}

		if visible_pressed{
			section.visible = !section.visible
		}
	}

	return pressed_section
}

draw_frame_controll :: proc(app: ^App, pos: la.Vector2f32){
	frame_id := app.editor_data.cur_frame[app.editor_data.selected_section]
	frame_id_str := fmt.tprint(frame_id)
	rl.DrawText(strings.clone_to_cstring(frame_id_str, context.temp_allocator), i32(pos.x), i32(pos.y), 36, rl.BLACK)
	increase := rl.GuiButton(rl.Rectangle{pos.x + 40, pos.y, 20, 16}, "+")
	decrease := rl.GuiButton(rl.Rectangle{pos.x + 40, pos.y + 20, 20, 16}, "-")

	if increase{
		max_frames := uint(len(app.loaded_rig.sections[app.editor_data.selected_section].frames))

		next_frame := (max_frames + frame_id + 1) % max_frames
		app.editor_data.cur_frame[app.editor_data.selected_section] = (max_frames + frame_id + 1) % max_frames 
	} else if decrease{
		max_frames := uint(len(app.loaded_rig.sections[app.editor_data.selected_section].frames))

		app.editor_data.cur_frame[app.editor_data.selected_section] = (max_frames + frame_id - 1) % max_frames
	}
}

draw_selected_section :: proc(app: ^App) {

}

#+feature dynamic-literals

package png_tuber

import "core:encoding/json"
import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

LerpMode :: enum {
	Constant,
	Linear,
	Sin,
	SmoothStep,
}

TextureLib :: struct {
	textures: map[string]rl.Texture2D,
}

Rig :: struct {
	frames:             map[string]Frame,
	sections:           map[string]AnimationSection,
	on_talk:            []RigCommand,
	on_blink:           []RigCommand, // only from idle
	on_action:          []RigCommand,
	on_idle:            []RigCommand, // from talk, blink or action
	idle_time:          f32,
	blink_time:         f32,
	position_offset:    la.Vector2f32,
	rotation_offset:    la.Vector2f32,
	preserve_talk_time: f32,
	lerp_vt:            bool,
	vt_lerp_mode:       LerpMode,
	vt_lerp_strength:   f32,
	volume_threshhold:  f32,
	rig_path:           string,
}

AnimationSection :: struct {
	visible:                bool,
	z_index:                int,
	frames:                 []string,
	window_anchor:          Anchor,
	window_anchor_offset:   la.Vector2f32,
	rotation_anchor:        Anchor,
	rotation_anchor_offset: la.Vector2f32,
	volume_transforms:      []VolumeTransformer, // supposed to go from quietest to loudest
	connect_to_section:     string,
}

delete_animation_section :: proc(as: ^AnimationSection) {
	for frame in as.frames {
		delete(frame)
	}
	delete(as.frames)

	delete(as.connect_to_section)

	delete(as.volume_transforms)
}

Frame :: struct {
	src:            string,
	time:           f32,
	transform:      Transformer,
	rand_transform: RandTransformer,
	overwrite_tint: bool, // Prevents having default tint as black with alpha 0
	tint:           rl.Color,
}

delete_frame :: proc(f: ^Frame) {
	delete(f.src)
}

Transformer :: struct {
	lerp_mode:     LerpMode, //
	position:      la.Vector2f32,
	width, height: f32,
	rotation:      f32,
}

RandTransformer :: struct {
	x, y, width, height, rotation: [2]f32,
}

colapse_rand_transformer :: proc(rt: ^RandTransformer) -> Transformer {
	nt: Transformer

	if rt.x[0] < rt.x[1] {
		nt.position.x = rand.float32_range(rt.x[0], rt.x[1])
	}
	if rt.y[0] < rt.y[1] {
		nt.position.y = rand.float32_range(rt.y[0], rt.y[1])
	}
	if rt.width[0] < rt.width[1] {
		nt.width = rand.float32_range(rt.width[0], rt.width[1])
	}
	if rt.height[0] < rt.height[1] {
		nt.height = rand.float32_range(rt.height[0], rt.height[1])
	}
	if rt.rotation[0] < rt.rotation[1] {
		nt.rotation = rand.float32_range(rt.rotation[0], rt.rotation[1])
	}

	return nt
}

VolumeTransformer :: struct {
	lerp_mode:                     LerpMode,
	volume:                        f32, // in decibels
	x, y, width, height, rotation: f32,
}

colapse_volume_transformer :: proc(vt: ^VolumeTransformer) -> Transformer {
	return Transformer{vt.lerp_mode, {vt.x, vt.y}, vt.width, vt.height, vt.rotation}
}

solve_volume_transformers :: proc(vt_s: ^[]VolumeTransformer, db: f32) -> Transformer {
	nt: Transformer

	vt_s_len := len(vt_s)
	if vt_s_len > 0 {
		if db < vt_s[0].volume {
			nt.position = {vt_s[0].x, vt_s[0].y}
			nt.width = vt_s[0].width
			nt.height = vt_s[0].height
			nt.rotation = vt_s[0].rotation
		}

		for i := 0; i < vt_s_len - 1; i += 1 {
			cur_vt := vt_s[i]
			next_vt := vt_s[i + 1]

			if db >= cur_vt.volume && db < next_vt.volume {
				factor := (db - cur_vt.volume) / (next_vt.volume - cur_vt.volume)
				t1 := colapse_volume_transformer(&cur_vt)
				t2 := colapse_volume_transformer(&next_vt)

				return lerp_transformers(&t1, &t2, factor, t1.lerp_mode)
			}
		}

		last_vt := vt_s[vt_s_len - 1]
		if db > last_vt.volume {
			nt.position = {last_vt.x, last_vt.y}
			nt.width = last_vt.width
			nt.height = last_vt.height
			nt.rotation = last_vt.rotation
		}
	}

	return nt
}

add_transformers :: proc(t1: ^Transformer, t2: ^Transformer) -> Transformer {
	nt: Transformer

	nt.lerp_mode = t1.lerp_mode
	nt.position.x = t1.position.x + t2.position.x
	nt.position.y = t1.position.y + t2.position.y
	nt.width = t1.width + t2.width
	nt.height = t1.height + t2.height
	nt.rotation = t1.rotation + t2.rotation

	return nt
}

lerp_transformers :: proc(
	t1: ^Transformer,
	t2: ^Transformer,
	f: f32,
	mode: LerpMode,
) -> Transformer {
	nt: Transformer // new transormer

	switch mode {
	case .Constant:
		nt.position = t1.position
		nt.rotation = t1.rotation
		nt.width = t1.width
		nt.height = t1.height
	case .Linear:
		nt.position.x = t1.position.x + ((t2.position.x - t1.position.x) * f)
		nt.position.y = t1.position.y + ((t2.position.y - t1.position.y) * f)
		nt.rotation = t1.rotation + ((t2.rotation - t1.rotation) * f)
		nt.width = t1.width + ((t2.width - t1.width) * f)
		nt.height = t1.height + ((t2.height - t1.height) * f)
	case .Sin:
		nf := la.sin(f * la.PI / 2.0) // new factor
		nt.position.x = t1.position.x + ((t2.position.x - t1.position.x) * nf)
		nt.position.y = t1.position.y + ((t2.position.y - t1.position.y) * nf)
		nt.rotation = t1.rotation + ((t2.rotation - t1.rotation) * nf)
		nt.width = t1.width + ((t2.width - t1.width) * nf)
		nt.height = t1.height + ((t2.height - t1.height) * nf)
	case .SmoothStep:
		nf := f32(math.smoothstep(0.0, 1.0, f64(f)))
		nt.position.x = t1.position.x + ((t2.position.x - t1.position.x) * nf)
		nt.position.y = t1.position.y + ((t2.position.y - t1.position.y) * nf)
		nt.rotation = t1.rotation + ((t2.rotation - t1.rotation) * nf)
		nt.width = t1.width + ((t2.width - t1.width) * nf)
		nt.height = t1.height + ((t2.height - t1.height) * nf)
	}


	return nt
}

RigStatus :: struct {
	is_talking:         bool,
	frame_time:         map[string]f32,
	idle_time:          f32,
	blink_time:         f32,
	cur_frame:          map[string]uint,
	preserve_talk_time: f32,
	z_layers:           []int,
}

default_rig_status :: proc() -> RigStatus {
	return RigStatus{false, {}, 0.0, 0.0, {}, 0.0, {}}
}

prepare_rig_status :: proc(rs: ^RigStatus, r: ^Rig) {
	for key, _ in r.sections {
		rs.frame_time[key] = 0.0
		rs.cur_frame[key] = 0
	}

	active_layers := make([dynamic]int)
	for key, value in r.sections {
		ok := slice.contains(active_layers[:], value.z_index)
		if !ok {
			append(&active_layers, value.z_index)
		}
	}
	slice.sort(active_layers[:])
	rs.z_layers = active_layers[:]
}

delete_rig_status :: proc(rs: ^RigStatus) {
	delete(rs.cur_frame)
	delete(rs.frame_time)
	delete(rs.z_layers)
}

load_rig :: proc(directory_path: string) -> (rig: ^Rig, ok: bool) {
	path, path_err := filepath.join({directory_path, "rig.json"})
	defer {
		if path_err == nil {
			delete(path)
		}
	}

	if !os.exists(path) {
		fmt.eprintfln("File %s does not exist", path)
		return nil, false
	}

	data, err := os.read_entire_file(path, context.allocator)
	defer {
		if err == nil {
			delete(data)
		}
	}


	if err != nil {
		fmt.eprintln("Failed to read file")
		return nil, false
	}

	rig = new(Rig)
	unmarshal_err := json.unmarshal(data, rig)
	if unmarshal_err == nil {
		rig.rig_path = directory_path
		return rig, true
	} else {
		delete_rig(rig)
		fmt.eprintln("Failed to unmarshal JSON", unmarshal_err)
	}

	return nil, false
}

delete_rig :: proc(rig: ^Rig) {
	if rig != nil {
		for key, &value in rig.frames {
			delete_frame(&value)
			delete(key)
		}
		delete(rig.frames)

		for key, &value in rig.sections {
			delete_animation_section(&value)
			delete(key)
		}
		delete(rig.sections)

		delete_rig_commands(&rig.on_idle)
		delete_rig_commands(&rig.on_talk)
		delete_rig_commands(&rig.on_action)
		delete_rig_commands(&rig.on_blink)

		free(rig)
	}
}

delete_frame_lib :: proc(tl: ^TextureLib) {
	for _, value in tl.textures {
		//no need to delete key, because Rig handles that already
		rl.UnloadTexture(value)
	}
	delete(tl.textures)
}

load_textures :: proc(tl: ^TextureLib, r: ^Rig) {
	for key, frame in r.frames {
		ok := frame.src in tl.textures
		if ok {
			continue
		}

		path, err := filepath.join({r.rig_path, frame.src})
		defer {
			if err == nil {
				delete(path)
			}
		}

		if err != nil {
			fmt.eprintln("Failed to parse file path")
			continue
		}

		if !os.exists(path) {
			fmt.eprintfln("Path %s does not exits", path)
			continue
		}

		path_clone := strings.clone_to_cstring(path)
		defer delete(path_clone)

		tl.textures[frame.src] = rl.LoadTexture(path_clone)
	}
}

get_texture_factor :: proc(
	r: ^Rig,
	section: string,
	frame_id: uint,
	remaining_frame_time: f32,
) -> f32 {
	frame, ok := get_frame(r, section, frame_id)
	if ok {
		return 1.0 - (remaining_frame_time / frame.time)
	}

	return 0.0
}

// loops back to the begining if frame larger than len
get_frame :: proc(r: ^Rig, section_name: string, frame_id: uint) -> (frame: ^Frame, ok: bool) {
	section, section_ok := r.sections[section_name]

	if !section_ok {
		return nil, false
	}

	frame_id := frame_id % len(section.frames)

	frame_name := section.frames[frame_id]

	ok2 := frame_name in r.frames

	if ok2 {
		return &r.frames[frame_name], true
	}
	return nil, false
}

process_rig_status :: proc(rs: ^RigStatus, r: ^Rig, delta: f32) -> (sections_changes: []string) {
	if r == nil {
		return {}
	}

	global_change := false

	rs.blink_time -= delta

	if rs.blink_time < 0.0 {
		rs.blink_time = r.blink_time
		for &command in r.on_blink {
			run_rig_command(r, &command)
		}
		fmt.println("Blink")
		global_change = true
	}

	db := get_db() // volume decibels
	talk := db > r.volume_threshhold

	if talk {
		rs.idle_time = 0.0
		if !rs.is_talking {
			for &command in r.on_talk {
				run_rig_command(r, &command)
			}
			fmt.println("Talk")
			global_change = true
		}
	} else {
		rs.idle_time += delta
		if rs.is_talking {
			for &command in r.on_idle {
				run_rig_command(r, &command)
			}
			fmt.println("Idle")
			global_change = true
		}

		if rs.idle_time >= r.idle_time {
			for &command in r.on_action {
				run_rig_command(r, &command)
			}
			rs.idle_time = 0.0
			fmt.println("Action")
			global_change = true
		}
	}

	rs.is_talking = talk

	modyfied_sections := [dynamic]string{}

	for section_name, section in r.sections {
		if !section.visible {
			continue
		}

		rs.frame_time[section_name] -= delta

		if rs.frame_time[section_name] < 0.0 {
			next_frame(rs, r, section_name)
			update_frame(rs, r, section_name)
			append(&modyfied_sections, section_name)

		} else if global_change {
			append(&modyfied_sections, section_name)
		}
	}

	return modyfied_sections[:]
}

next_frame :: proc(rs: ^RigStatus, r: ^Rig, section_name: string) {
	section, section_ok := r.sections[section_name]

	if !section_ok {
		return
	}

	cur_frame := rs.cur_frame[section_name]
	rs.cur_frame[section_name] = (cur_frame + 1) % len(section.frames)
}

update_frame :: proc(rs: ^RigStatus, r: ^Rig, section_name: string) {
	section, section_ok := r.sections[section_name]

	if !section_ok {
		return
	}

	frame_name := r.sections[section_name].frames[rs.cur_frame[section_name]]
	frame, ok := r.frames[frame_name]

	rs.frame_time[section_name] = frame.time
}

get_rig_rect :: proc(r: ^Rig) -> rl.Rectangle {
	min_x, max_x, min_y, max_y: f32
	for _, &frame in r.frames {
		x, y, width, height: f32
		x = frame.transform.position.x
		y = frame.transform.position.y
		width = frame.transform.width
		height = frame.transform.height

		if x < min_x {
			min_x = x
		}
		if x + width > max_x {
			max_x = x + width
		}
		if y < min_y {
			min_y = y
		}
		if y + height > max_y {
			max_y = y + height
		}
	}

	return rl.Rectangle{min_x, min_y, max_x - min_x, max_y - min_y}
}

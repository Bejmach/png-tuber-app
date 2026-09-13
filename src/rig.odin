#+feature dynamic-literals

package png_tuber

import "core:encoding/json"
import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

LerpMode :: enum {
	Constant,
	Linear,
	Sin,
	SmoothStep,
}

RigState :: enum {
	Idle,
	//Blink,
	Talk,
	Action,
}

TextureLib :: struct {
	textures: map[string]rl.Texture2D,
}

Rig :: struct {
	textures:               map[string]Texture,
	idle:                   AnimationData,
	//blink:              AnimationData,
	idle_actions:           AnimationData,
	idle_time:              f32,
	talk:                   AnimationData,
	//blink_time:         f32,
	window_anchor:          Anchor,
	window_anchor_offset:   la.Vector2f32,
	rotation_anchor:        Anchor,
	rotation_anchor_offset: la.Vector2f32,
	position_offset:        la.Vector2f32,
	rotation_offset:        la.Vector2f32,
	preserve_talk_time:     f32,
	rig_path:               string,
}

Texture :: struct {
	src:            string,
	time:           f32,
	transform:      Transformer,
	overwrite_tint: bool, // Prevents having default tint as black with alpha 0
	tint:           rl.Color,
}

delete_texture :: proc(t: ^Texture) {
	delete(t.src)
}

Transformer :: struct {
	lerp_mode:     LerpMode, //
	position:      la.Vector2f32,
	width, height: f32,
	rotation:      f32,
}

lerp_transformers :: proc(t1: ^Transformer, t2: ^Transformer, f: f32) -> Transformer {
	lerp_mode := t1.lerp_mode

	nt: Transformer // new transormer

	switch lerp_mode {
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
	state:              RigState,
	frame_time:         f32,
	idle_time:          f32,
	//blink_time:         f32,
	cur_frame:          uint,
	preserve_talk_time: f32,
}

AnimationSection :: struct {
	textures: []string,
}

delete_anition_section :: proc(as: ^AnimationSection) {
	for texture in as.textures {
		delete(texture)
	}
	delete(as.textures)
}

AnimationData :: struct {
	section:   AnimationSection,
	randomise: bool,
}

delete_animation_data :: proc(ad: ^AnimationData) {
	delete_anition_section(&ad.section)
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
		for key, &value in rig.textures {
			delete_texture(&value)
			delete(key)
		}
		delete(rig.textures)

		delete_animation_data(&rig.idle_actions)
		delete_animation_data(&rig.talk)
		delete_animation_data(&rig.idle)

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
	for key, frame in r.textures {
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

default_rig_status :: proc() -> RigStatus {
	return RigStatus{.Idle, 0.0, 0.0, 0, 0.0}
}

get_texture_factor :: proc(
	r: ^Rig,
	state: RigState,
	frame: uint,
	remaining_frame_time: f32,
) -> f32 {
	texture, ok := get_texture(r, state, frame)
	if ok {
		return 1.0 - (remaining_frame_time / texture.time)
	}

	return 0.0
}

// loops back to the begining if frame larger than len
get_texture :: proc(r: ^Rig, state: RigState, frame: uint) -> (texture: ^Texture, ok: bool) {
	frame_name: string
	switch state {
	case .Idle:
		idle_len := len(r.idle.section.textures)
		if idle_len == 0 {
			return nil, false
		}
		frame := frame % uint(idle_len)
		frame_name = r.idle.section.textures[frame]
	case .Talk:
		talk_len := len(r.talk.section.textures)
		if talk_len == 0 {
			return nil, false
		}
		frame := frame % uint(talk_len)
		frame_name = r.talk.section.textures[frame]
	case .Action:
		action_len := len(r.idle_actions.section.textures)
		if action_len == 0 {
			return nil, false
		}
		frame := frame % uint(action_len)
		frame_name = r.idle_actions.section.textures[frame]
	//case .Blink:
	//	frame_name = r.blink.section.textures[frame]
	}

	ok2 := frame_name in r.textures

	if ok2 {
		return &r.textures[frame_name], true
	}
	return nil, false
}

process_rig_status :: proc(rs: ^RigStatus, r: ^Rig, delta: f32) -> (frame_change: bool) {
	if r == nil {
		return false
	}

	rs.frame_time -= delta
	//rs.blink_time += delta

	db := get_db() // volume decibels

	talk := db > -50

	switch rs.state {
	case .Idle:
		if talk {
			return switch_state(rs, r, .Talk)
		} else {
			rs.idle_time += delta
			if rs.idle_time > r.idle_time {
				return switch_state(rs, r, .Action)
			}
			if rs.frame_time < 0.0 {
				next_frame(rs, r)
				update_frame(rs, r)
				return true
			}
		}
	case .Talk:
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			update_frame(rs, r)
			return true
		}
		if !talk {
			rs.preserve_talk_time += delta
			if rs.preserve_talk_time > r.preserve_talk_time {
				return switch_state(rs, r, .Idle)
			}
		} else {
			rs.preserve_talk_time = 0.0
		}
	case .Action:
		if talk {
			return switch_state(rs, r, .Talk)
		}
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			update_frame(rs, r)
			return true
		}
	/*case .Blink:
		if talk {
			return switch_state(rs, r, .Talk)
		}
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			return true
		}
	*/
	}
	return false
}

next_frame :: proc(rs: ^RigStatus, r: ^Rig) {
	switch rs.state {
	case .Idle:
		idle_len := len(r.idle.section.textures)
		if idle_len > 0 {
			rs.cur_frame = (rs.cur_frame + 1) % len(r.idle.section.textures)
		}
	case .Talk:
		idle_len := len(r.talk.section.textures)
		if idle_len > 0 {
			rs.cur_frame = (rs.cur_frame + 1) % len(r.talk.section.textures)
		}
	case .Action:
		idle_len := len(r.idle_actions.section.textures)
		if idle_len > 0 {
			rs.cur_frame = (rs.cur_frame + 1) % len(r.idle_actions.section.textures)
		}
	/*case .Blink:
		idle_len := len(r.blink.section.textures)
		if idle_len > 0{
			rs.cur_frame = (rs.cur_frame + 1) % len(r.blink.section.textures)
		}
	*/
	}
}

update_frame :: proc(rs: ^RigStatus, r: ^Rig) {
	switch rs.state {
	case .Idle:
		if len(r.idle.section.textures) == 0 {
			break
		}
		frame_name := r.idle.section.textures[rs.cur_frame]
		frame, ok := r.textures[frame_name]

		rs.frame_time = frame.time
	case .Talk:
		if len(r.talk.section.textures) == 0 {
			break
		}
		frame_name := r.talk.section.textures[rs.cur_frame]
		frame, ok := r.textures[frame_name]

		rs.frame_time = frame.time
	case .Action:
		if len(r.idle_actions.section.textures) == 0 {
			break
		}
		frame_name := r.idle_actions.section.textures[rs.cur_frame]
		frame, ok := r.textures[frame_name]

		rs.frame_time = frame.time
	/*case .Blink:
		if len(r.blink.section.textures) == 0 {
			break
		}
		rs.cur_frame_name = r.blink.textures[rs.cur_frame[0]][rs.cur_frame[1]]
		frame, ok := r.textures[rs.cur_frame_name]

		rs.frame_time = get_frame_time(&frame, r)
	*/
	}
}

switch_state :: proc(rs: ^RigStatus, r: ^Rig, state: RigState) -> (state_changed: bool) {
	switch state {
	case .Idle:
		if len(r.idle.section.textures) == 0 {
			return false
		}
	case .Talk:
		rs.idle_time = 0.0
		if len(r.talk.section.textures) == 0 {
			return false
		}
	case .Action:
		rs.idle_time = 0.0
		if len(r.idle_actions.section.textures) == 0 {
			return false
		}
	//case .Blink:
	//	if len(r.blink.textures) == 0 {
	//		return false
	//	}
	}

	rs.state = state
	rs.cur_frame = 0
	return true
}

get_rig_rect :: proc(r: ^Rig) -> rl.Rectangle {
	min_x, max_x, min_y, max_y: f32
	for _, &frame in r.textures {
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

/*

next_frame :: proc(rs: ^RigStatus, r: ^Rig) {
	switch rs.state {
	case .Idle:
		if len(r.idle.textures) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.idle.textures[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			next_section(rs, r)
			rs.cur_frame[1] = 0
		}
		update_frame(rs, r)
	case .Talk:
		if len(r.talk.textures) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.talk.textures[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			next_section(rs, r)
			rs.cur_frame[1] = 0
		}
		update_frame(rs, r)
	case .Action:
		if len(r.idle_actions.textures) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.idle_actions.textures[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			switch_state(rs, r, .Idle)
		}
		update_frame(rs, r)
	case .Blink:
		if len(r.blink.textures) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.blink.textures[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			switch_state(rs, r, .Idle)
		}
		update_frame(rs, r)
	}
}



next_section :: proc(rs: ^RigStatus, r: ^Rig, move_by: uint = 1) {
	switch rs.state {
	case .Idle:
		if len(r.idle.textures) == 0 {
			break
		}
		if r.idle.randomise {
			rs.cur_frame[0] = rand.uint_range(0, len(r.idle.textures))
		} else {
			rs.cur_frame[0] = (rs.cur_frame[0] + move_by) % len(r.idle.textures)
		}
	case .Talk:
		if len(r.talk.textures) == 0 {
			break
		}
		if r.talk.randomise {
			rs.cur_frame[0] = rand.uint_range(0, len(r.talk.textures))
		} else {
			rs.cur_frame[0] = (rs.cur_frame[0] + move_by) % len(r.talk.textures)
		}
	case .Action:
		if len(r.idle_actions.textures) == 0 {
			break
		}
		rs.cur_frame[0] = rand.uint_range(0, len(r.idle_actions.textures))
	case .Blink:
		if len(r.blink.textures) == 0 {
			break
		}
		rs.cur_frame[0] = rand.uint_range(0, len(r.blink.textures))
	}
}

delete_frame :: proc(f: ^Frame) {
	delete_position(&f.position)
	delete(f.src)
}

get_frame_rotation :: proc(f: ^Frame, r: ^Rig) -> f32 {
	if !f.overwrite_rotation {
		rand_rotation: f32
		if r.random_rotation_offset[0] < r.random_rotation_offset[1] {
			rand_rotation = rand.float32_range(
				r.random_rotation_offset[0],
				r.random_rotation_offset[1],
			)
		}

		return r.rotation + rand_rotation
	}

	rand_rotation: f32
	if f.random_rotation_offset[0] < f.random_rotation_offset[1] {
		rand_rotation = rand.float32_range(
			f.random_rotation_offset[0],
			f.random_rotation_offset[1],
		)
	}


	return(
		f.rotation +
		rand.float32_range(f.random_rotation_offset[0], f.random_rotation_offset[1]) \
	)
}

get_frame_tint :: proc(f: ^Frame, r: ^Rig) -> rl.Color {
	if !f.overwrite_tint {
		if !r.frame_tint {
			return rl.WHITE
		}

		rand_r, rand_g, rand_b, rand_a: u8

		if r.random_tint_offset[0][0] < r.random_tint_offset[0][1] {
			rand_r = u8(rand.int32_range(r.random_tint_offset[0][0], r.random_tint_offset[0][1]))
		}
		if r.random_tint_offset[1][0] < r.random_tint_offset[1][1] {
			rand_g = u8(rand.int32_range(r.random_tint_offset[1][0], r.random_tint_offset[1][1]))
		}
		if r.random_tint_offset[2][0] < r.random_tint_offset[2][1] {
			rand_b = u8(rand.int32_range(r.random_tint_offset[2][0], r.random_tint_offset[2][1]))
		}
		if r.random_tint_offset[3][0] < r.random_tint_offset[3][1] {
			rand_a = u8(rand.int32_range(r.random_tint_offset[3][0], r.random_tint_offset[3][1]))
		}

		r_c := math.clamp(r.tint.r + rand_r, 0, 255)
		g_c := math.clamp(r.tint.g + rand_g, 0, 255)
		b_c := math.clamp(r.tint.b + rand_b, 0, 255)
		a_c := math.clamp(r.tint.a + rand_a, 0, 255)

		return rl.Color{r_c, g_c, b_c, a_c}

	} else {
		rand_r, rand_g, rand_b, rand_a: u8

		if f.random_tint_offset[0][0] != f.random_tint_offset[0][1] {
			rand_r = u8(rand.int32_range(f.random_tint_offset[0][0], f.random_tint_offset[0][1]))
		}
		if f.random_tint_offset[1][0] != f.random_tint_offset[1][1] {
			rand_g = u8(rand.int32_range(f.random_tint_offset[1][0], f.random_tint_offset[1][1]))
		}
		if f.random_tint_offset[2][0] != f.random_tint_offset[2][1] {
			rand_b = u8(rand.int32_range(f.random_tint_offset[2][0], f.random_tint_offset[2][1]))
		}
		if f.random_tint_offset[3][0] != f.random_tint_offset[3][1] {
			rand_a = u8(rand.int32_range(f.random_tint_offset[3][0], f.random_tint_offset[3][1]))
		}

		r_c := math.clamp(f.tint.r + rand_r, 0, 255)
		g_c := math.clamp(f.tint.g + rand_g, 0, 255)
		b_c := math.clamp(f.tint.b + rand_b, 0, 255)
		a_c := math.clamp(f.tint.a + rand_a, 0, 255)

		return rl.Color{r_c, g_c, b_c, a_c}
	}
}

delete_frame_data :: proc(fd: ^FrameData) {
	for textures in fd.textures {
		for frame in textures {
			delete(frame)
		}
		delete(textures)
	}
	delete(fd.textures)
}

delete_position :: proc(p: ^Position) {
	delete(p.positions)
}

get_position :: proc(p: ^Position) -> la.Vector2f32 {
	if p.use_range {
		x: f32 = rand.float32_range(p.range_x[0], p.range_x[1])
		y: f32 = rand.float32_range(p.range_y[0], p.range_y[1])

		return la.Vector2f32{x, y}
	}

	if len(p.positions) > 0 {
		id := rand.uint_range(0, len(p.positions))
		return p.positions[id]
	}
	return {0, 0}
}
*/

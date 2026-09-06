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

FrameLib :: struct {
	frames: map[string]rl.Texture2D,
}

delete_frame_lib :: proc(fl: ^FrameLib) {
	for _, value in fl.frames {
		//no need to delete key, because Rig handles that already
		rl.UnloadTexture(value)
	}
	delete(fl.frames)
}

load_textures :: proc(fl: ^FrameLib, r: ^Rig) {
	for key, frame in r.frames {
		ok := frame.src in fl.frames
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

		fl.frames[frame.src] = rl.LoadTexture(path_clone)
	}
}

RigState :: enum {
	Idle,
	Blink,
	Talk,
	Action,
}

RigStatus :: struct {
	state:              RigState,
	frame_time:         f32,
	idle_time:          f32,
	blink_time:         f32,
	cur_frame:          [2]uint,
	cur_frame_name:     string,
	preserve_talk_time: f32,
}

default_rig_status :: proc() -> RigStatus {
	return RigStatus{.Idle, 0.0, 0.0, 0.0, {0, 0}, "", 0.0}
}

process_rig_status :: proc(rs: ^RigStatus, r: ^Rig, delta: f32) -> (frame_change: bool) {
	if r == nil {
		return false
	}

	rs.frame_time -= delta
	rs.blink_time += delta

	db := get_db()

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
			if rs.blink_time > r.blink_time {
				rs.blink_time = 0
				return switch_state(rs, r, .Blink)
			}
			if rs.frame_time < 0.0 {
				next_frame(rs, r)
				return true
			}
		}

	case .Action:
		if talk {
			return switch_state(rs, r, .Talk)
		}
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			return true
		}
	case .Blink:
		if talk {
			return switch_state(rs, r, .Talk)
		}
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			return true
		}

	case .Talk:
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
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
	}
	return false
}

next_frame :: proc(rs: ^RigStatus, r: ^Rig) {
	switch rs.state {
	case .Idle:
		if len(r.idle.frames) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.idle.frames[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			next_section(rs, r)
			rs.cur_frame[1] = 0
		}
		update_frame(rs, r)
	case .Talk:
		if len(r.talk.frames) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.talk.frames[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			next_section(rs, r)
			rs.cur_frame[1] = 0
		}
		update_frame(rs, r)
	case .Action:
		if len(r.idle_actions.frames) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.idle_actions.frames[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			switch_state(rs, r, .Idle)
		}
		update_frame(rs, r)
	case .Blink:
		if len(r.blink.frames) == 0 {
			break
		}
		rs.cur_frame[1] += 1
		rig_section := r.blink.frames[rs.cur_frame[0]]
		if rs.cur_frame[1] >= len(rig_section) {
			switch_state(rs, r, .Idle)
		}
		update_frame(rs, r)
	}
}

get_frame :: proc(rs: ^RigStatus, r: ^Rig) -> (return_frame: ^Frame, ok: bool) {
	ok2 := rs.cur_frame_name in r.frames

	if ok2 {
		return &r.frames[rs.cur_frame_name], true
	}
	return {}, false

}

next_section :: proc(rs: ^RigStatus, r: ^Rig, move_by: uint = 1) {
	switch rs.state {
	case .Idle:
		if len(r.idle.frames) == 0 {
			break
		}
		if r.idle.randomise {
			rs.cur_frame[0] = rand.uint_range(0, len(r.idle.frames))
		} else {
			rs.cur_frame[0] = (rs.cur_frame[0] + move_by) % len(r.idle.frames)
		}
	case .Talk:
		if len(r.talk.frames) == 0 {
			break
		}
		if r.talk.randomise {
			rs.cur_frame[0] = rand.uint_range(0, len(r.talk.frames))
		} else {
			rs.cur_frame[0] = (rs.cur_frame[0] + move_by) % len(r.talk.frames)
		}
	case .Action:
		if len(r.idle_actions.frames) == 0 {
			break
		}
		rs.cur_frame[0] = rand.uint_range(0, len(r.idle_actions.frames))
	case .Blink:
		if len(r.blink.frames) == 0 {
			break
		}
		rs.cur_frame[0] = rand.uint_range(0, len(r.blink.frames))
	}
}

update_frame :: proc(rs: ^RigStatus, r: ^Rig) {
	switch rs.state {
	case .Idle:
		if len(r.idle.frames) == 0 {
			break
		}
		rs.cur_frame_name = r.idle.frames[rs.cur_frame[0]][rs.cur_frame[1]]
		frame, ok := r.frames[rs.cur_frame_name]

		rs.frame_time = get_frame_time(&frame, r)
	case .Talk:
		if len(r.talk.frames) == 0 {
			break
		}
		rs.cur_frame_name = r.talk.frames[rs.cur_frame[0]][rs.cur_frame[1]]
		frame, ok := r.frames[rs.cur_frame_name]

		rs.frame_time = get_frame_time(&frame, r)
	case .Action:
		if len(r.idle_actions.frames) == 0 {
			break
		}
		rs.cur_frame_name = r.idle_actions.frames[rs.cur_frame[0]][rs.cur_frame[1]]
		frame, ok := r.frames[rs.cur_frame_name]

		rs.frame_time = get_frame_time(&frame, r)
	case .Blink:
		if len(r.blink.frames) == 0 {
			break
		}
		rs.cur_frame_name = r.blink.frames[rs.cur_frame[0]][rs.cur_frame[1]]
		frame, ok := r.frames[rs.cur_frame_name]

		rs.frame_time = get_frame_time(&frame, r)
	}
}

switch_state :: proc(rs: ^RigStatus, r: ^Rig, state: RigState) -> (state_changed: bool) {
	switch state {
	case .Idle:
		if len(r.idle.frames) == 0 {
			return false
		}
	case .Talk:
		rs.idle_time = 0.0
		if len(r.talk.frames) == 0 {
			return false
		}
	case .Action:
		rs.idle_time = 0.0
		if len(r.idle_actions.frames) == 0 {
			return false
		}
	case .Blink:
		if len(r.blink.frames) == 0 {
			return false
		}
	}

	rs.state = state
	rs.cur_frame = {0, 0}
	next_section(rs, r, 0)
	update_frame(rs, r)
	return true
}

Rig :: struct {
	frames:                 map[string]Frame,
	idle:                   FrameData,
	blink:                  FrameData,
	idle_actions:           FrameData,
	idle_time:              f32,
	talk:                   FrameData,
	blink_time:             f32,
	window_anchor:          Anchor,
	rotation_anchor:        Anchor,
	position_offset:        la.Vector2f32,
	preserve_talk_time:     f32,
	overwrite_size:         bool,
	width:                  f32,
	height:                 f32,
	rig_path:               string,
	frame_time:             f32,
	random_time_offset:     [2]f32,
	rotation:               f32,
	random_rotation_offset: [2]f32,
	frame_tint:             bool,
	tint:                   rl.Color,
	random_tint_offset:     [4][2]i32,
}

Frame :: struct {
	src:                    string,
	overwrite_time:         bool,
	frame_time:             f32,
	random_time_offset:     [2]f32,
	position:               Position,
	overwrite_size:         bool,
	width:                  f32,
	height:                 f32,
	overwrite_rotation:     bool,
	rotation:               f32,
	random_rotation_offset: [2]f32,
	overwrite_tint:         bool, // Prevents having default tint as black with alpha 0
	tint:                   rl.Color,
	random_tint_offset:     [4][2]i32,
}

delete_frame :: proc(f: ^Frame) {
	delete_position(&f.position)
	delete(f.src)
}

get_frame_size :: proc(f: ^Frame, r: ^Rig) -> [2]f32 {
	if !f.overwrite_size {
		return {r.width, r.height}
	}
	return {f.width, f.height}
}

get_rig_size :: proc(r: ^Rig) -> [2]f32 {
	biggest: [2]f32 = {0.0, 0.0}
	for _, &frame in r.frames {
		size: [2]f32 = get_frame_size(&frame, r)
		if size.x > biggest.x{
			biggest.x = size.x
		}
		if size.y > biggest.y{
			biggest.y = size.y
		}
	}

	return biggest
}

get_frame_time :: proc(f: ^Frame, r: ^Rig) -> f32 {
	if !f.overwrite_time {
		rand_time: f32
		if r.random_time_offset[0] < r.random_time_offset[1] {
			rand_time = rand.float32_range(r.random_time_offset[0], r.random_time_offset[1])
		}

		return math.max(r.frame_time + rand_time, 0)

	}

	rand_time: f32
	if f.random_time_offset[0] < f.random_time_offset[1] {
		rand_time = rand.float32_range(f.random_time_offset[0], f.random_time_offset[1])
	}

	return math.max(f.frame_time + rand_time, 0)
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

FrameData :: struct {
	frames:    [][]string,
	randomise: bool,
}

delete_frame_data :: proc(fd: ^FrameData) {
	for frames in fd.frames {
		for frame in frames {
			delete(frame)
		}
		delete(frames)
	}
	delete(fd.frames)
}

Position :: struct {
	positions: []la.Vector2f32,
	range_x:   [2]f32,
	range_y:   [2]f32,
	use_range: bool,
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
			delete(key)
			delete_frame(&value)
		}
		delete(rig.frames)

		delete_frame_data(&rig.idle)
		delete_frame_data(&rig.idle_actions)
		delete_frame_data(&rig.talk)
		delete_frame_data(&rig.blink)

		free(rig)
	}
}

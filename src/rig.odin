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
	Talk,
	Action,
}

RigStatus :: struct {
	state:              RigState,
	frame_time:         f32,
	idle_time:          f32,
	cur_frame:          [2]uint,
	cur_frame_name:     string,
	preserve_talk_time: f32,
}

default_rig_status :: proc() -> RigStatus {
	return RigStatus{.Idle, 0.0, 0.0, {0, 0}, "", 0.0}
}

process_rig_status :: proc(rs: ^RigStatus, r: ^Rig, delta: f32) -> (frame_change: bool) {
	rs.frame_time -= delta
	db := get_db()

	talk := db > -50

	switch rs.state {
	case .Idle:
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			return true
		}
		if talk {
			switch_state(rs, r, .Talk)
			return true
		} else {
			rs.idle_time += delta
			if rs.idle_time > r.idle_time {
				switch_state(rs, r, .Action)
				return true
			}
		}
	case .Action:
		if rs.frame_time < 0.0 {
			//next_frame()
		}
	case .Talk:
		if rs.frame_time < 0.0 {
			next_frame(rs, r)
			return true
		}
		if !talk {
			rs.preserve_talk_time += delta
			if rs.preserve_talk_time > r.preserve_talk_time {
				switch_state(rs, r, .Idle)
				return true
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
	}
}

get_frame :: proc(rs: ^RigStatus, r: ^Rig) -> (return_frame: Frame, ok: bool) {
	frame, ok2 := r.frames[rs.cur_frame_name]

	if ok2 {
		return frame, true
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

		if ok {
			rs.frame_time = get_frame_time(&frame)
		} else {
			rs.frame_time = r.default_frame_time
		}
	case .Talk:
		if len(r.talk.frames) == 0 {
			break
		}
		rs.cur_frame_name = r.talk.frames[rs.cur_frame[0]][rs.cur_frame[1]]
		frame, ok := r.frames[rs.cur_frame_name]

		if ok {
			rs.frame_time = get_frame_time(&frame)
		} else {
			rs.frame_time = r.default_frame_time
		}
	case .Action:
	}
}

switch_state :: proc(rs: ^RigStatus, r: ^Rig, state: RigState) {
	fmt.println(state)
	rs.state = state
	rs.idle_time = 0.0
	rs.cur_frame = {0, 0}
	next_section(rs, r, 0)
	update_frame(rs, r)
}

Rig :: struct {
	frames:             map[string]Frame,
	idle:               FrameData,
	idle_actions:       FrameData,
	idle_time:          f32,
	talk:               FrameData,
	blink_time:         f32,
	window_anchor:      Anchor,
	rotation_anchor:    Anchor,
	position_offset:    la.Vector2f32,
	preserve_talk_time: f32,
	default_frame_time: f32,
	rig_path:           string,
}

Frame :: struct {
	src:                    string,
	frame_time:             f32,
	random_time_offset:     f32,
	position:               Position,
	overwrite_size:         bool,
	width:                  f32,
	height:                 f32,
	rotation:               f32,
	random_rotation_offset: f32,
}

delete_frame :: proc(f: ^Frame) {
	delete_position(&f.position)
	delete(f.src)
}

get_frame_time :: proc(f: ^Frame) -> f32 {
	return math.max(
		f.frame_time + rand.float32_range(-f.random_time_offset, f.random_time_offset),
		0,
	)
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
	if json.unmarshal(data, rig) == nil {
		rig.rig_path = directory_path
		return rig, true
	} else {
		delete_rig(rig)
		fmt.eprintln("Failed to unmarshal JSON")
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

		free(rig)
	}
}

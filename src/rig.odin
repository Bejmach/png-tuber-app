#+feature dynamic-literals

package png_tuber

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/rand"
import la "core:math/linalg"
import "core:os"

RigState :: enum {
	Idle,
	Talk,
	Action,
}

RigStatus :: struct {}

Rig :: struct {
	frames:       map[string]Frame,
	idle:         FrameData,
	idle_actions: FrameData,
	idle_time:    f32,
	talking:      FrameData,
	blink_time:   f32,
}

Frame :: struct {
	img_path:   string,
	frame_time: f32,
	width:      f32,
	height:     f32,
	anchor:     Anchor,
}

delete_frame :: proc(f: ^Frame) {
	delete(f.img_path)
}

FrameData :: struct {
	frames:    [][]string,
	position:  Position,
	randomise: bool,
	cur_frame: [2]uint
}

delete_frame_data :: proc(fd: ^FrameData) {
	for frames in fd.frames {
		for frame in frames {
			delete(frame)
		}
		delete(frames)
	}
	delete(fd.frames)

	delete_position(&fd.position)
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

get_position :: proc(p: ^Position) -> la.Vector2f32{
	if p.use_range{
		x: f32 = rand.float32_range(p.range_x[0], p.range_x[1])
		y: f32 = rand.float32_range(p.range_y[0], p.range_y[1])

		return la.Vector2f32{x, y}
	}

	id := rand.uint_range(0, len(p.positions))
	return p.positions[id]
}

load_rig :: proc(path: string) -> (rig: ^Rig, ok: bool) {
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
		delete_frame_data(&rig.talking)

		free(rig)
	}
}

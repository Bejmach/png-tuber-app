package png_tuber

import "core:encoding/json"
import "core:fmt"
import "core:os"

import rl "vendor:raylib"

Settings :: struct {
	background_color: rl.Color,
	rig_paths:        []string,
}

default_settings :: proc() -> ^Settings{
	s: ^Settings = new(Settings)
	s.background_color = rl.Color{0, 255, 0, 255}

	return s
}

load_settings :: proc(path: string) -> (settings: ^Settings, ok: bool) {
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

	settings = new(Settings)
	unmarshal_err := json.unmarshal(data, settings)
	if unmarshal_err == nil {
		return settings, true
	} else {
		delete_settings(settings)
		fmt.eprintln("Failed to unmarshal JSON", unmarshal_err)
	}

	return nil, false
}

save_settings :: proc(path: string, s: ^Settings) -> bool {
	data, err := json.marshal(s^, allocator = context.allocator)
	defer {
		if err == nil {
			delete(data)
		}
	}

	if err != nil {
		fmt.eprintln("Failed to parse struct to json", err)
		return false
	}

	if os.write_entire_file(path, data) != nil {
		fmt.eprintln("Failed to write file")
		return false
	}

	return true
}

delete_settings :: proc(s: ^Settings) {
	for path in s.rig_paths {
		delete(path)
	}
	delete(s.rig_paths)

	free(s)
}

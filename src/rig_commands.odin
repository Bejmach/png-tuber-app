package png_tuber

import "core:fmt"
import "core:reflect"
import "core:strings"
RigAction :: enum {
	Enable_Section,
	Disable_Section,
	Toggle_Section,
	Print_Params,
	Set_Param,
	Reset_Section,
	Run_Bind, // can't run from bind
}

RigCommand :: struct {
	action: RigAction,
	params: []string,
}

run_rig_command :: proc(r: ^Rig, rs: ^RigStatus, command: ^RigCommand) {
	parsed_params := make([]string, len(command.params))
	defer delete(parsed_params)

	for param, id in command.params {
		if param[0] == '$' {
			param_name := param[1:]
			value, ok := r.params[param_name]

			if ok {
				parsed_params[id] = value
			} else {
				fmt.eprintln("Param", param_name, "not found in rig params")
				return
			}
		} else {
			parsed_params[id] = param
		}
	}

	switch command.action {
	case .Enable_Section:
		comm_enable_section(r, rs, parsed_params)
	case .Disable_Section:
		comm_disable_section(r, rs, parsed_params)
	case .Toggle_Section:
		comm_toggle_section(r, rs, parsed_params)
	case .Reset_Section:
		comm_reset_section(r, rs, parsed_params)
	case .Set_Param:
		comm_set_param(r, parsed_params)
	case .Print_Params:
		fmt.println(r.params)
	case .Run_Bind:
		comm_run_bind(r, rs, parsed_params)
	}
}

comm_reset_section :: proc(r: ^Rig, rs: ^RigStatus, sections: []string){
	for section_name in sections{
		section, ok := &r.sections[section_name]
		if ok{
			rs.frame_time[section_name] = 0
			if len(section.frames) > 0{
				frame, ok := r.frames[section.frames[0]]
				if ok{
					rs.frame_time[section_name] = frame.time
				}
			}
			rs.cur_frame[section_name] = 0
			rs.frame_direction[section_name] = 1
		}
	}
}

comm_enable_section :: proc(r: ^Rig, rs: ^RigStatus, sections: []string) {
	for section_name in sections {
		section, ok := &r.sections[section_name]
		if ok {
			section.visible = true
			if section.reset_on_enter {
				rs.cur_frame[section_name] = 0
				rs.frame_time[section_name] = 0
			}
		}
	}
}

comm_disable_section :: proc(r: ^Rig, rs: ^RigStatus, sections: []string) {
	for section_name in sections {
		section, ok := &r.sections[section_name]
		if ok {
			section.visible = false
		}
	}
}

comm_toggle_section :: proc(r: ^Rig, rs: ^RigStatus, sections: []string) {
	for section_name in sections {
		section, ok := &r.sections[section_name]
		if ok {
			section.visible = !section.visible
			if section.visible && section.reset_on_enter {
				rs.cur_frame[section_name] = 0
				rs.frame_time[section_name] = 0
			}
		}
	}
}

comm_set_param :: proc(r: ^Rig, params: []string) {
	if len(params) > 0 && len(params) % 2 == 0 {
		for i := 0; i < len(params); i += 2 {
			key := strings.clone(params[i])
			value := strings.clone(params[i+1])
			r.params[key] = value
		}
	}
}

comm_run_bind :: proc(r: ^Rig, rs: ^RigStatus, binds: []string) {
	for bind_name in binds {
		bind, ok := r.binds[bind_name]
		for &command in bind.commands {
			if command.action != .Run_Bind {
				run_rig_command(r, rs, &command)
			}
		}
	}
}

parse_command :: proc(command: string) -> []RigCommand {
	trimmed, trim_alloc := strings.replace_all(command, " ", "")
	defer {
		if trim_alloc {
			delete(trimmed)
		}
	}

	parsed_commands := make([dynamic]RigCommand)

	commands := strings.split(trimmed, ";")
	defer {
		delete(commands)
	}

	for command in commands {
		if len(command) == 0 {
			continue
		}
		params_start := strings.index(command, "(")

		if params_start == -1 {
			action, ok := reflect.enum_from_name(RigAction, command)

			if !ok {
				continue
			}

			parsed_command := RigCommand{action, {}}
			append(&parsed_commands, parsed_command)
			continue
		}

		params_end := strings.index(command, ")")

		action_name := command[:params_start]
		action, ok := reflect.enum_from_name(RigAction, action_name)

		if !ok {
			continue
		}

		params_str := command[params_start + 1:params_end]
		params := strings.split(params_str, ",")

		// Needs to clone because json parser allocates each param, and split does not
		// which lead to delete_rig_commands not being able to delete param in string split
		for i := 0; i < len(params); i += 1 {
			params[i] = strings.clone(params[i])
		}

		parsed_command := RigCommand{action, params}
		append(&parsed_commands, parsed_command)
	}

	return parsed_commands[:]
}

delete_rig_commands :: proc(rc_s: ^[]RigCommand) {
	for &command in rc_s {
		for param in command.params {
			delete(param)
		}
		delete(command.params)
	}

	delete(rc_s^)
}

package png_tuber

import "core:reflect"
import "core:strings"
RigAction :: enum {
	Enable_Section,
	Disable_Section,
}

RigCommand :: struct {
	action: RigAction,
	params: []string,
}

parse_command :: proc(command: string) -> []RigCommand {
	trimmed, trim_alloc := strings.replace_all(command, " ", "")
	defer {
		if trim_alloc{
			delete(trimmed)
		}
	}

	parsed_commands := make([dynamic]RigCommand)

	commands := strings.split(trimmed, ";")
	defer {
		delete(commands)
	}

	for command in commands{
		if len(command) == 0{
			continue
		}
		params_start := strings.index(command, "(")
		params_end := strings.index(command, ")")

		action_name := command[:params_start]
		action, ok := reflect.enum_from_name(RigAction, action_name)

		if !ok{
			continue
		}

		params_str := command[params_start+1:params_end]
		params := strings.split(params_str, ",")

		parsed_command := RigCommand{action, params}
		append(&parsed_commands, parsed_command)
	}

	return parsed_commands[:]
}

delete_rig_commands :: proc(rc_s: ^[]RigCommand){
	for &command in rc_s{
		delete(command.params)
	}

	delete(rc_s^)
}

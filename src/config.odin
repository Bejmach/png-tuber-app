package png_tuber

import "core:encoding/ini"

import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

Config :: struct {
	fps: i32,
	vsync: bool,
	width, height: i32,
	background_color: rl.Color,
}

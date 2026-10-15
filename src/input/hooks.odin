package input

import rl "vendor:raylib"
import "../config"

when config.IS_AUTOTEST {

KEY_CAP :: 512

Virtual_Input :: struct {
	down:    [KEY_CAP]bool,
	pressed: [KEY_CAP]bool,
}

virtual: Virtual_Input

key_index :: proc(key: rl.KeyboardKey) -> int {
	i := int(key)
	if i < 0 || i >= KEY_CAP {
		return -1
	}
	return i
}

begin_frame :: proc() {
	for i in 0 ..< KEY_CAP {
		virtual.pressed[i] = false
	}
}

press :: proc(key: rl.KeyboardKey) {
	i := key_index(key)
	if i < 0 {
		return
	}
	virtual.down[i] = true
	virtual.pressed[i] = true
}

set_down :: proc(key: rl.KeyboardKey, down: bool) {
	i := key_index(key)
	if i < 0 {
		return
	}
	virtual.down[i] = down
}

clear_movement :: proc() {
	set_down(.A, false)
	set_down(.D, false)
	set_down(.LEFT, false)
	set_down(.RIGHT, false)
	set_down(.LEFT_SHIFT, false)
	set_down(.F, false)
	set_down(.B, false)
}

key_down :: proc(key: rl.KeyboardKey) -> bool {
	i := key_index(key)
	if i >= 0 && virtual.down[i] {
		return true
	}
	return rl.IsKeyDown(key)
}

key_pressed :: proc(key: rl.KeyboardKey) -> bool {
	i := key_index(key)
	if i >= 0 && virtual.pressed[i] {
		return true
	}
	return rl.IsKeyPressed(key)
}

}

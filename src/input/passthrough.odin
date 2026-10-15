package input

import rl "vendor:raylib"
import "../config"

when !config.IS_AUTOTEST {

begin_frame :: proc() {}

press :: proc(key: rl.KeyboardKey) {
	_ = key
}

set_down :: proc(key: rl.KeyboardKey, down: bool) {
	_, _ = key, down
}

clear_movement :: proc() {}

key_down :: proc(key: rl.KeyboardKey) -> bool {
	return rl.IsKeyDown(key)
}

key_pressed :: proc(key: rl.KeyboardKey) -> bool {
	return rl.IsKeyPressed(key)
}

}

package game

import "core:strings"
import rl "vendor:raylib"

init_window :: proc(g: ^Game) {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(
		auto_cast g.window_size.x,
		auto_cast g.window_size.y,
		strings.clone_to_cstring(g.defs.title),
	)

	monitor_id := rl.GetCurrentMonitor()
	monitor_w := rl.GetMonitorWidth(monitor_id)
	monitor_h := rl.GetMonitorHeight(monitor_id)

	rl.SetWindowPosition(
		(monitor_w / 2) - (auto_cast g.window_size.x / 2),
		(monitor_h / 2) - (auto_cast g.window_size.y / 2),
	)

	rl.SetTargetFPS(60)
	when ODIN_OS != .JS {
		rl.SetExitKey(.ESCAPE)
	}
}

close_window :: proc() {
	rl.CloseWindow()
}

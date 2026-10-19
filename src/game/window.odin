package game

import "core:log"
import "core:strings"
import rl "vendor:raylib"

init_window :: proc(g: ^Game) {
	log.infof(
		"initializing window %dx%d title %s",
		i32(g.view.window_size.x),
		i32(g.view.window_size.y),
		g.defs.title,
	)
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(
		auto_cast g.view.window_size.x,
		auto_cast g.view.window_size.y,
		strings.clone_to_cstring(g.defs.title),
	)
	rl.SetTextureFilter(rl.GetFontDefault().texture, .POINT)

	monitor_id := rl.GetCurrentMonitor()
	monitor_w := rl.GetMonitorWidth(monitor_id)
	monitor_h := rl.GetMonitorHeight(monitor_id)

	rl.SetWindowPosition(
		(monitor_w / 2) - (auto_cast g.view.window_size.x / 2),
		(monitor_h / 2) - (auto_cast g.view.window_size.y / 2),
	)

	rl.SetTargetFPS(60)
	when ODIN_OS != .JS {
		rl.SetExitKey(.ESCAPE)
	}
}

close_window :: proc() {
	log.info("closing window")
	rl.CloseWindow()
}

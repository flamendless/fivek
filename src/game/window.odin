package game

import "core:log"
import "core:strings"
import rl "vendor:raylib"
import "../config"

@(private = "file")
macos_present_kicks_left: int

// Monitor index whose virtual desktop bounds contain (x, y), else 0.
monitor_for_point :: proc(x, y: f32) -> i32 {
	for i in 0 ..< rl.GetMonitorCount() {
		pos := rl.GetMonitorPosition(i)
		w := f32(rl.GetMonitorWidth(i))
		h := f32(rl.GetMonitorHeight(i))
		if x >= pos.x && x < pos.x + w && y >= pos.y && y < pos.y + h {
			return i
		}
	}
	return 0
}

center_window_on_monitor :: proc(g: ^Game, monitor: i32) {
	win_w := i32(g.view.window_size.x)
	win_h := i32(g.view.window_size.y)
	pos := rl.GetMonitorPosition(monitor)
	mw := rl.GetMonitorWidth(monitor)
	mh := rl.GetMonitorHeight(monitor)
	rl.SetWindowPosition(
		i32(pos.x) + (mw - win_w) / 2,
		i32(pos.y) + (mh - win_h) / 2,
	)
}

window_logical_size :: proc(g: ^Game) -> (w, h: i32) {
	return i32(g.view.window_size.x), i32(g.view.window_size.y)
}

enforce_window_size :: proc(g: ^Game) {
	win_w, win_h := window_logical_size(g)
	rl.SetWindowSize(win_w, win_h)
}

// Mimics a user window drag — macOS often skips the first present until move/resize.
@(private = "file")
macos_nudge_present :: proc(g: ^Game) {
	when ODIN_OS == .Darwin {
		enforce_window_size(g)
		p := rl.GetWindowPosition()
		x, y := i32(p.x), i32(p.y)
		rl.SetWindowPosition(x + 1, y)
		rl.SetWindowPosition(x, y)
		enforce_window_size(g)
	}
}

// Call at the start of each frame (first few frames on macOS).
tick_macos_window_present :: proc(g: ^Game) {
	when ODIN_OS == .Darwin {
		if macos_present_kicks_left <= 0 {
			return
		}
		macos_present_kicks_left -= 1
		macos_nudge_present(g)
	}
}

init_window :: proc(g: ^Game) {
	log.infof(
		"initializing window %dx%d title %s",
		i32(g.view.window_size.x),
		i32(g.view.window_size.y),
		g.defs.title,
	)
	flags: rl.ConfigFlags
	flags += {.VSYNC_HINT}
	when ODIN_OS == .Darwin {
		flags += {.WINDOW_HIDDEN}
	}
	rl.SetConfigFlags(flags)
	rl.InitWindow(
		auto_cast g.view.window_size.x,
		auto_cast g.view.window_size.y,
		strings.clone_to_cstring(g.defs.title),
	)
	rl.SetTextureFilter(rl.GetFontDefault().texture, .POINT)

	// Pick monitor under the cursor (terminal on external display → window follows).
	mouse := rl.GetMousePosition()
	monitor_id := monitor_for_point(mouse.x, mouse.y)
	center_window_on_monitor(g, monitor_id)

	when ODIN_OS == .Darwin {
		macos_present_kicks_left = 4
		rl.ClearWindowState({.WINDOW_HIDDEN})
		macos_nudge_present(g)
	}

	enforce_window_size(g)

	log.infof(
		"window on monitor %d want=%dx%d screen=%dx%d render=%dx%d dpi=%.2f",
		monitor_id,
		config.GAME_VIEW_WIDTH,
		config.GAME_VIEW_HEIGHT,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.GetRenderWidth(),
		rl.GetRenderHeight(),
		rl.GetWindowScaleDPI().x,
	)

	rl.SetTargetFPS(60)
	when ODIN_OS != .JS {
		rl.SetExitKey(.KEY_NULL)
	}
	rl.HideCursor()
}

close_window :: proc() {
	log.info("closing window")
	rl.ShowCursor()
	rl.CloseWindow()
}

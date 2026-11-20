package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:strconv"
import rl "vendor:raylib"
import "../config"

DEV_SPEED_MIN :: 1.0
DEV_SPEED_MAX :: 50.0
DEV_POP_MIN :: 100
DEV_POP_MAX :: 5000
DEV_PANEL_POP_BUF :: 8

Game_Display :: struct {
	fullscreen:             bool,
	dev_open:               bool,
	dev_speed:              f32,
	dev_pop_target:         int,
	dev_speed_drag:         bool,
	dev_pop_focus:          bool,
	dev_hovered_fullscreen: bool,
	dev_hovered_speed:      bool,
	dev_hovered_pop:        bool,
	dev_pop_text:           [DEV_PANEL_POP_BUF]u8,
	dev_pop_text_len:       int,
}

display_defaults :: proc() -> Game_Display {
	d := Game_Display{
		fullscreen = false,
		dev_open = false,
		dev_speed = 1,
		dev_pop_target = config.TARGET_POPULATION,
	}
	dev_pop_sync_text(&d)
	return d
}

dev_pop_sync_text :: proc(d: ^Game_Display) {
	n := dev_clamp_population(d.dev_pop_target)
	d.dev_pop_target = n
	s := fmt.bprintf(d.dev_pop_text[:], "%d", n)
	d.dev_pop_text_len = len(s)
}

refresh_view_layout :: proc(g: ^Game) {
	g.view.scale = math.min(
		g.view.window_size.x / g.view.game_size.x,
		g.view.window_size.y / g.view.game_size.y,
	)
	zoom := g.view.scale * config.GAME_WORLD_ZOOM
	g.cameras.camera.offset = {g.view.window_size.x * 0.5, g.view.window_size.y * 0.5}
	g.cameras.camera.zoom = zoom
	g.cameras.ui_camera.zoom = g.view.scale
}

apply_window_logical_size :: proc(g: ^Game, w, h: f32) {
	g.view.window_size = {w, h}
	when config.IS_GAME_SIZE_SAME {
		g.view.game_size = g.view.window_size
		g.view.ui_scale = g.view.game_size.y / f32(config.UI_DESIGN_HEIGHT)
	}
	refresh_view_layout(g)
	enforce_window_size(g)
}

sync_display_from_window :: proc(g: ^Game) {
	when ODIN_OS == .JS {
		if g.display.fullscreen {
			w, h: i32
			web_viewport_size(&w, &h)
			if w > 0 && h > 0 {
				if f32(w) != g.view.window_size.x || f32(h) != g.view.window_size.y {
					apply_window_logical_size(g, f32(w), f32(h))
				}
			}
		}
		return
	}
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	if sw > 0 && sh > 0 && (sw != g.view.window_size.x || sh != g.view.window_size.y) {
		apply_window_logical_size(g, sw, sh)
	}
}

display_set_fullscreen :: proc(g: ^Game, enabled: bool) {
	if g.display.fullscreen == enabled {
		sync_display_from_window(g)
		return
	}
	g.display.fullscreen = enabled
	when ODIN_OS == .JS {
		web_viewport_set_fullscreen(enabled)
		if enabled {
			sync_display_from_window(g)
		} else {
			apply_window_logical_size(
				g,
				f32(config.GAME_VIEW_WIDTH),
				f32(config.GAME_VIEW_HEIGHT),
			)
		}
	} else {
		if enabled {
			if !rl.IsWindowFullscreen() {
				rl.ToggleFullscreen()
			}
		} else if rl.IsWindowFullscreen() {
			rl.ToggleFullscreen()
			apply_window_logical_size(
				g,
				f32(config.GAME_VIEW_WIDTH),
				f32(config.GAME_VIEW_HEIGHT),
			)
		}
		sync_display_from_window(g)
	}
	log.infof("display fullscreen=%v window=%.0fx%.0f", g.display.fullscreen, g.view.window_size.x, g.view.window_size.y)
}

tick_display :: proc(g: ^Game) {
	when ODIN_OS == .JS {
		fs := web_viewport_is_fullscreen()
		if fs != g.display.fullscreen {
			g.display.fullscreen = fs
		}
	} else {
		g.display.fullscreen = rl.IsWindowFullscreen()
	}
	when ODIN_OS == .Darwin {
		tick_macos_window_present(g)
	}
	sync_display_from_window(g)
}

dev_clamp_population :: proc(n: int) -> int {
	return math.clamp(n, DEV_POP_MIN, DEV_POP_MAX)
}

dev_apply_population_target :: proc(g: ^Game) {
	n := dev_clamp_population(g.display.dev_pop_target)
	g.display.dev_pop_target = n
	g.defs.target_population = n
	if (g.mode == .Playing || g.mode == .Post_Game) && g.scene.people != nil {
		goal := n
		if goal > g.scene.people.crowd_count {
			goal = g.scene.people.crowd_count
		}
		g.run.person_count = goal
	}
}

ui_uses_system_pointer :: proc(g: ^Game) -> bool {
	return g.display.dev_open || g.title.settings_open
}

tick_ui_pointer :: proc(g: ^Game) {
	show := ui_uses_system_pointer(g)
	when ODIN_OS == .JS {
		web_set_system_cursor_visible(show)
	} else {
		if show {
			rl.ShowCursor()
		} else {
			rl.HideCursor()
		}
	}
}
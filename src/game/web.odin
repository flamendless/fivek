package game

import "../food"
import rl "vendor:raylib"

@(private = "file")
g_web: ^Game

@(private = "file")
web_should_quit: bool

request_app_shutdown :: proc() {
	when ODIN_OS == .JS {
		web_should_quit = true
	} else {
		rl.CloseWindow()
	}
}

web_start :: proc() {
	g_web = init(get_defs())
	init_window(g_web)
	load_intro_assets(g_web)
	food.load()
	rl.SetTargetFPS(0)
}

web_update :: proc() -> bool {
	update(g_web)
	rl.PollInputEvents()
	draw(g_web)
	g_web.frame += 1
	free_all(context.temp_allocator)
	return !web_should_quit
}

web_end :: proc() {
	if g_web != nil {
		close(g_web)
		g_web = nil
	}
	close_window()
}

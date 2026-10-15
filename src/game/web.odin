package game

import rl "vendor:raylib"

@(private = "file")
g_web: ^Game

web_start :: proc() {
	g_web = init(get_defs())
	init_window(g_web)
}

web_update :: proc() -> bool {
	update(g_web)
	draw(g_web)
	g_web.frame += 1
	free_all(context.temp_allocator)
	return !rl.WindowShouldClose()
}

web_end :: proc() {
	if g_web != nil {
		close(g_web)
		g_web = nil
	}
	close_window()
}

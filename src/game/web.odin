package game

import "core:log"
import "../currency"
import "../food"
import "../ui"
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
	log.info("initializing game")
	g_web = init(get_defs())

	log.info("initializing window")
	init_window(g_web)

	log.info("loading intro assets")
	load_intro_assets(g_web)

	log.info("loading title assets")
	load_title_assets()

	log.info("loading food")
	food.load()

	log.info("loading currency")
	currency.load()

	log.info("loading UI")
	ui.load()

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
	log.info("unloading title assets")
	unload_title_assets()

	log.info("unloading UI")
	ui.unload()
	log.info("unloading currency")
	currency.unload()
	log.info("closing game")
	if g_web != nil {
		close(g_web)
		g_web = nil
	}
	log.info("closing window")
	close_window()
}

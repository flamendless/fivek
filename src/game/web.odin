package game

import "core:log"
import "../currency"
import "../food"
import "../ui"
import rl "vendor:raylib"

Web_Runtime :: struct {
	game:        ^Game,
	should_quit: bool,
}

@(private = "file")
web: Web_Runtime

request_app_shutdown :: proc() {
	when ODIN_OS == .JS {
		web.should_quit = true
	} else {
		rl.CloseWindow()
	}
}

web_start :: proc() {
	log.info("initializing game")
	web.game = init(get_defs())

	log.info("initializing window")
	init_window(web.game)

	log.info("loading splash assets")
	load_splash_assets(web.game)

	log.info("loading title assets")
	load_title_assets(web.game)

	log.info("loading food")
	food.load()

	log.info("loading currency")
	currency.load()

	log.info("loading UI")
	ui.load()

	rl.SetTargetFPS(0)
}

web_update :: proc() -> bool {
	update(web.game)
	rl.PollInputEvents()
	draw(web.game)
	web.game.frame += 1
	free_all(context.temp_allocator)
	return !web.should_quit
}

web_end :: proc() {
	log.info("unloading UI")
	ui.unload()
	log.info("unloading currency")
	currency.unload()
	log.info("closing game")
	if web.game != nil {
		close(web.game)
		web.game = nil
	}
	log.info("closing window")
	close_window()
}

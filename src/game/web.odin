package game

import "core:log"
import "../assets"
import "../config"
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

	log.info("loading boot assets")
	assets.load_boot()

	log.info("loading title assets")
	load_title_assets(web.game)

	log.info("loading gameplay assets")
	assets.load_gameplay()

	when config.IS_DEBUG {
		apply_launch_state(web.game)
	}

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
	log.info("closing game")
	if web.game != nil {
		close(web.game)
		web.game = nil
	}
	log.info("closing window")
	close_window()
}

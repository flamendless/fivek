package main

import "core:log"
import "config"
import "game"
import "assets"

when config.IS_AUTOTEST {
	main :: proc() {
		game.exit_autotest(game.run_autotest())
	}
} else {
	main :: proc() {
		when ODIN_OS != .JS {
			context.logger = log.create_console_logger()
		}
		log.info("checking defs")
		defs := game.get_defs()
		log.infof("%v", defs)

		log.info("initializing game")
		g := game.init(defs)
		defer {
			log.info("closing game")
			game.close(g)
		}
		log.infof("%v", g)

		log.info("initializing window")
		game.init_window(g)

		log.info("loading boot assets")
		assets.load_boot()

		log.info("loading title assets")
		game.load_title_assets(g)

		log.info("loading gameplay assets")
		assets.load_gameplay()

		defer {
			log.info("closing window")
			game.close_window()
		}

		when config.IS_DEBUG {
			game.apply_launch_state(g)
		}
		game.loop(g)
	}
}

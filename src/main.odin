package main

import "core:fmt"
import "config"
import "game"
import "food"

when config.IS_AUTOTEST {
	main :: proc() {
		game.exit_autotest(game.run_autotest())
	}
} else {
	main :: proc() {
		fmt.println("Checking defs...")
		defs := game.get_defs()
		fmt.println(defs)

		fmt.println("Initializing game...")
		g := game.init(defs)
		defer {
			fmt.println("Closing game...")
			game.close(g)
		}
		fmt.println(g)

		fmt.println("Initializing window...")
		game.init_window(g)
		game.load_intro_assets(g)
		food.load()
		defer {
			fmt.println("Closing window...")
			game.close_window()
		}

		game.loop(g)
	}
}

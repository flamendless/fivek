package main

import "core:fmt"
import "game"

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
	defer {
		fmt.println("Closing window...")
		game.close_window()
	}

	game.loop(g)
}

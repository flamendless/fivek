package main

import "core:fmt"
import "game"

main :: proc() {
	fmt.println("Initializing game...")
	g := game.init()
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

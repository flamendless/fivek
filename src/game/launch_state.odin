package game

import "../config"

when config.IS_DEBUG {

apply_launch_state :: proc(g: ^Game) {
	switch config.START_STATE {
	case "":
		return
	case "play", "playing":
		start_run(g, false)
	case "title":
		g.mode = .Title
	case "tutorial":
		g.intro.tutorial_into_play = false
		g.mode = .Tutorial
	case "disclaimer":
		g.mode = .Disclaimer
	case "splash":
		return
	case:
		return
	}
}

}

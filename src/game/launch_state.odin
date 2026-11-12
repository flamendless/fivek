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
		enter_tutorial(g, false)
	case "disclaimer":
		enter_disclaimer(g)
	case "credits":
		enter_credits(g, false)
	case "stats":
		enter_stats(g)
	case "splash":
		return
	case:
		return
	}
}

}

package game

import "core:strconv"
import "core:strings"
import "../config"

when config.IS_DEBUG {

launch_state_end_lineup :: proc(state: string) -> (lineup: int, ok: bool) {
	prefix := "end:"
	if state == "end" {
		return 0, true
	}
	if !strings.has_prefix(state, prefix) {
		return 0, false
	}
	rest := state[len(prefix):]
	if len(rest) == 0 {
		return 0, true
	}
	v, parsed := strconv.parse_int(rest)
	if !parsed || v < 0 {
		return 0, true
	}
	return v, true
}

apply_launch_state :: proc(g: ^Game) {
	state := string(config.START_STATE)
	switch state {
	case "":
		return
	case "play", "playing":
		start_run(g, false)
	case "postgame":
		start_run(g, false)
		begin_post_game(g)
	case "end":
		debug_enter_epilogue_roam(g, 0)
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
	case "achievements":
		enter_achievements(g)
	case "splash":
		return
	case:
		if lineup, is_end := launch_state_end_lineup(state); is_end {
			debug_enter_epilogue_roam(g, lineup)
			return
		}
		return
	}
}

}

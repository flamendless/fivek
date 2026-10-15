package game

import rl "vendor:raylib"
import "../input"
import "../config"
import "../person"

when config.IS_AUTOTEST {

AUTOPLAY_SIM_SPEED :: 4.0

loop_until_credits :: proc(g: ^Game) -> bool {
	for {
		if rl.WindowShouldClose() {
			return false
		}
		input.begin_frame()
		update(g)
		draw(g)
		g.frame += 1
		free_all(context.temp_allocator)

		if g.mode == .Credits {
			return true
		}
		if g.autoplay_max_frames > 0 && g.frame >= g.autoplay_max_frames {
			g.autoplay_failed = true
			return false
		}
	}
}

served_count :: proc(g: ^Game) -> int {
	if g.people == nil {
		return 0
	}
	return person.count_served(g.people)
}

person_count :: proc(g: ^Game) -> int {
	return g.person_count
}

run_frame :: proc(g: ^Game) -> int {
	return g.frame
}

}

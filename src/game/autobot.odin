package game

import "core:math"
import "../config"
import "../input"
import "../person"

when config.IS_AUTOTEST {

AUTOBOT_MOVE_DEADBAND :: 4.0

pick_nearest_unserved :: proc(g: ^Game, interactable_only: bool) -> int {
	if g.people == nil {
		return -1
	}
	player_cx := g.player.pos.x + g.player.size.x * 0.5
	best := -1
	best_dist: f32 = math.F32_MAX

	for i in 0 ..< len(g.people.rows) {
		if g.people.rows[i].served {
			continue
		}
		if g.people.rows[i].phase != .Active {
			continue
		}
		if interactable_only && !person.is_interactable(g.people, i) {
			continue
		}
		cx := g.people.rows[i].pos_x + g.people.rows[i].size_w * 0.5
		d := math.abs(cx - player_cx)
		if d < best_dist {
			best_dist = d
			best = i
		}
	}
	return best
}

target_still_valid :: proc(g: ^Game, i: int) -> bool {
	if i < 0 || g.people == nil || i >= len(g.people.rows) {
		return false
	}
	if g.people.rows[i].served {
		return false
	}
	if g.people.rows[i].phase != .Active {
		return false
	}
	return true
}

autobot_tick :: proc(g: ^Game) {
	input.clear_movement()

	if g.people == nil || g.player == nil {
		return
	}

	if !target_still_valid(g, g.autobot_target) {
		g.autobot_target = pick_nearest_unserved(g, true)
		if g.autobot_target < 0 {
			g.autobot_target = pick_nearest_unserved(g, false)
		}
	}
	target := g.autobot_target
	if target < 0 {
		return
	}

	row := &g.people.rows[target]
	player_cx := g.player.pos.x + g.player.size.x * 0.5
	person_cx := row.pos_x + row.size_w * 0.5
	dx := person_cx - player_cx

	if math.abs(dx) > AUTOBOT_MOVE_DEADBAND {
		if dx > 0 {
			input.set_down(.D, true)
		} else {
			input.set_down(.A, true)
		}
		input.set_down(.LEFT_SHIFT, true)
	}

	nearest := person.nearest_interact_index(
		g.people,
		g.player.pos,
		g.player.size,
		g.defs.interact_radius,
	)
	if nearest != target {
		return
	}

	if !row.has_fish {
		input.press(.F)
	} else if !row.has_bread {
		input.press(.B)
	}
}

}

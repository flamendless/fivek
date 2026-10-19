package game

import "../config"
import "../input"
import "../person"

when config.IS_AUTOTEST {

AUTOBOT_MOVE_DEADBAND :: 4.0
AUTOBOT_SWEEP_PAD :: 12.0

Autobot_Phase :: enum {
	Fish_Right,
	Bread_Left,
}

autobot_phase: Autobot_Phase = .Fish_Right

any_needs_food :: proc(g: ^Game) -> bool {
	if g.scene.people == nil {
		return false
	}
	for i in 0 ..< len(g.scene.people.rows) {
		if person.needs_food(g.scene.people, i) {
			return true
		}
	}
	return false
}

any_needs_item :: proc(g: ^Game, item: person.Give_Item) -> bool {
	if g.scene.people == nil {
		return false
	}
	for i in 0 ..< len(g.scene.people.rows) {
		if !person.needs_food(g.scene.people, i) {
			continue
		}
		row := g.scene.people.rows[i]
		switch item {
		case .Fish:
			if !row.food.has_fish {
				return true
			}
		case .Bread:
			if !row.food.has_bread {
				return true
			}
		}
	}
	return false
}

person_chunk_bounds :: proc(g: ^Game) -> (left_x, right_x: f32, ok: bool) {
	if g.scene.level == nil {
		return 0, 0, false
	}
	for c in g.scene.level.chunks {
		if c.person_count == 0 {
			continue
		}
		if !ok {
			left_x = c.x_min + AUTOBOT_SWEEP_PAD
			ok = true
		}
		right_x = c.x_max - AUTOBOT_SWEEP_PAD
	}
	return left_x, right_x, ok
}

autobot_tick :: proc(g: ^Game) {
	input.clear_movement()

	if g.scene.people == nil || g.scene.player == nil || g.scene.level == nil {
		return
	}
	if !any_needs_food(g) {
		return
	}

	left_x, right_x, bounds_ok := person_chunk_bounds(g)
	if !bounds_ok {
		return
	}

	bonuses := person.party_bonuses(g.scene.people)
	radius := g.defs.interact_radius + bonuses.interact_radius_add
	pos := g.scene.player.pos
	size := g.scene.player.size
	player_cx := pos.x + size.x * 0.5

	switch autobot_phase {
	case .Fish_Right:
		person.give_item_in_contact(g.scene.people, pos, size, radius, .Fish, &g.run.run_stats)
		if !any_needs_item(g, .Fish) {
			autobot_phase = .Bread_Left
		} else if player_cx >= right_x - AUTOBOT_MOVE_DEADBAND {
			autobot_phase = .Bread_Left
		} else {
			input.set_down(.D, true)
			input.set_down(.LEFT_SHIFT, true)
		}
	case .Bread_Left:
		person.give_item_in_contact(g.scene.people, pos, size, radius, .Bread, &g.run.run_stats)
		if !any_needs_item(g, .Bread) {
			autobot_phase = .Fish_Right
		} else if player_cx <= left_x + AUTOBOT_MOVE_DEADBAND {
			autobot_phase = .Fish_Right
		} else {
			input.set_down(.A, true)
			input.set_down(.LEFT_SHIFT, true)
		}
	}
}

}

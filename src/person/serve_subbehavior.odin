package person

import "core:math"

update_subbehavior :: proc(p: ^People, i: int, dt: f32) -> bool {
	row := &p.rows[i]
	switch row.behavior.subbehavior {
	case .None:
		return false
	case .Flee_After_Food:
		if try_begin_celebrate(p, i) {
			return true
		}
		prev_x := row.transform.pos_x
		speed := person_move_speed(p, i, .Running)
		row.transform.pos_x += row.transform.dir * speed * dt
		roam_after_step(p, i)
		moved := math.abs(row.transform.pos_x - prev_x)
		if moved == 0 {
			end_flee_after_food(p, i)
			return true
		}
		row.behavior.flee_remaining -= moved
		if row.behavior.flee_remaining <= 0 {
			end_flee_after_food(p, i)
		}
		return true
	case .Frozen_Talk:
		return true
	case .Escort_To_Player:
		speed := person_move_speed(p, i, .Walking)
		dx := row.nav.target_x - row.transform.pos_x
		if math.abs(dx) < 4 {
			row.behavior.subbehavior = .None
			roam_to_idle(p, i)
			return true
		}
		if dx < 0 {
			row.transform.dir = -1
		} else {
			row.transform.dir = 1
		}
		row.transform.pos_x += row.transform.dir * speed * dt
		roam_after_step(p, i)
		return true
	case .Scared_To_Chunk:
		prev_x := row.transform.pos_x
		speed := person_move_speed(p, i, .Running)
		row.transform.pos_x += row.transform.dir * speed * dt
		roam_after_step(p, i)
		moved := math.abs(row.transform.pos_x - prev_x)
		row.behavior.flee_remaining -= moved
		if moved == 0 || row.behavior.flee_remaining <= 0 {
			row.behavior.subbehavior = .None
			roam_to_idle(p, i)
		}
		return true
	}
	return false
}

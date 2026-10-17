package person

import "core:math"
import "core:math/rand"
import "../config"

age_flees_after_food :: proc(age: Person_Age) -> bool {
	return age == .Kid || age == .Young
}

begin_flee_after_food :: proc(p: ^People, i: int, player_cx: f32) {
	row := &p.rows[i]
	row.subbehavior = .Flee_After_Food
	row.flee_remaining = rand_float_range(CHILD_FLEE_DISTANCE_MIN, CHILD_FLEE_DISTANCE_MAX)
	row.state = .Running
	person_cx := row.pos_x + row.size_w * 0.5
	if person_cx >= player_cx {
		row.dir = 1
	} else {
		row.dir = -1
	}
}

end_flee_after_food :: proc(p: ^People, i: int) {
	p.rows[i].subbehavior = .None
	p.rows[i].flee_remaining = 0
	if !try_begin_celebrate(p, i) {
		roam_to_idle(p, i)
	}
}

update_subbehavior :: proc(p: ^People, i: int, dt: f32) -> bool {
	row := &p.rows[i]
	switch row.subbehavior {
	case .None:
		return false
	case .Flee_After_Food:
		if try_begin_celebrate(p, i) {
			return true
		}
		prev_x := row.pos_x
		speed := person_move_speed(p, i, .Running)
		row.pos_x += row.dir * speed * dt
		roam_after_step(p, i)
		moved := math.abs(row.pos_x - prev_x)
		if moved == 0 {
			end_flee_after_food(p, i)
			return true
		}
		row.flee_remaining -= moved
		if row.flee_remaining <= 0 {
			end_flee_after_food(p, i)
		}
		return true
	}
	return false
}

pick_lineup_after_serve :: proc(age: Person_Age) -> bool {
	roll := rand.int_max(100)
	switch age {
	case .Kid:
		return roll < 75
	case .Young:
		return roll < 50
	case .Adult:
		return roll < 25
	}
	return false
}

lineup_slots_per_row :: proc(chunk_width: f32) -> int {
	inner := chunk_width - LINEUP_PAD * 2
	return max(int(inner / LINEUP_SLOT_PITCH), 1)
}

reserve_lineup_slot :: proc(p: ^People, person_i: int) {
	per_row := lineup_slots_per_row(p.lineup_chunk_width)
	slot := p.lineup_next_slot
	p.lineup_next_slot += 1

	line_row_idx := slot / per_row
	col := slot % per_row

	p.rows[person_i].line_row = line_row_idx
	p.rows[person_i].target_x =
		LINEUP_PAD + f32(col) * LINEUP_SLOT_PITCH + (LINEUP_SLOT_PITCH - p.rows[person_i].size_w) * 0.5
	p.rows[person_i].target_y =
		p.lineup_ground_y - p.rows[person_i].size_h - f32(line_row_idx) * LINEUP_ROW_DEPTH
}

begin_post_serve :: proc(p: ^People, person_i: int) {
	p.rows[person_i].served = true
	p.rows[person_i].state = .Running

	if pick_lineup_after_serve(p.rows[person_i].age) {
		reserve_lineup_slot(p, person_i)
		p.rows[person_i].phase = .Run_Lineup
		if p.rows[person_i].pos_x > p.rows[person_i].target_x {
			p.rows[person_i].dir = -1
		} else {
			p.rows[person_i].dir = 1
		}
	} else {
		p.rows[person_i].phase = .Run_Home
		p.rows[person_i].target_x = p.lineup_chunk_width * 1.5
		p.rows[person_i].target_y = p.rows[person_i].base_y
		p.rows[person_i].dir = 1
	}
}

begin_celebrating :: proc(p: ^People, i: int) {
	p.rows[i].state = .Celebrating
	p.rows[i].hop_step = 0
	p.rows[i].hop_count = u8(CELEBRATE_HOP_MIN + rand.int_max(CELEBRATE_HOP_MAX - CELEBRATE_HOP_MIN + 1))
	p.rows[i].hop_timer = CELEBRATE_HOP_DURATION
}

try_begin_celebrate :: proc(p: ^People, i: int) -> bool {
	if !p.rows[i].has_fish || !p.rows[i].has_bread || p.rows[i].served {
		return false
	}
	p.rows[i].subbehavior = .None
	p.rows[i].flee_remaining = 0
	begin_celebrating(p, i)
	return true
}

move_toward_target :: proc(p: ^People, i: int, dt: f32) -> bool {
	dx := p.rows[i].target_x - p.rows[i].pos_x
	if math.abs(dx) < 2 {
		p.rows[i].pos_x = p.rows[i].target_x
		p.rows[i].pos_y = p.rows[i].target_y
		return true
	}
	if dx < 0 {
		p.rows[i].dir = -1
	} else {
		p.rows[i].dir = 1
	}
	speed := RUN_SPEED * POST_SERVE_SPEED_MULT * p.rows[i].speed_scale
	p.rows[i].pos_x += p.rows[i].dir * speed * dt
	p.rows[i].pos_y = p.rows[i].target_y
	return false
}

when config.IS_DEBUG {
	debug_serve_next :: proc(p: ^People) -> bool {
		for i in 0 ..< p.crowd_count {
			if p.rows[i].served {
				continue
			}
			p.rows[i].has_fish = true
			p.rows[i].has_bread = true
			p.rows[i].subbehavior = .None
			p.rows[i].flee_remaining = 0
			begin_post_serve(p, i)
			return true
		}
		return false
	}
}

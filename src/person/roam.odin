package person

import "core:math"
import "core:math/rand"

pick_idle_duration :: proc(age: Person_Age) -> f32 {
	switch age {
	case .Kid:
		return rand_float_range(0.3, 1.0)
	case .Young:
		return rand_float_range(0.8, 2.0)
	case .Adult:
		return rand_float_range(1.5, 4.0)
	}
	return 1.0
}

pick_move_state :: proc(age: Person_Age) -> Person_State {
	roll := rand.int_max(100)
	switch age {
	case .Kid:
		if roll < 60 {
			return .Running
		}
		if roll < 90 {
			return .Walking
		}
	case .Young:
		if roll < 15 {
			return .Running
		}
		if roll < 75 {
			return .Walking
		}
	case .Adult:
		if roll < 10 {
			return .Running
		}
		if roll < 35 {
			return .Walking
		}
	}
	return .Idle
}

pick_move_duration :: proc(age: Person_Age, state: Person_State) -> f32 {
	switch state {
	case .Running:
		switch age {
		case .Kid:
			return rand_float_range(0.4, 1.2)
		case .Young:
			return rand_float_range(0.8, 2.0)
		case .Adult:
			return rand_float_range(1.0, 2.5)
		}
	case .Walking:
		switch age {
		case .Kid:
			return rand_float_range(0.6, 1.8)
		case .Young:
			return rand_float_range(1.2, 3.0)
		case .Adult:
			return rand_float_range(2.0, 5.0)
		}
	case .Idle, .Celebrating:
		break
	}
	return 1.5
}

pick_roam_from_idle :: proc(p: ^People, i: int) {
	next := pick_move_state(p.rows[i].traits.age)
	if next != .Idle && next == p.rows[i].motion.last_roam {
		reroll := pick_move_state(p.rows[i].traits.age)
		if reroll != .Idle {
			next = reroll
		}
		if next == p.rows[i].motion.last_roam {
			next = .Idle
		}
	}
	if next == .Idle {
		p.rows[i].motion.timer = pick_idle_duration(p.rows[i].traits.age)
		return
	}
	p.rows[i].motion.state = next
	p.rows[i].motion.last_roam = next
	p.rows[i].motion.timer = pick_move_duration(p.rows[i].traits.age, next)
	if rand.int_max(2) == 0 {
		p.rows[i].transform.dir = -1
	} else {
		p.rows[i].transform.dir = 1
	}
}

roam_to_idle :: proc(p: ^People, i: int) {
	p.rows[i].motion.state = .Idle
	p.rows[i].motion.timer = pick_idle_duration(p.rows[i].traits.age)
}

roam_after_step :: proc(p: ^People, i: int) {
	row := &p.rows[i]
	legal_min := row.transform.bound_min_x
	legal_max := row.transform.bound_max_x - row.transform.size_w
	if legal_max < legal_min {
		row.transform.pos_x = (row.transform.bound_min_x + row.transform.bound_max_x) * 0.5 - row.transform.size_w * 0.5
		roam_to_idle(p, i)
		return
	}
	prev_x := row.transform.pos_x
	row.transform.pos_x = math.clamp(row.transform.pos_x, legal_min, legal_max)
	if row.transform.pos_x == prev_x {
		return
	}
	if row.motion.timer < WALL_IDLE_GRACE {
		roam_to_idle(p, i)
		return
	}
	if row.transform.pos_x <= legal_min {
		row.transform.dir = 1
	} else {
		row.transform.dir = -1
	}
}

person_move_speed :: proc(p: ^People, i: int, state: Person_State) -> f32 {
	base: f32
	switch state {
	case .Running:
		base = RUN_SPEED
	case .Walking:
		base = WALK_SPEED
	case .Idle, .Celebrating:
		return 0
	}
	return base * p.rows[i].traits.speed_scale
}

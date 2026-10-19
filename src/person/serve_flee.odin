package person

import "core:math"

age_flees_after_food :: proc(age: Person_Age) -> bool {
	return age == .Kid || age == .Young
}

begin_flee_after_food :: proc(p: ^People, i: int, player_cx: f32) {
	row := &p.rows[i]
	row.behavior.subbehavior = .Flee_After_Food
	row.behavior.flee_remaining = rand_float_range(CHILD_FLEE_DISTANCE_MIN, CHILD_FLEE_DISTANCE_MAX)
	row.motion.state = .Running
	person_cx := row.transform.pos_x + row.transform.size_w * 0.5
	if person_cx >= player_cx {
		row.transform.dir = 1
	} else {
		row.transform.dir = -1
	}
}

end_flee_after_food :: proc(p: ^People, i: int) {
	p.rows[i].behavior.subbehavior = .None
	p.rows[i].behavior.flee_remaining = 0
	if !try_begin_celebrate(p, i) {
		roam_to_idle(p, i)
	}
}

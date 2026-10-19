package person

import "core:math/rand"

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
	per_row := lineup_slots_per_row(p.lineup.chunk_width)
	slot := p.lineup.next_slot
	p.lineup.next_slot += 1

	line_row_idx := slot / per_row
	col := slot % per_row

	p.rows[person_i].nav.line_row = line_row_idx
	p.rows[person_i].nav.target_x =
		LINEUP_PAD + f32(col) * LINEUP_SLOT_PITCH + (LINEUP_SLOT_PITCH - p.rows[person_i].transform.size_w) * 0.5
	p.rows[person_i].nav.target_y =
		p.lineup.ground_y - p.rows[person_i].transform.size_h - f32(line_row_idx) * LINEUP_ROW_DEPTH
}

begin_run_lineup :: proc(p: ^People, person_i: int) {
	reserve_lineup_slot(p, person_i)
	p.rows[person_i].motion.phase = .Run_Lineup
	if p.rows[person_i].transform.pos_x > p.rows[person_i].nav.target_x {
		p.rows[person_i].transform.dir = -1
	} else {
		p.rows[person_i].transform.dir = 1
	}
}

begin_run_home :: proc(p: ^People, person_i: int) {
	roll_run_home_coin_drop(p, person_i)
	row := &p.rows[person_i]
	row.motion.phase = .Run_Home
	row.nav.target_x = p.lineup.chunk_width * 1.5
	row.nav.target_y = row.transform.base_y
	row.transform.dir = 1
}

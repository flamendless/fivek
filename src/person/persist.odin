package person

count_served :: proc(p: ^People) -> int {
	n := 0
	for i in 0 ..< p.crowd_count {
		if p.rows[i].served {
			n += 1
		}
	}
	return n
}

sim_settled :: proc(p: ^People) -> bool {
	for i in 0 ..< len(p.rows) {
		row := p.rows[i]
		switch row.phase {
		case .Run_Lineup, .Run_Home:
			return false
		case .Active:
			if row.state == .Celebrating {
				return false
			}
			if row.subbehavior != .None {
				return false
			}
		case .In_Lineup, .Gone, .Following:
			break
		}
	}
	return true
}

place_in_lineup_slot :: proc(p: ^People, person_i: int) {
	reserve_lineup_slot(p, person_i)
	p.rows[person_i].pos_x = p.rows[person_i].target_x
	p.rows[person_i].pos_y = p.rows[person_i].target_y
	p.rows[person_i].phase = .In_Lineup
	p.rows[person_i].state = .Idle
	p.rows[person_i].served = true
}

apply_served_bits :: proc(p: ^People, bits: []u8) {
	for i in 0 ..< p.crowd_count {
		if served_bit_get(bits, i) {
			p.rows[i].has_fish = true
			p.rows[i].has_bread = true
			place_in_lineup_slot(p, i)
		}
	}
}

sync_served_bits :: proc(p: ^People, bits: []u8) {
	for i in 0 ..< p.crowd_count {
		if p.rows[i].served {
			served_bit_set(bits, i)
		}
	}
}

served_bit_get :: proc(bits: []u8, i: int) -> bool {
	return (bits[i / 8] >> u8(i % 8)) & 1 != 0
}

served_bit_set :: proc(bits: []u8, i: int) {
	bits[i / 8] |= 1 << u8(i % 8)
}

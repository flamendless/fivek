package person

import "core:fmt"
import "core:math/rand"
import "../currency"

COIN_DROP_CHANCE :: 40
COIN_DROP_ZONE_FRAC :: 0.7

chunk_local_x :: proc(pos_x: f32, chunk_width: f32) -> (chunk_idx: int, local_x: f32) {
	chunk_idx = int(pos_x / chunk_width)
	local_x = pos_x - f32(chunk_idx) * chunk_width
	return
}

roll_run_home_coin_drop :: proc(p: ^People, person_i: int) {
	row := &p.rows[person_i]
	row.behavior.pending_coin_drop = false
	drops_ok := p.coin_drops != nil
	judas := judas_in_party(p)
	if drops_ok && judas {
		roll := rand.int_max(100)
		pending := roll < COIN_DROP_CHANCE
		fmt.printf(
			"[coin] person index=%d run_home spawn_roll=%d (need < %d) pending_drop=%v judas=%v\n",
			person_i,
			roll,
			COIN_DROP_CHANCE,
			pending,
			judas,
		)
		if pending {
			row.behavior.pending_coin_drop = true
		}
	} else {
		fmt.printf(
			"[coin] person index=%d run_home no roll judas=%v drops_buf=%v\n",
			person_i,
			judas,
			drops_ok,
		)
	}
}

try_spawn_pending_coin_drop :: proc(p: ^People, i: int) {
	row := &p.rows[i]
	if !row.behavior.pending_coin_drop || p.coin_drops == nil {
		return
	}
	cw := p.lineup.chunk_width
	chunk_idx, local_x := chunk_local_x(row.transform.pos_x, cw)
	gate_x := COIN_DROP_ZONE_FRAC * cw
	if local_x < gate_x {
		return
	}
	row.behavior.pending_coin_drop = false
	cx := row.transform.pos_x + row.transform.size_w * 0.5
	cy := p.lineup.ground_y - currency.COIN_ICON_DRAW_SIZE * 0.5 + 2
	icon := u8(rand.int_max(currency.COIN_ICON_COUNT))
	fmt.printf(
		"[coin] person index=%d zone reached chunk=%d local_x=%.1f gate_x=%.1f icon=%d at (%.1f, %.1f)\n",
		i,
		chunk_idx,
		local_x,
		gate_x,
		icon,
		cx,
		cy,
	)
	currency.spawn_drop(p.coin_drops, {cx, cy}, icon)
}

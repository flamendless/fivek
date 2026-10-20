package person

import "core:fmt"
import "core:math/rand"
import "../currency"

COIN_DROP_CHANCE :: 40

spawn_run_home_coin :: proc(p: ^People, person_i: int) {
	row := &p.rows[person_i]
	cx := row.transform.pos_x + row.transform.size_w * 0.5
	cy := p.lineup.ground_y - currency.COIN_ICON_DRAW_SIZE * 0.5 + 2
	icon := u8(rand.int_max(currency.COIN_ICON_COUNT))
	fmt.printf(
		"[coin] person index=%d run_home drop icon=%d at (%.1f, %.1f)\n",
		person_i,
		icon,
		cx,
		cy,
	)
	currency.spawn_drop(p.coin_drops, {cx, cy}, icon)
}

roll_run_home_coin_drop :: proc(p: ^People, person_i: int) {
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
			spawn_run_home_coin(p, person_i)
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

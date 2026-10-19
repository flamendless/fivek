package person

import "core:math"
import "core:math/rand"
import "../config"
import "../food"

begin_post_serve :: proc(p: ^People, person_i: int, stats: ^Run_Stats) {
	p.rows[person_i].food.served = true
	p.rows[person_i].motion.state = .Running

	if stats != nil {
		stat_add(stats, .Total_Served, 1)
		switch p.rows[person_i].traits.age {
		case .Kid:
			stat_add(stats, .Fed_Kids, 1)
		case .Young:
			stat_add(stats, .Fed_Young, 1)
		case .Adult:
			stat_add(stats, .Fed_Adults, 1)
		}
	}

	if pick_lineup_after_serve(p.rows[person_i].traits.age) {
		begin_run_lineup(p, person_i)
	} else {
		begin_run_home(p, person_i)
	}
}

begin_celebrating :: proc(p: ^People, i: int) {
	p.rows[i].motion.state = .Celebrating
	p.rows[i].motion.hop_step = 0
	p.rows[i].motion.hop_count = u8(CELEBRATE_HOP_MIN + rand.int_max(CELEBRATE_HOP_MAX - CELEBRATE_HOP_MIN + 1))
	p.rows[i].motion.hop_timer = CELEBRATE_HOP_DURATION
}

try_begin_celebrate :: proc(p: ^People, i: int) -> bool {
	if !p.rows[i].food.has_fish || !p.rows[i].food.has_bread || p.rows[i].food.served {
		return false
	}
	p.rows[i].behavior.subbehavior = .None
	p.rows[i].behavior.flee_remaining = 0
	begin_celebrating(p, i)
	return true
}

move_toward_target :: proc(p: ^People, i: int, dt: f32) -> bool {
	dx := p.rows[i].nav.target_x - p.rows[i].transform.pos_x
	if math.abs(dx) < 2 {
		p.rows[i].transform.pos_x = p.rows[i].nav.target_x
		p.rows[i].transform.pos_y = p.rows[i].nav.target_y
		return true
	}
	if dx < 0 {
		p.rows[i].transform.dir = -1
	} else {
		p.rows[i].transform.dir = 1
	}
	speed := RUN_SPEED * POST_SERVE_SPEED_MULT * p.rows[i].traits.speed_scale
	p.rows[i].transform.pos_x += p.rows[i].transform.dir * speed * dt
	p.rows[i].transform.pos_y = p.rows[i].nav.target_y
	return false
}

when config.IS_DEBUG {
	debug_serve_next :: proc(p: ^People) -> bool {
		for i in 0 ..< p.crowd_count {
			if p.rows[i].food.served {
				continue
			}
			p.rows[i].food.has_fish = true
			p.rows[i].food.fish_icon = u8(rand.int_max(food.FISH_ICON_COUNT))
			p.rows[i].food.has_bread = true
			p.rows[i].food.bread_icon = u8(rand.int_max(food.BREAD_ICON_COUNT))
			p.rows[i].behavior.subbehavior = .None
			p.rows[i].behavior.flee_remaining = 0
			begin_post_serve(p, i, nil)
			return true
		}
		return false
	}
}

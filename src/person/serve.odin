package person

import "core:math"
import "core:math/rand"
import "../achievements"
import "../assets"
import "../config"

begin_post_serve :: proc(p: ^People, person_i: int, stats: ^Run_Stats, after_celebration: bool = false) {
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

	to_lineup: bool
	if after_celebration {
		to_lineup = p.rows[person_i].behavior.pending_lineup
	} else {
		to_lineup = pick_lineup_after_serve(p.rows[person_i].traits.age)
	}
	if after_celebration && p.career_stats != nil {
		if to_lineup && p.career_stats.post_celebrate_lineup == 0 {
			achievements.try_unlock(p.achievement_state, p.achievement_pending, .SmallActBigChange)
		} else if !to_lineup && p.career_stats.post_celebrate_home == 0 {
			achievements.try_unlock(p.achievement_state, p.achievement_pending, .NotTheRejectedOne)
		}
		career_record_post_celebrate_route(p.career_stats, to_lineup)
	}
	if to_lineup {
		begin_run_lineup(p, person_i)
	} else {
		begin_run_home(p, person_i)
	}
}

assign_celebrate_emote :: proc(p: ^People, i: int, lineup: bool) {
	if p.rows[i].identity.role != .Crowd {
		p.rows[i].behavior.celebrate_emote = .None
		return
	}
	p.rows[i].behavior.pending_lineup = lineup
	if lineup {
		if rand.int_max(2) == 0 {
			p.rows[i].behavior.celebrate_emote = .Heart
		} else {
			p.rows[i].behavior.celebrate_emote = .Exclamation
		}
	} else {
		p.rows[i].behavior.celebrate_emote = .Question
	}
}

begin_celebrating :: proc(p: ^People, i: int) {
	p.rows[i].motion.state = .Celebrating
	p.rows[i].motion.hop_step = 0
	p.rows[i].motion.hop_count = u8(CELEBRATE_HOP_MIN + rand.int_max(CELEBRATE_HOP_MAX - CELEBRATE_HOP_MIN + 1))
	p.rows[i].motion.hop_timer = CELEBRATE_HOP_DURATION
	if p.rows[i].identity.role == .Crowd {
		assign_celebrate_emote(p, i, pick_lineup_after_serve(p.rows[i].traits.age))
	}
}

try_begin_celebrate :: proc(p: ^People, i: int) -> bool {
	if !p.rows[i].food.has_fish || !p.rows[i].food.has_bread || p.rows[i].food.served {
		return false
	}
	p.rows[i].behavior.subbehavior = .None
	p.rows[i].behavior.flee_remaining = 0
	begin_celebrating(p, i)
	achievements.try_unlock(p.achievement_state, p.achievement_pending, .CharityNeverFaileth)
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
	p.rows[i].motion.walk_anim_t += dt
	return false
}

when config.IS_DEBUG {
	debug_mark_all_served :: proc(p: ^People) {
		for i in 0 ..< p.crowd_count {
			p.rows[i].food.has_fish = true
			p.rows[i].food.has_bread = true
			p.rows[i].food.served = true
			p.rows[i].motion.phase = .Gone
		}
	}

	// lineup_count 0 = every crowd member served; otherwise first N only.
	debug_mark_lineup_count :: proc(p: ^People, lineup_count: int) {
		if lineup_count <= 0 {
			debug_mark_all_served(p)
			return
		}
		n := min(lineup_count, p.crowd_count)
		for i in 0 ..< p.crowd_count {
			if i < n {
				p.rows[i].food.has_fish = true
				p.rows[i].food.has_bread = true
				p.rows[i].food.served = true
				p.rows[i].motion.phase = .Gone
			} else {
				p.rows[i].food.has_fish = false
				p.rows[i].food.has_bread = false
				p.rows[i].food.served = false
				p.rows[i].motion.phase = .Gone
			}
		}
	}

	debug_serve_next :: proc(p: ^People) -> bool {
		for i in 0 ..< p.crowd_count {
			if p.rows[i].food.served {
				continue
			}
			p.rows[i].food.has_fish = true
			p.rows[i].food.fish_icon = u8(rand.int_max(assets.fish_grid().icon_count))
			p.rows[i].food.has_bread = true
			p.rows[i].food.bread_icon = u8(rand.int_max(assets.bread_grid().icon_count))
			p.rows[i].behavior.subbehavior = .None
			p.rows[i].behavior.flee_remaining = 0
			begin_post_serve(p, i, nil)
			return true
		}
		return false
	}
}

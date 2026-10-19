package person

import "core:math"
import rl "vendor:raylib"

update_person_at :: proc(p: ^People, i: int, dt: f32) {
	switch p.rows[i].motion.phase {
	case .Gone:
		return
	case .In_Lineup:
		return
	case .Run_Lineup:
		if move_toward_target(p, i, dt) {
			p.rows[i].motion.phase = .In_Lineup
			p.rows[i].motion.state = .Idle
		}
		return
	case .Run_Home:
		try_spawn_pending_coin_drop(p, i)
		if move_toward_target(p, i, dt) {
			p.rows[i].behavior.pending_coin_drop = false
			p.rows[i].motion.phase = .Gone
			p.rows[i].motion.state = .Idle
		}
		return
	case .Following:
		return
	case .Active:
		break
	}

	if update_subbehavior(p, i, dt) {
		return
	}

	switch p.rows[i].motion.state {
	case .Celebrating:
		p.rows[i].motion.hop_timer -= dt
		if p.rows[i].motion.hop_timer <= 0 {
			p.rows[i].motion.hop_step += 1
			if p.rows[i].motion.hop_step >= p.rows[i].motion.hop_count {
				if p.rows[i].identity.role == .Apostle {
					finish_apostle_celebrate(p, i)
				} else {
					p.rows[i].transform.pos_y = p.rows[i].transform.base_y
					p.rows[i].motion.hop_step = 0
					begin_post_serve(p, i, p.run_stats)
				}
			} else {
				p.rows[i].motion.hop_timer = CELEBRATE_HOP_DURATION
			}
		}
		if p.rows[i].motion.hop_step < p.rows[i].motion.hop_count {
			t := math.max(p.rows[i].motion.hop_timer / CELEBRATE_HOP_DURATION, 0)
			p.rows[i].transform.pos_y = p.rows[i].transform.base_y - CELEBRATE_HOP_HEIGHT * math.abs(math.sin(t * math.PI))
		}

	case .Idle:
		if p.rows[i].identity.role == .Crowd &&
		   p.rows[i].food.has_fish &&
		   p.rows[i].food.has_bread &&
		   !p.rows[i].food.served {
			begin_celebrating(p, i)
			return
		}
		if p.rows[i].identity.role == .Apostle {
			return
		}
		p.rows[i].motion.timer -= dt
		if p.rows[i].motion.timer <= 0 {
			pick_roam_from_idle(p, i)
		}

	case .Walking, .Running:
		if p.rows[i].identity.role == .Crowd &&
		   p.rows[i].food.has_fish &&
		   p.rows[i].food.has_bread &&
		   !p.rows[i].food.served {
			begin_celebrating(p, i)
			return
		}
		p.rows[i].motion.timer -= dt
		if p.rows[i].motion.timer <= 0 {
			roam_to_idle(p, i)
			return
		}
		speed := person_move_speed(p, i, p.rows[i].motion.state)
		p.rows[i].transform.pos_x += p.rows[i].transform.dir * speed * dt
		roam_after_step(p, i)
	}
}

update_people :: proc(p: ^People, view: rl.Rectangle, frame: int, dt: f32) {
	tick_apostle_reject_flash(p, dt)
	for i in 0 ..< len(p.rows) {
		if p.rows[i].motion.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		visible := rl.CheckCollisionRecs(pr, view)
		always := p.rows[i].motion.phase == .Run_Lineup ||
			p.rows[i].motion.phase == .Run_Home ||
			p.rows[i].motion.state == .Celebrating ||
			p.rows[i].behavior.subbehavior != .None
		if visible || always {
			update_person_at(p, i, dt)
		} else if (frame + i) % OFFSCREEN_UPDATE_INTERVAL == 0 {
			update_person_at(p, i, dt)
		}
	}
}

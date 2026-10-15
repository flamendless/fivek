package person

import "core:math"
import rl "vendor:raylib"

update_person_at :: proc(p: ^People, i: int, dt: f32) {
	switch p.rows[i].phase {
	case .Gone:
		return
	case .In_Lineup:
		return
	case .Run_Lineup:
		if move_toward_target(p, i, dt) {
			p.rows[i].phase = .In_Lineup
			p.rows[i].state = .Idle
		}
		return
	case .Run_Home:
		if move_toward_target(p, i, dt) {
			p.rows[i].phase = .Gone
			p.rows[i].state = .Idle
		}
		return
	case .Active:
		break
	}

	if update_subbehavior(p, i, dt) {
		return
	}

	switch p.rows[i].state {
	case .Celebrating:
		p.rows[i].hop_timer -= dt
		if p.rows[i].hop_timer <= 0 {
			p.rows[i].hop_step += 1
			if p.rows[i].hop_step >= p.rows[i].hop_count {
				p.rows[i].pos_y = p.rows[i].base_y
				p.rows[i].hop_step = 0
				begin_post_serve(p, i)
			} else {
				p.rows[i].hop_timer = CELEBRATE_HOP_DURATION
			}
		}
		if p.rows[i].hop_step < p.rows[i].hop_count {
			t := math.max(p.rows[i].hop_timer / CELEBRATE_HOP_DURATION, 0)
			p.rows[i].pos_y = p.rows[i].base_y - CELEBRATE_HOP_HEIGHT * math.abs(math.sin(t * math.PI))
		}

	case .Idle:
		if p.rows[i].has_fish && p.rows[i].has_bread && !p.rows[i].served {
			begin_celebrating(p, i)
			return
		}
		p.rows[i].timer -= dt
		if p.rows[i].timer <= 0 {
			pick_roam_from_idle(p, i)
		}

	case .Walking, .Running:
		if p.rows[i].has_fish && p.rows[i].has_bread && !p.rows[i].served {
			begin_celebrating(p, i)
			return
		}
		p.rows[i].timer -= dt
		if p.rows[i].timer <= 0 {
			roam_to_idle(p, i)
			return
		}
		speed := person_move_speed(p, i, p.rows[i].state)
		p.rows[i].pos_x += p.rows[i].dir * speed * dt
		roam_after_step(p, i)
	}
}

update_people :: proc(p: ^People, view: rl.Rectangle, frame: int, dt: f32) {
	for i in 0 ..< len(p.rows) {
		if p.rows[i].phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		visible := rl.CheckCollisionRecs(pr, view)
		always := p.rows[i].phase == .Run_Lineup ||
			p.rows[i].phase == .Run_Home ||
			p.rows[i].state == .Celebrating ||
			p.rows[i].subbehavior != .None
		if visible || always {
			update_person_at(p, i, dt)
		} else if (frame + i) % OFFSCREEN_UPDATE_INTERVAL == 0 {
			update_person_at(p, i, dt)
		}
	}
}

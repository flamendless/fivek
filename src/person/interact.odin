package person

import "core:math"
import rl "vendor:raylib"

nearest_interact_index :: proc(
	p: ^People,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
) -> int {
	best := -1
	best_dist := radius
	player_rect := rl.Rectangle{player_pos.x, player_pos.y, player_size.x, player_size.y}
	player_cx := player_pos.x + player_size.x * 0.5
	player_cy := player_pos.y + player_size.y * 0.5

	for i in 0 ..< len(p.rows) {
		if !is_interactable(p, i) {
			continue
		}
		pr := person_rect_at(p, i)
		touches := rl.CheckCollisionRecs(player_rect, pr)
		cx := p.rows[i].pos_x + p.rows[i].size_w * 0.5
		cy := p.rows[i].pos_y + p.rows[i].size_h * 0.5
		dx := cx - player_cx
		dy := cy - player_cy
		d := math.sqrt(dx * dx + dy * dy)
		in_range := d < radius
		if !touches && !in_range {
			continue
		}
		if d < best_dist {
			best_dist = d
			best = i
		}
	}
	return best
}

try_give_item :: proc(
	p: ^People,
	at: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
	item: Give_Item,
) -> int {
	best := nearest_interact_index(p, at, player_size, radius)
	if best < 0 {
		return -1
	}

	gave_new := false
	switch item {
	case .Fish:
		if !p.rows[best].has_fish {
			p.rows[best].has_fish = true
			gave_new = true
		}
	case .Bread:
		if !p.rows[best].has_bread {
			p.rows[best].has_bread = true
			gave_new = true
		}
	}
	if gave_new {
		if !try_begin_celebrate(p, best) && age_flees_after_gift(p.rows[best].age) {
			player_cx := at.x + player_size.x * 0.5
			begin_flee_after_gift(p, best, player_cx)
		}
	}
	return best
}

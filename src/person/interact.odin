package person

import "core:math"
import "core:math/rand"
import "../food"
import rl "vendor:raylib"

player_in_interact_range :: proc(
	p: ^People,
	i: int,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
) -> bool {
	if i < 0 || i >= len(p.rows) {
		return false
	}
	player_rect := rl.Rectangle{player_pos.x, player_pos.y, player_size.x, player_size.y}
	pr := person_rect_at(p, i)
	if rl.CheckCollisionRecs(player_rect, pr) {
		return true
	}
	player_cx := player_pos.x + player_size.x * 0.5
	player_cy := player_pos.y + player_size.y * 0.5
	cx := p.rows[i].transform.pos_x + p.rows[i].transform.size_w * 0.5
	cy := p.rows[i].transform.pos_y + p.rows[i].transform.size_h * 0.5
	dx := cx - player_cx
	dy := cy - player_cy
	return math.sqrt(dx * dx + dy * dy) < radius
}

needs_food :: proc(p: ^People, i: int) -> bool {
	if i < 0 || i >= len(p.rows) {
		return false
	}
	row := p.rows[i]
	return row.motion.phase == .Active &&
		!row.food.served &&
		row.motion.state != .Celebrating &&
		(!row.food.has_fish || !row.food.has_bread)
}

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
		cx := p.rows[i].transform.pos_x + p.rows[i].transform.size_w * 0.5
		cy := p.rows[i].transform.pos_y + p.rows[i].transform.size_h * 0.5
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

apply_give_item :: proc(p: ^People, i: int, item: Give_Item, player_cx: f32, stats: ^Run_Stats) -> bool {
	if !is_interactable(p, i) {
		return false
	}
	gave_new := false
	switch item {
	case .Fish:
		if !p.rows[i].food.has_fish {
			p.rows[i].food.has_fish = true
			p.rows[i].food.fish_icon = u8(rand.int_max(food.FISH_ICON_COUNT))
			gave_new = true
		}
	case .Bread:
		if !p.rows[i].food.has_bread {
			p.rows[i].food.has_bread = true
			p.rows[i].food.bread_icon = u8(rand.int_max(food.BREAD_ICON_COUNT))
			gave_new = true
		}
	}
	if gave_new {
		if stats != nil {
			switch item {
			case .Fish:
				stat_add(stats, .Fish_Given, 1)
			case .Bread:
				stat_add(stats, .Bread_Given, 1)
			}
		}
		if !try_begin_celebrate(p, i) && age_flees_after_food(p.rows[i].traits.age) {
			begin_flee_after_food(p, i, player_cx)
		}
	}
	return gave_new
}

try_give_item :: proc(
	p: ^People,
	at: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
	item: Give_Item,
	stats: ^Run_Stats,
) -> int {
	best := nearest_interact_index(p, at, player_size, radius)
	if best < 0 {
		return -1
	}
	player_cx := at.x + player_size.x * 0.5
	if apply_give_item(p, best, item, player_cx, stats) {
		return best
	}
	return -1
}

give_item_in_contact :: proc(
	p: ^People,
	at: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
	item: Give_Item,
	stats: ^Run_Stats,
) {
	player_cx := at.x + player_size.x * 0.5
	for i in 0 ..< len(p.rows) {
		if !player_in_interact_range(p, i, at, player_size, radius) {
			continue
		}
		apply_give_item(p, i, item, player_cx, stats)
	}
}

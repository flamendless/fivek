package person

import "../assets"
import "../character"
import "../food"
import "../theme"
import "../wardrobe"
import rl "vendor:raylib"

FOOD_BUBBLE_ABOVE :: 8.0

food_bubble_visible :: proc(p: ^People, i: int) -> bool {
	if i < 0 || i >= len(p.rows) {
		return false
	}
	row := p.rows[i]
	if row.identity.role != .Crowd || (!row.food.has_fish && !row.food.has_bread) {
		return false
	}
	switch row.motion.phase {
	case .Gone, .In_Lineup, .Following:
		return false
	case .Active, .Run_Lineup, .Run_Home:
		return true
	}
	return false
}

draw_food_bubble :: proc(p: ^People, i: int) {
	if !assets.gameplay_ready() {
		return
	}
	row := p.rows[i]
	pcx := row.transform.pos_x + row.transform.size_w * 0.5
	icon_d := assets.food_icon_draw_size()
	fish := assets.fish_grid()
	bread := assets.bread_grid()
	icon_r := icon_d * 0.5
	gap: f32 = 4
	inner_w: f32 = icon_d
	if row.food.has_fish && row.food.has_bread {
		inner_w = icon_d + gap + icon_d
	}
	bubble_w := inner_w + f32(BUBBLE_PAD) * 2
	bubble_h := icon_d + f32(BUBBLE_PAD) * 2
	bx := pcx - bubble_w * 0.5
	by := row.transform.pos_y - bubble_h - FOOD_BUBBLE_ABOVE
	rl.DrawRectangleRec({bx, by, bubble_w, bubble_h}, theme.BUBBLE_FILL)
	rl.DrawRectangleLinesEx({bx, by, bubble_w, bubble_h}, 1, theme.BUBBLE_BORDER)
	cy := by + f32(BUBBLE_PAD) + icon_r

	if row.food.has_fish && row.food.has_bread {
		fish_x := bx + f32(BUBBLE_PAD) + icon_r
		bread_x := bx + bubble_w - f32(BUBBLE_PAD) - icon_r
		food.draw_icon(
			assets.atlas(.Fish),
			int(row.food.fish_icon),
			fish.cell,
			fish.cols,
			{fish_x, cy},
		)
		food.draw_icon(
			assets.atlas(.Bread),
			int(row.food.bread_icon),
			bread.cell,
			bread.cols,
			{bread_x, cy},
		)
	} else if row.food.has_fish {
		food.draw_icon(
			assets.atlas(.Fish),
			int(row.food.fish_icon),
			fish.cell,
			fish.cols,
			{pcx, cy},
		)
	} else {
		food.draw_icon(
			assets.atlas(.Bread),
			int(row.food.bread_icon),
			bread.cell,
			bread.cols,
			{pcx, cy},
		)
	}
}

draw_food_bubbles :: proc(p: ^People, view: rl.Rectangle) {
	for i in 0 ..< len(p.rows) {
		if p.rows[i].motion.phase == .Gone {
			continue
		}
		if !food_bubble_visible(p, i) {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		draw_food_bubble(p, i)
	}
}

crowd_motion_kind :: proc(state: Person_State) -> wardrobe.Motion_Kind {
	switch state {
	case .Walking, .Running:
		return .Walk
	case .Idle, .Celebrating:
		return .Idle
	}
	return .Idle
}

draw_people :: proc(p: ^People, view: rl.Rectangle) {
	for i in 0 ..< len(p.rows) {
		if p.rows[i].motion.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		row := p.rows[i]
		if row.identity.role == .Crowd && assets.crowd_ready() {
			character.draw_crowd(
				pr,
				row.traits.appearance,
				crowd_motion_kind(row.motion.state),
				row.transform.dir,
				row.motion.idle_anim_t,
				row.motion.walk_anim_t,
			)
			continue
		}
		col := row.traits.color
		if row.identity.role == .Apostle && row.traits.draw_alpha < 1 {
			col.a = u8(f32(col.a) * row.traits.draw_alpha)
		}
		rl.DrawRectangleV({row.transform.pos_x, row.transform.pos_y}, {row.transform.size_w, row.transform.size_h}, col)
	}
}

draw_person_outline :: proc(p: ^People, i: int, color: rl.Color) {
	draw_rect_outline(person_rect_at(p, i), color)
}

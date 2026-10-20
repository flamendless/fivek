package person

import "../food"
import "../theme"
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
	if !food.ready() {
		return
	}
	row := p.rows[i]
	pcx := row.transform.pos_x + row.transform.size_w * 0.5
	icon_d := food.FOOD_ICON_DRAW_SIZE
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
			food.fish_tex,
			int(row.food.fish_icon),
			f32(food.FISH_CELL_SIZE),
			food.FISH_ATLAS_COLS,
			{fish_x, cy},
		)
		food.draw_icon(
			food.bread_tex,
			int(row.food.bread_icon),
			f32(food.BREAD_CELL_SIZE),
			food.BREAD_ATLAS_COLS,
			{bread_x, cy},
		)
	} else if row.food.has_fish {
		food.draw_icon(
			food.fish_tex,
			int(row.food.fish_icon),
			f32(food.FISH_CELL_SIZE),
			food.FISH_ATLAS_COLS,
			{pcx, cy},
		)
	} else {
		food.draw_icon(
			food.bread_tex,
			int(row.food.bread_icon),
			f32(food.BREAD_CELL_SIZE),
			food.BREAD_ATLAS_COLS,
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

draw_people :: proc(p: ^People, view: rl.Rectangle) {
	for i in 0 ..< len(p.rows) {
		if p.rows[i].motion.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		col := p.rows[i].traits.color
		if p.rows[i].identity.role == .Apostle && p.rows[i].traits.draw_alpha < 1 {
			col.a = u8(f32(col.a) * p.rows[i].traits.draw_alpha)
		}
		rl.DrawRectangleV(
			{p.rows[i].transform.pos_x, p.rows[i].transform.pos_y},
			{p.rows[i].transform.size_w, p.rows[i].transform.size_h},
			col,
		)
	}
}

draw_person_outline :: proc(p: ^People, i: int, color: rl.Color) {
	draw_rect_outline(person_rect_at(p, i), color)
}

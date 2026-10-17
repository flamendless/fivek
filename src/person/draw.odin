package person

import "../food"
import rl "vendor:raylib"

FOOD_BUBBLE_ABOVE :: 8.0

food_bubble_visible :: proc(p: ^People, i: int) -> bool {
	if i < 0 || i >= len(p.rows) {
		return false
	}
	row := p.rows[i]
	if row.role != .Crowd || (!row.has_fish && !row.has_bread) {
		return false
	}
	switch row.phase {
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
	pcx := row.pos_x + row.size_w * 0.5
	icon_d := food.FOOD_ICON_DRAW_SIZE
	icon_r := icon_d * 0.5
	gap: f32 = 4
	inner_w: f32 = icon_d
	if row.has_fish && row.has_bread {
		inner_w = icon_d + gap + icon_d
	}
	bubble_w := inner_w + f32(BUBBLE_PAD) * 2
	bubble_h := icon_d + f32(BUBBLE_PAD) * 2
	bx := pcx - bubble_w * 0.5
	by := row.pos_y - bubble_h - FOOD_BUBBLE_ABOVE
	rl.DrawRectangleRec({bx, by, bubble_w, bubble_h}, {255, 255, 255, 230})
	rl.DrawRectangleLinesEx({bx, by, bubble_w, bubble_h}, 1, {40, 40, 40, 255})
	cy := by + f32(BUBBLE_PAD) + icon_r

	if row.has_fish && row.has_bread {
		fish_x := bx + f32(BUBBLE_PAD) + icon_r
		bread_x := bx + bubble_w - f32(BUBBLE_PAD) - icon_r
		food.draw_fish_icon(int(row.fish_icon), {fish_x, cy})
		food.draw_bread_icon(int(row.bread_icon), {bread_x, cy})
	} else if row.has_fish {
		food.draw_fish_icon(int(row.fish_icon), {pcx, cy})
	} else {
		food.draw_bread_icon(int(row.bread_icon), {pcx, cy})
	}
}

draw_food_bubbles :: proc(p: ^People, view: rl.Rectangle) {
	for i in 0 ..< len(p.rows) {
		if p.rows[i].phase == .Gone {
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
		if p.rows[i].phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		col := p.rows[i].color
		if p.rows[i].role == .Apostle && p.rows[i].reject_flash > 0 {
			col = rl.RED
		}
		rl.DrawRectangleV(
			{p.rows[i].pos_x, p.rows[i].pos_y},
			{p.rows[i].size_w, p.rows[i].size_h},
			col,
		)
	}
}

draw_person_outline :: proc(p: ^People, i: int, color: rl.Color) {
	draw_rect_outline(person_rect_at(p, i), color)
}

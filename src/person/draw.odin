package person

import rl "vendor:raylib"

draw_gift_dots :: proc(p: ^People, i: int) {
	row := p.rows[i]
	if !row.has_fish && !row.has_bread {
		return
	}
	hand_y := row.pos_y + row.size_h * 0.55
	if row.has_fish {
		fish_x := row.pos_x + row.size_w * 0.2
		rl.DrawCircleV({fish_x, hand_y}, GIFT_DOT_RADIUS, FISH_DOT_COLOR)
	}
	if row.has_bread {
		bread_x := row.pos_x + row.size_w * 0.8
		rl.DrawCircleV({bread_x, hand_y}, GIFT_DOT_RADIUS, BREAD_DOT_COLOR)
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
		rl.DrawRectangleV(
			{p.rows[i].pos_x, p.rows[i].pos_y},
			{p.rows[i].size_w, p.rows[i].size_h},
			p.rows[i].color,
		)
		draw_gift_dots(p, i)
	}
}

draw_person_outline :: proc(p: ^People, i: int, color: rl.Color) {
	draw_rect_outline(person_rect_at(p, i), color)
}

package person

import rl "vendor:raylib"
import "../currency"
import "../food"
import "../theme"

draw_apostle_perk_bubbles :: proc(p: ^People, view: rl.Rectangle) {
	font: i32 = APOSTLE_LABEL_FONT
	pad: f32 = BUBBLE_PAD
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.identity.role != .Apostle || row.motion.phase != .Following {
			continue
		}
		if row.perk.perk_bubble.kind == .None {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		if row.traits.draw_alpha <= 0.05 {
			continue
		}
		cx := person_cx(p, i)
		anchor_y := row.transform.pos_y - 4
		bubble_h: f32
		bubble_w: f32
		switch row.perk.perk_bubble.kind {
		case .Intent_Text, .Judas_Angry, .Passive_Text:
			draw_speech_bubble_text(cx, anchor_y, row.perk.perk_bubble.text, font)
		case .Judas_Coin:
			icon := food.FOOD_ICON_DRAW_SIZE
			bubble_w = icon + pad * 2
			bubble_h = icon + pad * 2
			draw_speech_bubble(cx, anchor_y, bubble_w, bubble_h)
			cy := anchor_y - bubble_h * 0.5
			currency.draw_coin_icon(int(row.perk.perk_bubble.coin_icon), {cx, cy})
		case .Philip_Calc:
			icon := food.FOOD_ICON_DRAW_SIZE
			gap: f32 = 4
			eq: cstring = "= ???"
			eq_w := f32(rl.MeasureText(eq, font))
			mid: cstring = "x"
			mw := f32(rl.MeasureText(mid, font))
			bubble_w = icon + gap + mw + gap + icon + gap + eq_w + pad * 2
			bubble_h = icon + pad * 2
			draw_speech_bubble(cx, anchor_y, bubble_w, bubble_h)
			left := cx - bubble_w * 0.5 + pad
			cy := anchor_y - bubble_h * 0.5
			if food.ready() {
				food.draw_icon(
					food.fish_tex,
					int(row.perk.perk_bubble.philip_fish) % food.FISH_ICON_COUNT,
					f32(food.FISH_CELL_SIZE),
					food.FISH_ATLAS_COLS,
					{left + icon * 0.5, cy},
				)
				food.draw_icon(
					food.bread_tex,
					int(row.perk.perk_bubble.philip_bread) % food.BREAD_ICON_COUNT,
					f32(food.BREAD_CELL_SIZE),
					food.BREAD_ATLAS_COLS,
					{left + icon + gap + mw + gap + icon * 0.5, cy},
				)
			}
			rl.DrawText(mid, i32(left + icon + gap), i32(cy - f32(font) * 0.5), font, theme.TEXT_INK)
			rl.DrawText(eq, i32(left + icon + gap + mw + gap + icon + gap), i32(cy - f32(font) * 0.5), font, theme.TEXT_INK)
		case .None:
			break
		}
	}
}

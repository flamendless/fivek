package person

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../ui"
import "../theme"

apostle_req_row_width :: proc(kind: Stat_Kind, avail: u32, req: u32, font: i32) -> f32 {
	symbol_w := stat_symbol_width(kind, font)
	nums := stat_req_numbers(avail, req)
	return symbol_w + REQ_NUM_GAP + f32(rl.MeasureText(nums, font))
}

measure_apostle_requirement_bubble :: proc(
	p: ^People,
	apostle_idx: int,
	available: Run_Stats,
	font: i32,
) -> (bubble_w, bubble_h: f32) {
	line_gap: f32 = 1
	title_h := f32(font)
	req_row_h := math.max(title_h, ui.UI_ICON_DRAW_SIZE)
	def := APOSTLE_DEFS[apostle_idx]
	reqs := p.apostle_requirements[apostle_idx]
	bonus_kind := apostle_bonus_kind(apostle_idx)
	bonus_line: cstring = ""
	if bonus_kind != .None {
		bonus_line = fmt.ctprintf("Bonus: %s", apostle_bonus_label(bonus_kind))
	}
	title := fmt.ctprintf("%s:", def.name)
	tw := f32(rl.MeasureText(title, font))
	if bonus_line != "" {
		bw := f32(rl.MeasureText(bonus_line, font))
		if bw > tw {
			tw = bw
		}
	}
	n := int(reqs.count)
	for j in 0 ..< n {
		r := reqs.reqs[j]
		avail := stat_value(available, r.kind)
		rw := apostle_req_row_width(r.kind, avail, r.amount, font)
		if rw > tw {
			tw = rw
		}
	}
	bubble_w = tw + BUBBLE_PAD * 2
	bubble_h = BUBBLE_PAD + title_h + line_gap + f32(n) * req_row_h
	if n > 0 {
		bubble_h += f32(n - 1) * line_gap
	}
	if bonus_line != "" {
		bubble_h += line_gap + title_h
	}
	bubble_h += BUBBLE_PAD
	return bubble_w, bubble_h
}

draw_apostle_requirement_bubble :: proc(
	p: ^People,
	apostle_idx: int,
	available: Run_Stats,
	cx: f32,
	anchor_y: f32,
	font: i32,
) {
	line_gap: f32 = 1
	title_h := f32(font)
	req_row_h := math.max(title_h, ui.UI_ICON_DRAW_SIZE)
	def := APOSTLE_DEFS[apostle_idx]
	reqs := p.apostle_requirements[apostle_idx]
	bonus_kind := apostle_bonus_kind(apostle_idx)
	bonus_line: cstring = ""
	if bonus_kind != .None {
		bonus_line = fmt.ctprintf("Bonus: %s", apostle_bonus_label(bonus_kind))
	}
	bubble_w, bubble_h := measure_apostle_requirement_bubble(p, apostle_idx, available, font)
	draw_speech_bubble(cx, anchor_y, bubble_w, bubble_h)
	bx := cx - bubble_w * 0.5
	by := anchor_y - bubble_h
	content_x := bx + BUBBLE_PAD
	ty := by + BUBBLE_PAD
	name_w := rl.MeasureText(def.name, font)
	rl.DrawText(def.name, i32(content_x), i32(ty), font, def.color)
	rl.DrawText(":", i32(content_x + f32(name_w)), i32(ty), font, theme.TEXT_INK)
	ty += title_h + line_gap
	if bonus_line != "" {
		rl.DrawText(bonus_line, i32(content_x), i32(ty), font, theme.REQ_MET)
		ty += title_h + line_gap
	}
	n := int(reqs.count)
	for j in 0 ..< n {
		r := reqs.reqs[j]
		avail := stat_value(available, r.kind)
		symbol_w := stat_symbol_width(r.kind, font)
		draw_stat_symbol(r.kind, content_x, ty, req_row_h, font, theme.TEXT_INK)
		nums := stat_req_numbers(avail, r.amount)
		num_col := stat_req_met(avail, r.amount) ? theme.REQ_MET : theme.REQ_SHORT
		num_ty := i32(ty + req_row_h) - font
		rl.DrawText(nums, i32(content_x + symbol_w + REQ_NUM_GAP), num_ty, font, num_col)
		ty += req_row_h + line_gap
	}
}

apostle_hit_index_at :: proc(p: ^People, at: rl.Vector2) -> int {
	for i := len(p.rows) - 1; i >= p.crowd_count; i -= 1 {
		row := p.rows[i]
		if row.identity.role != .Apostle || row.motion.phase == .Gone {
			continue
		}
		if rl.CheckCollisionPointRec(at, person_rect_at(p, i)) {
			return i
		}
	}
	return -1
}

draw_apostle_credits_speech_at :: proc(p: ^People, person_i: int, show_requirements: bool) {
	if person_i < p.crowd_count || person_i >= len(p.rows) {
		return
	}
	row := p.rows[person_i]
	if row.identity.role != .Apostle {
		return
	}
	cx := row.transform.pos_x + row.transform.size_w * 0.5
	anchor_y := row.transform.pos_y - 4
	apostle_idx := int(row.identity.apostle_idx)
	def := APOSTLE_DEFS[apostle_idx]
	if show_requirements {
		available: Run_Stats
		draw_apostle_requirement_bubble(p, apostle_idx, available, cx, anchor_y, CREDITS_SPEECH_FONT)
		return
	}
	if speech := apostle_reject_speech_text(p, apostle_idx); speech != "" {
		draw_speech_bubble_named_wrap(cx, anchor_y, def.name, def.color, speech)
	}
}

draw_apostle_credits_hover :: proc(p: ^People, person_i: int) {
	draw_apostle_credits_speech_at(p, person_i, false)
}

draw_apostle_overlays :: proc(
	p: ^People,
	view: rl.Rectangle,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
	available: Run_Stats,
) {
	player_rect := rl.Rectangle{player_pos.x, player_pos.y, player_size.x, player_size.y}
	font: i32 = APOSTLE_LABEL_FONT
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.identity.role != .Apostle || row.motion.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		if row.motion.phase == .Active &&
		   is_apostle_interactable(p, i) &&
		   rl.CheckCollisionRecs(player_rect, pr) {
			cx := row.transform.pos_x + row.transform.size_w * 0.5
			anchor_y := row.transform.pos_y - 4

			if row.behavior.reject_speech_show {
				text := apostle_reject_speech_text(p, int(row.identity.apostle_idx))
				if text != "" {
					draw_speech_bubble_text(cx, anchor_y, text, font)
				}
				continue
			}

			draw_apostle_requirement_bubble(
				p,
				int(row.identity.apostle_idx),
				available,
				cx,
				anchor_y,
				font,
			)
		}
	}
}

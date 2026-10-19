package person

import "core:fmt"
import rl "vendor:raylib"
import "../config"
import "../input"
import "../theme"

when config.IS_DEBUG {

apostle_debug_clamp_slot :: proc(p: ^People) {
	if p.party.count <= 0 {
		p.debug.apostle_inspector_slot = 0
		return
	}
	if p.debug.apostle_inspector_slot < 0 {
		p.debug.apostle_inspector_slot = 0
	}
	if p.debug.apostle_inspector_slot >= p.party.count {
		p.debug.apostle_inspector_slot = p.party.count - 1
	}
}

apostle_debug_tick_input :: proc(p: ^People) {
	if input.key_pressed(.I) {
		p.debug.apostle_inspector_open = !p.debug.apostle_inspector_open
	}
	if !p.debug.apostle_inspector_open {
		return
	}
	apostle_debug_clamp_slot(p)
	if p.party.count <= 0 {
		return
	}
	if input.key_pressed(.LEFT_BRACKET) {
		p.debug.apostle_inspector_slot -= 1
		if p.debug.apostle_inspector_slot < 0 {
			p.debug.apostle_inspector_slot = p.party.count - 1
		}
	}
	if input.key_pressed(.RIGHT_BRACKET) {
		p.debug.apostle_inspector_slot += 1
		if p.debug.apostle_inspector_slot >= p.party.count {
			p.debug.apostle_inspector_slot = 0
		}
	}
}

draw_apostle_debug_inspector :: proc(
	p: ^People,
	font: i32,
	game_w: f32,
	pad: i32,
	line_step: i32,
	top_y: i32,
) {
	if !p.debug.apostle_inspector_open {
		return
	}
	apostle_debug_clamp_slot(p)

	lines: [28]cstring
	n := 0
	lines[n] = fmt.ctprintf(
		"Party %d  trail %d  escort %d",
		p.party.count,
		p.party.trail_count,
		p.escort.count,
	)
	n += 1
	if p.party.count > 0 {
		totals := party_bonuses(p)
		hud := party_bonus_hud_line(totals)
		if hud != "" && n < len(lines) {
			lines[n] = hud
			n += 1
		}
	}

	if p.party.count == 0 {
		lines[n] = "Party empty"
		n += 1
		lines[n] = "L recruit (bypass)"
		n += 1
	} else {
		for slot in 0 ..< p.party.count {
			if n >= len(lines) - 12 {
				break
			}
			i := apostle_follow_index_by_slot(p, slot)
			if i < 0 {
				lines[n] = fmt.ctprintf("%d: (missing)", slot)
				n += 1
				continue
			}
			row := p.rows[i]
			idx := int(row.identity.apostle_idx)
			name: cstring = "?"
			if idx >= 0 && idx < APOSTLE_COUNT {
				name = APOSTLE_DEFS[idx].name
			}
			prefix := slot == p.debug.apostle_inspector_slot ? "*" : " "
			bonus := apostle_bonus_label(apostle_bonus_kind(idx))
			lines[n] = fmt.ctprintf(
				"%s%d %s %s %v %v %v pt:%.1f",
				prefix,
				slot,
				name,
				bonus,
				row.motion.phase,
				row.motion.state,
				row.perk.apostle_perk,
				row.perk.perk_timer,
				row.perk.perk_cooldown,
			)
			n += 1
		}

		sel := p.debug.apostle_inspector_slot
		i := apostle_follow_index_by_slot(p, sel)
		if i >= 0 && n < len(lines) {
			row := p.rows[i]
			lines[n] = "--- detail ---"
			n += 1
			if n < len(lines) {
				lines[n] = fmt.ctprintf("sub %v  rej:%.2f  a:%.2f", row.behavior.subbehavior, row.behavior.reject_flash, row.traits.draw_alpha)
				n += 1
			}
			if n < len(lines) {
				lines[n] = fmt.ctprintf("tgt:%d aux:%d row:%d x:%.0f", row.perk.perk_target_i, row.perk.perk_aux, i, row.transform.pos_x)
				n += 1
			}
			if n < len(lines) {
				lines[n] = fmt.ctprintf(
					"bubble %v t:%.1f",
					row.perk.perk_bubble.kind,
					row.perk.perk_bubble.timer,
				)
				n += 1
			}
			if n < len(lines) && row.perk.apostle_perk != .Follow {
				lines[n] = fmt.ctprintf("perk_timer %.2f", row.perk.perk_timer)
				n += 1
			}
		}
	}

	panel_w: i32 = 0
	for j in 0 ..< n {
		w := rl.MeasureText(lines[j], font)
		if w > panel_w {
			panel_w = w
		}
	}
	if panel_w < 80 {
		panel_w = 80
	}
	x := i32(game_w) - panel_w - pad
	y := top_y
	panel_h := i32(n) * line_step + 2
	rl.DrawRectangle(x - 2, y - 1, panel_w + 4, panel_h, theme.OVERLAY_SCRIM_180)
	for j in 0 ..< n {
		col := rl.LIGHTGRAY
		if p.party.count > 0 && j == 1 + p.debug.apostle_inspector_slot {
			col = theme.DEBUG_CYAN_BRIGHT
		}
		rl.DrawText(lines[j], x, y + i32(j) * line_step, font, col)
	}
}

draw_apostle_debug_world_labels :: proc(p: ^People, view: rl.Rectangle, font: i32) {
	if !p.debug.apostle_inspector_open || p.party.count == 0 {
		return
	}
	for slot in 0 ..< p.party.count {
		i := apostle_follow_index_by_slot(p, slot)
		if i < 0 {
			continue
		}
		row := p.rows[i]
		if row.motion.phase != .Following {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		idx := int(row.identity.apostle_idx)
		name: cstring = "?"
		if idx >= 0 && idx < APOSTLE_COUNT {
			name = APOSTLE_DEFS[idx].name
		}
		label := fmt.ctprintf("%s: %v", name, row.perk.apostle_perk)
		tw := rl.MeasureText(label, font)
		cx := person_cx(p, i)
		tx := i32(cx - f32(tw) * 0.5)
		ty := i32(row.transform.pos_y - f32(font) - 6)
		rl.DrawRectangle(tx - 1, ty - 1, tw + 2, font + 2, theme.OVERLAY_SCRIM_140)
		rl.DrawText(label, tx, ty, font, rl.YELLOW)
	}
}

}

package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../achievements"
import "../config"
import ui_assets "../ui"
import "../theme"

ACHIEVEMENT_TOAST_HOLD_S :: 3.5
ACHIEVEMENT_TOAST_FADE_S :: 1.5
ACHIEVEMENT_TOAST_LIFETIME_S :: ACHIEVEMENT_TOAST_HOLD_S + ACHIEVEMENT_TOAST_FADE_S
ACHIEVEMENT_TOAST_MAX :: 8
ACHIEVEMENT_TOAST_SLIDE_S :: 0.2

ACHIEVEMENT_TOAST_TITLE_DESIGN :: 12
ACHIEVEMENT_TOAST_DESC_DESIGN :: 9
ACHIEVEMENT_TOAST_PAD_DESIGN :: 6
ACHIEVEMENT_TOAST_GAP_DESIGN :: 4
ACHIEVEMENT_TOAST_TEXT_GAP_DESIGN :: 4

Achievement_Toast_Entry :: struct {
	id:           achievements.Id,
	timer:        f32,
	display_y:    f32,
	target_y:     f32,
	slide_active: bool,
}

Achievement_Toast_Stack :: struct {
	entries: [dynamic]Achievement_Toast_Entry,
}

achievement_toast_text_metrics :: proc(g: ^Game, title, desc: cstring) -> (title_h, desc_h, gap: f32) {
	title_m := title_measure_default(g, title, ACHIEVEMENT_TOAST_TITLE_DESIGN)
	desc_m := title_measure_default(g, desc, ACHIEVEMENT_TOAST_DESC_DESIGN)
	gap = f32(ui_px(g, ACHIEVEMENT_TOAST_TEXT_GAP_DESIGN))
	return title_m.y, desc_m.y, gap
}

achievement_toast_entry_h :: proc(g: ^Game, title, desc: cstring) -> f32 {
	pad := f32(ui_px(g, ACHIEVEMENT_TOAST_PAD_DESIGN))
	title_h, desc_h, gap := achievement_toast_text_metrics(g, title, desc)
	return pad + title_h + gap + desc_h + pad
}

achievement_toast_slot_step :: proc(g: ^Game, title, desc: cstring) -> f32 {
	return achievement_toast_entry_h(g, title, desc) + f32(ui_px(g, ACHIEVEMENT_TOAST_GAP_DESIGN))
}

achievement_toast_top_y :: proc(g: ^Game) -> f32 {
	return f32(ui_px(g, 16))
}

achievement_toast_layout_y :: proc(g: ^Game, index: int, step: f32) -> f32 {
	return achievement_toast_top_y(g) + f32(index) * step
}

achievement_toast_entry_alpha :: proc(timer: f32) -> f32 {
	if timer <= ACHIEVEMENT_TOAST_HOLD_S {
		return 1
	}
	t := (timer - ACHIEVEMENT_TOAST_HOLD_S) / ACHIEVEMENT_TOAST_FADE_S
	return math.clamp(1 - t, 0, 1)
}

achievement_toast_drain_pending :: proc(g: ^Game) {
	slot_step: f32 = 0
	for id in g.achievement_pending {
		if len(g.achievement_toasts.entries) >= ACHIEVEMENT_TOAST_MAX {
			break
		}
		def := achievements.ACHIEVEMENT_DEFS[id]
		if slot_step <= 0 {
			slot_step = achievement_toast_slot_step(g, def.title, def.description)
		}
		idx := len(g.achievement_toasts.entries)
		y := achievement_toast_layout_y(g, idx, slot_step)
		append(
			&g.achievement_toasts.entries,
			Achievement_Toast_Entry{id = id, display_y = y, target_y = y},
		)
	}
	clear(&g.achievement_pending)
}

achievement_toast_retarget_below :: proc(g: ^Game, step: f32) {
	for i in 0 ..< len(g.achievement_toasts.entries) {
		e := &g.achievement_toasts.entries[i]
		e.target_y = achievement_toast_layout_y(g, i, step)
		if math.abs(e.display_y - e.target_y) > 0.5 {
			e.slide_active = true
		}
	}
}

update_achievement_toasts :: proc(g: ^Game, dt: f32) {
	achievement_toast_drain_pending(g)
	stack := &g.achievement_toasts
	if len(stack.entries) == 0 {
		return
	}

	slot_step := achievement_toast_slot_step(
		g,
		achievements.ACHIEVEMENT_DEFS[stack.entries[0].id].title,
		achievements.ACHIEVEMENT_DEFS[stack.entries[0].id].description,
	)

	for i in 0 ..< len(stack.entries) {
		e := &stack.entries[i]
		if e.slide_active {
			slide := ACHIEVEMENT_TOAST_SLIDE_S
			if slide <= 0 {
				e.display_y = e.target_y
				e.slide_active = false
			} else {
				e.display_y += (e.target_y - e.display_y) * math.min(1, dt / f32(slide))
				if math.abs(e.display_y - e.target_y) < 0.5 {
					e.display_y = e.target_y
					e.slide_active = false
				}
			}
		}
	}

	top := &stack.entries[0]
	top.timer += dt

	for len(stack.entries) > 0 && stack.entries[0].timer >= ACHIEVEMENT_TOAST_LIFETIME_S {
		ordered_remove(&stack.entries, 0)
		achievement_toast_retarget_below(g, slot_step)
		if len(stack.entries) > 0 {
			stack.entries[0].timer += dt
		}
	}
}

achievement_toast_panel_w :: proc(g: ^Game, title, desc: cstring) -> i32 {
	pad := ui_px(g, ACHIEVEMENT_TOAST_PAD_DESIGN)
	tw := title_measure_default(g, title, ACHIEVEMENT_TOAST_TITLE_DESIGN).x
	dw := title_measure_default(g, desc, ACHIEVEMENT_TOAST_DESC_DESIGN).x
	return i32(max(tw, dw)) + pad * 2
}

achievement_toast_draw_centered_in :: proc(
	g: ^Game,
	text: cstring,
	y: f32,
	design: i32,
	content: rl.Rectangle,
	color: rl.Color,
) {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	m := rl.MeasureTextEx(font, text, size, spacing)
	x := content.x + (content.width - m.x) * 0.5
	rl.DrawTextEx(font, text, {x, y}, size, spacing, color)
}

draw_achievement_toasts :: proc(g: ^Game) {
	stack := &g.achievement_toasts
	if len(stack.entries) == 0 {
		return
	}

	for &e in stack.entries {
		def := achievements.ACHIEVEMENT_DEFS[e.id]
		alpha := achievement_toast_entry_alpha(e.timer)
		if alpha <= 0 {
			continue
		}

		title_h, desc_h, gap := achievement_toast_text_metrics(g, def.title, def.description)
		pad := ui_px(g, ACHIEVEMENT_TOAST_PAD_DESIGN)
		panel_w := achievement_toast_panel_w(g, def.title, def.description)
		panel_h := i32(achievement_toast_entry_h(g, def.title, def.description))
		x := i32((g.view.game_size.x - f32(panel_w)) * 0.5)
		y := i32(e.display_y)

		bg := rl.WHITE
		bg.a = u8(f32(255) * alpha)
		dest := rl.Rectangle{f32(x), f32(y), f32(panel_w), f32(panel_h)}
		ui_assets.draw_parchment_dialog(dest, bg)
		content := ui_assets.parchment_content(dest, 0)

		fill := rl.Color{0, 0, 0, u8(f32(255) * alpha)}
		block_h := title_h + gap + desc_h
		ty := content.y + (content.height - block_h) * 0.5
		achievement_toast_draw_centered_in(g, def.title, ty, ACHIEVEMENT_TOAST_TITLE_DESIGN, content, fill)
		ty += title_h + gap
		achievement_toast_draw_centered_in(g, def.description, ty, ACHIEVEMENT_TOAST_DESC_DESIGN, content, fill)
	}
}

when config.IS_DEBUG {
	// Toast only — does not mark achievements unlocked or persist.
	debug_queue_random_achievement_toast :: proc(g: ^Game) {
		id := achievements.Id(rand.int_max(achievements.ACHIEVEMENT_COUNT))
		append(&g.achievement_pending, id)
	}
}
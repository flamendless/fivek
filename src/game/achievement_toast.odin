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

achievement_toast_entry_h :: proc(g: ^Game) -> f32 {
	title_font := f32(ui_font(g, ACHIEVEMENT_TOAST_TITLE_DESIGN))
	desc_font := f32(ui_font(g, ACHIEVEMENT_TOAST_DESC_DESIGN))
	pad := f32(ui_px(g, ACHIEVEMENT_TOAST_PAD_DESIGN))
	gap := f32(ui_px(g, 2))
	return pad + title_font + gap + desc_font + pad
}

achievement_toast_slot_step :: proc(g: ^Game) -> f32 {
	return achievement_toast_entry_h(g) + f32(ui_px(g, ACHIEVEMENT_TOAST_GAP_DESIGN))
}

achievement_toast_top_y :: proc(g: ^Game) -> f32 {
	return f32(ui_px(g, 16))
}

achievement_toast_layout_y :: proc(g: ^Game, index: int) -> f32 {
	return achievement_toast_top_y(g) + f32(index) * achievement_toast_slot_step(g)
}

achievement_toast_entry_alpha :: proc(timer: f32) -> f32 {
	if timer <= ACHIEVEMENT_TOAST_HOLD_S {
		return 1
	}
	t := (timer - ACHIEVEMENT_TOAST_HOLD_S) / ACHIEVEMENT_TOAST_FADE_S
	return math.clamp(1 - t, 0, 1)
}

achievement_toast_drain_pending :: proc(g: ^Game) {
	for id in g.achievement_pending {
		if len(g.achievement_toasts.entries) >= ACHIEVEMENT_TOAST_MAX {
			break
		}
		idx := len(g.achievement_toasts.entries)
		y := achievement_toast_layout_y(g, idx)
		append(
			&g.achievement_toasts.entries,
			Achievement_Toast_Entry{id = id, display_y = y, target_y = y},
		)
	}
	clear(&g.achievement_pending)
}

achievement_toast_retarget_below :: proc(g: ^Game) {
	for i in 0 ..< len(g.achievement_toasts.entries) {
		e := &g.achievement_toasts.entries[i]
		e.target_y = achievement_toast_layout_y(g, i)
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
		achievement_toast_retarget_below(g)
		if len(stack.entries) > 0 {
			stack.entries[0].timer += dt
		}
	}
}

achievement_toast_panel_w :: proc(g: ^Game, title, desc: cstring) -> i32 {
	pad := ui_px(g, ACHIEVEMENT_TOAST_PAD_DESIGN)
	tw := title_measure_default(g, title, ACHIEVEMENT_TOAST_TITLE_DESIGN).x
	dw := title_measure_default(g, desc, ACHIEVEMENT_TOAST_DESC_DESIGN).x
	outline := title_text_outline_px(g) * 2
	inner := max(tw, dw) + outline
	return i32(inner) + pad * 2
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

		title_font := ui_font(g, ACHIEVEMENT_TOAST_TITLE_DESIGN)
		desc_font := ui_font(g, ACHIEVEMENT_TOAST_DESC_DESIGN)
		pad := ui_px(g, ACHIEVEMENT_TOAST_PAD_DESIGN)
		gap := ui_px(g, 2)
		panel_w := achievement_toast_panel_w(g, def.title, def.description)
		panel_h := i32(achievement_toast_entry_h(g))
		x := i32((g.view.game_size.x - f32(panel_w)) * 0.5)
		y := i32(e.display_y)

		bg := rl.WHITE
		bg.a = u8(f32(255) * alpha)
		dest := rl.Rectangle{f32(x), f32(y), f32(panel_w), f32(panel_h)}
		ui_assets.draw_parchment_dialog(dest, bg)
		content := ui_assets.parchment_content(dest, 0)

		fill := rl.Color{0, 0, 0, u8(f32(255) * alpha)}
		outline := fill
		ty := content.y + f32(pad)
		title_draw_centered_default_outlined(g, def.title, ty, ACHIEVEMENT_TOAST_TITLE_DESIGN, fill, outline)
		ty += f32(title_font) + f32(gap)
		title_draw_centered_default(g, def.description, ty, ACHIEVEMENT_TOAST_DESC_DESIGN, fill)
	}
}

when config.IS_DEBUG {
	// Toast only — does not mark achievements unlocked or persist.
	debug_queue_random_achievement_toast :: proc(g: ^Game) {
		id := achievements.Id(rand.int_max(achievements.ACHIEVEMENT_COUNT))
		append(&g.achievement_pending, id)
	}
}

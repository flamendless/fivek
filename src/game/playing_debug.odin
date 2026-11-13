package game

import "core:fmt"
import rl "vendor:raylib"
import "../config"
import "../person"
import ui_assets "../ui"
import "../theme"

when config.IS_DEBUG {
	PAUSE_DEBUG_STATS_FONT_DESIGN :: 12
	PAUSE_DEBUG_STATS_PAD_DESIGN :: 6
	PAUSE_DEBUG_STATS_LINE_GAP_DESIGN :: 2

	playing_debug_visible :: proc(g: ^Game) -> bool {
		when config.IS_AUTOTEST {
			return g.autotest.autoplay || g.defs.debug
		}
		return g.defs.debug
	}

	pause_stat_delta_color :: proc(delta: f32) -> rl.Color {
		if delta > 0 {
			return theme.PARTY_BONUS_GREEN
		}
		return theme.REQ_SHORT
	}

	draw_pause_debug_player_stats :: proc(g: ^Game) {
		if !playing_debug_visible(g) {
			return
		}

		bonuses := person.party_bonuses(g.scene.people)
		rows: [person.PARTY_DEBUG_STAT_COUNT]person.Party_Debug_Stat_Row
		person.party_debug_stat_rows(
			bonuses,
			g.scene.player.speed,
			g.defs.interact_radius,
			&rows,
		)

		font := ui_font(g, PAUSE_DEBUG_STATS_FONT_DESIGN)
		pad := ui_px(g, PAUSE_DEBUG_STATS_PAD_DESIGN)
		line_gap := ui_px(g, PAUSE_DEBUG_STATS_LINE_GAP_DESIGN)
		line_step := font + line_gap

		content_w: i32 = 0
		for row in rows {
			content_w = max(content_w, person.measure_party_debug_stat_row(row, font))
		}
		line_count: i32 = person.PARTY_DEBUG_STAT_COUNT
		content_h := font * line_count + line_gap * (line_count - 1)
		panel_w := ui_assets.wood_panel_width_for_inner(f32(content_w), 0)
		panel_h := ui_assets.wood_panel_height_for_inner(f32(content_h), 0)

		panel := rl.Rectangle{f32(pad), f32(pad), panel_w, panel_h}
		ui_assets.draw_wood_panel(panel)
		content := ui_assets.wood_panel_content(panel, 0)
		x := i32(content.x)
		y := i32(content.y)

		for row in rows {
			draw_labeled_value_delta(
				x,
				y,
				font,
				row.label,
				row.base,
				row.delta,
				pause_stat_delta_color(row.delta_value),
			)
			y += line_step
		}
	}

	draw_playing_debug_overlay :: proc(g: ^Game) {
		if !playing_debug_visible(g) {
			return
		}
		speed: f32 = 1.0
		when config.IS_AUTOTEST {
			if g.autotest.autoplay {
				speed = AUTOPLAY_SIM_SPEED
			}
		}
		speed_label := fmt.ctprintf("Speed %.1fx", speed)
		bg_label: cstring
		if g.scene.bg != nil {
			bg_label = fmt.ctprintf("bg %s", g.scene.bg.set_name)
		} else {
			bg_label = "bg (none)"
		}
		font := ui_font(g, 10)
		pad := ui_px(g, 4)
		line_gap := ui_px(g, 2)
		dbg_toast: cstring = "L  Random achievement toast"
		dbg_recruit: cstring = "K  Recruit apostle (bypass)"
		dbg_inspector: cstring = "I  Apostle inspector"
		dbg_slot: cstring = "[ ]  Select party slot"
		w_speed := rl.MeasureText(speed_label, font)
		w_bg := rl.MeasureText(bg_label, font)
		w_toast := rl.MeasureText(dbg_toast, font)
		w_recruit := rl.MeasureText(dbg_recruit, font)
		w_inspector := rl.MeasureText(dbg_inspector, font)
		w_slot := rl.MeasureText(dbg_slot, font)
		panel_text_w := max(w_speed, w_bg, w_toast, w_recruit, w_inspector, w_slot)
		content_h := font * 6 + line_gap * 5
		panel_w := i32(ui_assets.wood_panel_width_for_inner(f32(panel_text_w), 0))
		panel_h := i32(ui_assets.wood_panel_height_for_inner(f32(content_h), 0))
		panel_x := i32(g.view.game_size.x) - panel_w - pad
		panel_y: i32 = pad
		panel := rl.Rectangle{f32(panel_x), f32(panel_y), f32(panel_w), f32(panel_h)}
		rl.BeginMode2D(g.cameras.ui_camera)
			ui_assets.draw_wood_panel(panel)
			content := ui_assets.wood_panel_content(panel, 0)
			x := i32(content.x)
			y := i32(content.y)
			rl.DrawText(speed_label, x, y, font, theme.TEXT_INK)
			rl.DrawText(bg_label, x, y + font + line_gap, font, theme.TEXT_INK)
			rl.DrawText(dbg_toast, x, y + (font + line_gap) * 2, font, theme.TEXT_INK)
			rl.DrawText(dbg_recruit, x, y + (font + line_gap) * 3, font, theme.TEXT_INK)
			rl.DrawText(dbg_inspector, x, y + (font + line_gap) * 4, font, theme.TEXT_INK)
			rl.DrawText(dbg_slot, x, y + (font + line_gap) * 5, font, theme.TEXT_INK)
			inspector_top := panel_y + panel_h + line_gap
			person.draw_apostle_debug_inspector(
				g.scene.people,
				font,
				g.view.game_size.x,
				pad,
				font + line_gap,
				inspector_top,
			)
		rl.EndMode2D()
	}

	DEBUG_FPS_FONT_DESIGN :: 20

	draw_debug_fps :: proc(g: ^Game) {
		font := ui_font(g, DEBUG_FPS_FONT_DESIGN)
		pad := ui_px(g, 8)
		label := fmt.ctprintf("FPS %d", rl.GetFPS())
		bottom_reserve: i32 = 0
		if g.mode == .Playing && !g.run.paused {
			bottom_reserve = ui_px(g, 8) + ui_px(g, 4) + ui_px(g, 2)
		}
		y := i32(g.view.game_size.y) - font - pad - bottom_reserve
		rl.DrawText(label, pad, y, font, rl.RED)
	}

	draw_dev_version_badge :: proc(g: ^Game) {
		label := fmt.ctprintf("DEV %s", g.defs.version)
		ver_m := title_measure_default(g, label, TITLE_VERSION_FONT_DESIGN)
		ver_pad := f32(ui_px(g, 8))
		ver_x := g.view.game_size.x - ver_m.x - ver_pad
		ver_y := g.view.game_size.y - ver_m.y - ver_pad
		ver_font := rl.GetFontDefault()
		ver_size := f32(ui_font(g, TITLE_VERSION_FONT_DESIGN))
		ver_spacing := title_char_spacing(g, 1)
		rl.DrawTextEx(ver_font, label, {ver_x, ver_y}, ver_size, ver_spacing, rl.RED)
	}
}

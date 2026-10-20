package game

import "core:fmt"
import rl "vendor:raylib"
import "../config"
import "../person"
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
		x := pad
		y := pad

		panel_w: i32 = 0
		for row in rows {
			panel_w = max(panel_w, person.measure_party_debug_stat_row(row, font))
		}
		line_count: i32 = person.PARTY_DEBUG_STAT_COUNT
		panel_pad := ui_px(g, 2)
		panel_h := font * line_count + line_gap * (line_count - 1) + panel_pad * 2

		rl.DrawRectangle(
			x - panel_pad,
			y - panel_pad,
			panel_w + panel_pad * 2,
			panel_h,
			theme.OVERLAY_SCRIM_160,
		)

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
		font := ui_font(g, 8)
		pad := ui_px(g, 4)
		line_gap := ui_px(g, 1)
		dbg_recruit: cstring = "L  Recruit apostle (bypass)"
		dbg_inspector: cstring = "I  Apostle inspector"
		dbg_slot: cstring = "[ ]  Select party slot"
		w_speed := rl.MeasureText(speed_label, font)
		w_bg := rl.MeasureText(bg_label, font)
		w_recruit := rl.MeasureText(dbg_recruit, font)
		w_inspector := rl.MeasureText(dbg_inspector, font)
		w_slot := rl.MeasureText(dbg_slot, font)
		panel_text_w := max(w_speed, w_bg, w_recruit, w_inspector, w_slot)
		x := i32(g.view.game_size.x) - panel_text_w - pad
		y: i32 = pad
		panel_h := font * 5 + line_gap * 4 + 2
		fps_font := ui_font(g, 20)
		fps_label := fmt.ctprintf("FPS %d", rl.GetFPS())
		fps_x := pad
		fps_y := i32(g.view.game_size.y) - fps_font - pad
		rl.BeginMode2D(g.cameras.ui_camera)
			rl.DrawRectangle(x - ui_px(g, 2), y - 1, panel_text_w + ui_px(g, 4), panel_h, theme.OVERLAY_SCRIM_160)
			rl.DrawText(speed_label, x, y, font, rl.YELLOW)
			rl.DrawText(bg_label, x, y + font + line_gap, font, rl.GRAY)
			rl.DrawText(dbg_recruit, x, y + (font + line_gap) * 2, font, theme.DEBUG_CYAN)
			rl.DrawText(dbg_inspector, x, y + (font + line_gap) * 3, font, theme.DEBUG_GREEN)
			rl.DrawText(dbg_slot, x, y + (font + line_gap) * 4, font, theme.DEBUG_GREEN)
			rl.DrawText(fps_label, fps_x, fps_y, fps_font, rl.RED)
			inspector_top := y + panel_h + line_gap
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
}

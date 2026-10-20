package game

import "core:fmt"
import rl "vendor:raylib"
import "../config"
import ui_assets "../ui"
import "../person"
import "../player"
import "../theme"

draw_pause_overlay :: proc(g: ^Game) {
	if !g.run.paused {
		return
	}

	body_font := ui_font(g, 14)
	resume_font := ui_font(g, 20)
	ctrl_font := ui_font(g, 14)
	pause_icon_size := f32(ui_font(g, 48))
	section_gap := f32(ui_px(g, 16))
	line_gap := f32(ui_px(g, 8))
	ctrl_icon := f32(ui_px(g, 20))
	ctrl_line_step := ctrl_font + ui_px(g, 6)
	controls_block_h := i32(GAMEPLAY_CONTROL_ROW_COUNT) * ctrl_line_step

	timer_label := format_play_time(g.run.play_time)
	resume_label: cstring = "Press P to resume"

	body_icon := f32(body_font)
	resume_icon := f32(resume_font)

	block_h :=
		pause_icon_size +
		section_gap +
		f32(body_font) +
		line_gap +
		f32(resume_font) +
		section_gap +
		f32(controls_block_h)
	y0 := (g.view.game_size.y - block_h) * 0.5

	rl.BeginMode2D(g.cameras.ui_camera)
	rl.DrawRectangle(0, 0, i32(g.view.game_size.x), i32(g.view.game_size.y), theme.OVERLAY_SCRIM_140)

	cx := g.view.game_size.x * 0.5
	pause_cy := y0 + pause_icon_size * 0.5
	ui_assets.draw_general_icon(1, {cx, pause_cy}, pause_icon_size)

	y: i32 = i32(y0 + pause_icon_size + section_gap)
	draw_centered_icon_text_row(g, y, body_font, .Hourglass, timer_label, rl.WHITE, body_icon)
	y += body_font + i32(line_gap)
	draw_centered_icon_text_row(g, y, resume_font, .General_Play, resume_label, rl.LIGHTGRAY, resume_icon)
	y += resume_font + i32(section_gap)
	draw_centered_gameplay_controls(g, y, ctrl_font, ctrl_icon, ctrl_line_step)

	seed_font := ui_font(g, 10)
	seed_pad := ui_px(g, 8)
	seed_label := fmt.ctprintf("Seed: %d", g.seed.value)
	rl.DrawText(seed_label, seed_pad, i32(g.view.game_size.y) - seed_font - seed_pad, seed_font, rl.GRAY)
	when config.IS_DEBUG {
		draw_pause_debug_player_stats(g)
	}
	rl.EndMode2D()
}

draw_playing_overlay :: proc(g: ^Game) {
	served := person.count_served(g.scene.people)
	available := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
	stat_font := ui_font(g, PLAYING_HUD_FONT_DESIGN)
	icon_size := f32(ui_px(g, PLAYING_HUD_ICON_DESIGN))
	pad := ui_px(g, 4)
	inner := pad + ui_px(g, 4)
	stat_line_step := max(stat_font, i32(icon_size)) + ui_px(g, 2)
	panel_w := ui_px(g, 168)
	stat_lines := 4
	bonuses := person.party_bonuses(g.scene.people)
	bar_h := ui_px(g, 5)
	stats_panel_h := ui_px(g, 2) + i32(stat_lines) * stat_line_step + ui_px(g, 2)
	if !g.run.paused {
		stats_panel_h += ui_px(g, 2) + bar_h + ui_px(g, 2)
	}
	mods := person.party_player_modifiers(bonuses)
	stats_y := pad
	rl.BeginMode2D(g.cameras.ui_camera)
		rl.DrawRectangle(pad, stats_y, panel_w, stats_panel_h, theme.OVERLAY_SCRIM_180)
		y: i32 = stats_y + ui_px(g, 2)
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.People,
			fmt.ctprintf("%d / %d", served, g.run.person_count),
			rl.WHITE,
		)
		y += stat_line_step
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.Fish,
			fmt.ctprintf("%d", available.fish_given),
			rl.LIGHTGRAY,
		)
		y += stat_line_step
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.Bread,
			fmt.ctprintf("%d", available.bread_given),
			rl.LIGHTGRAY,
		)
		y += stat_line_step
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.Coin,
			fmt.ctprintf("%d", g.run.coins),
			rl.LIGHTGRAY,
		)
		y += stat_line_step
		if !g.run.paused {
			y += ui_px(g, 2)
			bar_x := inner
			bar_w := ui_px(g, 100)
			rl.DrawRectangle(bar_x, y, bar_w, bar_h, theme.BAR_TRACK)
			ratio := g.scene.player.stamina / mods.stamina_max
			fill_w := i32(f32(bar_w) * ratio)
			if fill_w > 0 {
				fill_col := rl.GREEN
				if ratio < 0.33 {
					fill_col = rl.ORANGE
				}
				if g.scene.player.exhausted {
					if player.exhaust_flash_on() {
						fill_col = rl.RED
					} else {
						fill_col = theme.BAR_TRACK
					}
				}
				rl.DrawRectangle(bar_x, y, fill_w, bar_h, fill_col)
			} else if g.scene.player.exhausted && player.exhaust_flash_on() {
				rl.DrawRectangle(bar_x, y, bar_w, bar_h, rl.RED)
			}
		}
	rl.EndMode2D()
}

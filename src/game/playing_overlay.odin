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
	draw_nav_button(g, "Title")
	hint: cstring = "Saved — P to resume"
	font := ui_font(g, 10)
	hw := rl.MeasureText(hint, font)
	hx := (i32(g.view.game_size.x) - hw) / 2
	hy := i32(g.view.game_size.y) - font - ui_px(g, 28)
	rl.DrawText(hint, hx, hy, font, rl.GRAY)
	rl.EndMode2D()
}

@(private = "file")
playing_hud_row_width :: proc(font: i32, icon_size: f32, icon: UI_Row_Icon, text: cstring) -> f32 {
	layout_w := row_icon_layout_width(icon, icon_size)
	tw := rl.MeasureText(text, font)
	return layout_w + UI_ICON_TEXT_GAP + f32(tw)
}

@(private = "file")
draw_playing_stamina_bar :: proc(g: ^Game, mods: player.Player_Modifiers) {
	if g.run.paused {
		return
	}
	pad := ui_px(g, 4)
	bar_h := ui_px(g, 8)
	bar_w := f32(ui_px(g, 96))
	bar_x := f32(pad)
	bar_y := g.view.game_size.y - f32(pad) - f32(bar_h)
	bar_dest := rl.Rectangle{bar_x, bar_y, bar_w, f32(bar_h)}
	ratio := g.scene.player.stamina / mods.stamina_max
	fill_col := rl.WHITE
	if ratio < 0.33 {
		fill_col = rl.ORANGE
	}
	draw_ratio := ratio
	if g.scene.player.exhausted {
		if player.exhaust_flash_on() {
			fill_col = rl.RED
			draw_ratio = max(ratio, 0.15)
		} else {
			draw_ratio = 0
		}
	}
	ui_assets.draw_stamina_bar(bar_dest, draw_ratio, fill_col)
}

draw_playing_overlay :: proc(g: ^Game) {
	served := person.count_served(g.scene.people)
	available := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
	stat_font := ui_font(g, PLAYING_HUD_FONT_DESIGN)
	icon_size := f32(ui_px(g, PLAYING_HUD_ICON_DESIGN))
	pad := ui_px(g, 4)
	stat_line_step := max(stat_font, i32(icon_size)) + ui_px(g, 1)
	stat_lines: i32 = 4
	bonuses := person.party_bonuses(g.scene.people)
	served_label := fmt.ctprintf("%d / %d", served, g.run.person_count)
	fish_label := fmt.ctprintf("%d", available.fish_given)
	bread_label := fmt.ctprintf("%d", available.bread_given)
	coin_label := fmt.ctprintf("%d", g.run.coins)
	inner_w: f32 = 0
	inner_w = max(inner_w, playing_hud_row_width(stat_font, icon_size, .People, served_label))
	inner_w = max(inner_w, playing_hud_row_width(stat_font, icon_size, .Fish, fish_label))
	inner_w = max(inner_w, playing_hud_row_width(stat_font, icon_size, .Bread, bread_label))
	inner_w = max(inner_w, playing_hud_row_width(stat_font, icon_size, .Coin, coin_label))
	inner_w = max(inner_w, f32(ui_px(g, 72)))
	inner_h: f32 = f32(stat_lines * stat_line_step)
	panel_w := i32(ui_assets.wood_panel_width_for_inner(inner_w, 0))
	panel_h := i32(ui_assets.wood_panel_height_for_inner(inner_h, 0))
	mods := person.party_player_modifiers(bonuses)
	stats_y := pad
	rl.BeginMode2D(g.cameras.ui_camera)
		panel_dest := rl.Rectangle{f32(pad), f32(stats_y), f32(panel_w), f32(panel_h)}
		ui_assets.draw_wood_panel(panel_dest)
		content := ui_assets.wood_panel_content(panel_dest, 0)
		inner := i32(content.x)
		y: i32 = i32(content.y)
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.People,
			fmt.ctprintf("%d / %d", served, g.run.person_count),
			theme.TEXT_INK,
		)
		y += stat_line_step
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.Fish,
			fmt.ctprintf("%d", available.fish_given),
			theme.TEXT_INK,
		)
		y += stat_line_step
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.Bread,
			fmt.ctprintf("%d", available.bread_given),
			theme.TEXT_INK,
		)
		y += stat_line_step
		draw_icon_fn_text_row(
			inner,
			y,
			stat_font,
			icon_size,
			.Coin,
			fmt.ctprintf("%d", g.run.coins),
			theme.TEXT_INK,
		)
		y += stat_line_step
		draw_playing_stamina_bar(g, mods)
	rl.EndMode2D()
}

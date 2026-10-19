package game

import "core:fmt"
import rl "vendor:raylib"
import "../config"
import "../currency"
import "../input"
import ui_assets "../ui"
import "../person"
import "../player"
import "../theme"
import w "../world"

persist_run :: proc(g: ^Game) {
	save_game(
		g.persist.save_path,
		g.seed.value,
		g.run.person_count,
		g.run.served_bits,
		g.run.apostle_bits,
		g.run.run_stats,
		g.run.stats_pledged,
		g.run.coins,
	)
}

format_play_time :: proc(seconds: f32) -> cstring {
	total := int(seconds)
	if total < 0 {
		total = 0
	}
	mins := total / 60
	secs := total % 60
	return fmt.ctprintf("%02d:%02d", mins, secs)
}

update_playing :: proc(g: ^Game) {
	if input.key_pressed(.P) {
		g.run.paused = !g.run.paused
	}
	if g.run.paused {
		return
	}

	dt := rl.GetFrameTime()
	when config.IS_AUTOTEST {
		if g.autotest.autoplay {
			dt *= AUTOPLAY_SIM_SPEED
			autobot_tick(g)
		}
	}
	g.run.play_time += dt

	bonuses := person.party_bonuses(g.scene.people)
	mods := person.party_player_modifiers(bonuses)
	moved := player.update(g.scene.player, g.scene.ground, g.view.world_width, mods, dt)
	if moved > 0 {
		person.stat_add(&g.run.run_stats, .Distance_Walked, u32(moved))
	}

	update_camera(g)
	view := camera_view_rect(g)
	party_before := g.scene.people.party.count
	person.update_people(g.scene.people, view, g.frame, dt)
	when config.IS_DEBUG {
		g.scene.people.debug.apostle_perk_log = playing_debug_visible(g)
	}
	interact_radius := g.defs.interact_radius + bonuses.interact_radius_add
	perk_ctx := person.Apostle_Perk_Ctx {
		world = g.scene.level,
		player_pos = g.scene.player.pos,
		player_size = g.scene.player.size,
		player_facing = g.scene.player.facing,
		interact_radius = interact_radius,
		run_stats = &g.run.run_stats,
		coins = &g.run.coins,
	}
	person.update_apostle_follow(g.scene.people, perk_ctx, dt)
	currency.tick_drops(&g.run.dropped_coins, dt)
	if g.scene.people.party.count > party_before {
		person.sync_apostle_bits(g.scene.people, g.run.apostle_bits)
		persist_run(g)
		bonuses = person.party_bonuses(g.scene.people)
		mods = person.party_player_modifiers(bonuses)
		interact_radius = g.defs.interact_radius + bonuses.interact_radius_add
	}

	fish_down := input.key_down(.F)
	bread_down := input.key_down(.B)
	e_down := input.key_down(.E)
	g.input.interact_index = person.nearest_interact_index(
		g.scene.people,
		g.scene.player.pos,
		g.scene.player.size,
		interact_radius,
	)
	g.input.apostle_interact_index = person.nearest_apostle_interact_index(
		g.scene.people,
		g.scene.player.pos,
		g.scene.player.size,
		interact_radius,
	)

	if fish_down && !g.input.fish_was_down {
		if person.try_give_item(
			g.scene.people,
			g.scene.player.pos,
			g.scene.player.size,
			interact_radius,
			.Fish,
			&g.run.run_stats,
		) >= 0 {
			persist_run(g)
		}
	}
	if bread_down && !g.input.bread_was_down {
		if person.try_give_item(
			g.scene.people,
			g.scene.player.pos,
			g.scene.player.size,
			interact_radius,
			.Bread,
			&g.run.run_stats,
		) >= 0 {
			persist_run(g)
		}
	}
	g.input.fish_was_down = fish_down
	g.input.bread_was_down = bread_down
	if e_down && !g.input.e_was_down {
		player_rect := rl.Rectangle{g.scene.player.pos.x, g.scene.player.pos.y, g.scene.player.size.x, g.scene.player.size.y}
		if currency.try_pickup(&g.run.dropped_coins, player_rect, &g.run.coins) {
			persist_run(g)
		}
		available := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
		_, pledged := person.try_interact_apostle(
			g.scene.people,
			g.scene.player.pos,
			g.scene.player.size,
			interact_radius,
			available,
			&g.run.stats_pledged,
		)
		if pledged {
			persist_run(g)
		}
	}
	g.input.e_was_down = e_down

	when config.IS_DEBUG {
		if input.key_pressed(.M) {
			person.debug_serve_next(g.scene.people)
		}
		if input.key_pressed(.L) {
			person.debug_recruit_nearest_apostle(
				g.scene.people,
				g.scene.player.pos,
				g.scene.player.size,
				interact_radius,
			)
		}
		if playing_debug_visible(g) {
			person.apostle_debug_tick_input(g.scene.people)
		}
	}

	before := person.count_served(g.scene.people)
	person.sync_served_bits(g.scene.people, g.run.served_bits)
	after := person.count_served(g.scene.people)
	if after > before {
		persist_run(g)
	}
	if after >= g.run.person_count && g.run.person_count > 0 && person.sim_settled(g.scene.people) {
		begin_victory_march(g)
	}
}

when config.IS_DEBUG {
	playing_debug_visible :: proc(g: ^Game) -> bool {
		when config.IS_AUTOTEST {
			return g.autotest.autoplay || g.defs.debug
		}
		return g.defs.debug
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

draw_playing :: proc(g: ^Game) {
	view := camera_view_rect(g)

	rl.BeginMode2D(g.cameras.camera)
		if g.scene.bg != nil {
			draw_parallax_bg(g.scene.bg, g.cameras.camera.target.x, view)
		}
		if g.scene.ground != nil {
			rl.DrawRectangleV(g.scene.ground.pos, g.scene.ground.size, rl.BROWN)
		}
		person.draw_people(g.scene.people, view)
		person.draw_food_bubbles(g.scene.people, view)
		currency.draw_drops(&g.run.dropped_coins, view)
		avail := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
		person.draw_apostle_overlays(g.scene.people, view, g.scene.player.pos, g.scene.player.size, avail)
		person.draw_apostle_perk_bubbles(g.scene.people, view)
		if g.input.interact_index >= 0 {
			person.draw_person_outline(g.scene.people, g.input.interact_index, rl.RED)
		}
		if g.input.apostle_interact_index >= 0 {
			person.draw_person_outline(g.scene.people, g.input.apostle_interact_index, theme.DEBUG_CYAN)
		}
		player.draw(g.scene.player)
		when config.IS_DEBUG {
			if playing_debug_visible(g) && g.scene.level != nil {
				w.debug_draw_chunks(g.scene.level, g.scene.ground, ui_font(g, 8), g.cameras.camera.zoom)
			}
			if playing_debug_visible(g) && g.scene.people.debug.apostle_inspector_open {
				person.draw_apostle_debug_world_labels(g.scene.people, view, ui_font(g, 8))
			}
		}
	rl.EndMode2D()

	draw_playing_overlay(g)
	draw_pause_overlay(g)
	when config.IS_DEBUG {
		draw_playing_debug_overlay(g)
		debug_draw_camera(g)
	}
}

draw_pause_overlay :: proc(g: ^Game) {
	if !g.run.paused {
		return
	}

	body_font := ui_font(g, 14)
	resume_font := ui_font(g, 20)
	pause_icon_size := f32(ui_font(g, 48))
	section_gap := f32(ui_px(g, 16))
	line_gap := f32(ui_px(g, 8))

	timer_label := format_play_time(g.run.play_time)
	resume_label: cstring = "Press P to resume"

	body_icon := f32(body_font)
	resume_icon := f32(resume_font)

	block_h :=
		pause_icon_size +
		section_gap +
		f32(body_font) +
		line_gap +
		f32(resume_font)
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

	seed_font := ui_font(g, 10)
	seed_pad := ui_px(g, 8)
	seed_label := fmt.ctprintf("Seed: %d", g.seed.value)
	rl.DrawText(seed_label, seed_pad, i32(g.view.game_size.y) - seed_font - seed_pad, seed_font, rl.GRAY)
	rl.EndMode2D()
}

PLAYING_HUD_FONT_DESIGN :: 12
PLAYING_HUD_ICON_DESIGN :: 22
PLAYING_HUD_CONTROLS_FONT_DESIGN :: 8
PLAYING_HUD_SECTION_GAP_DESIGN :: 6

draw_playing_overlay :: proc(g: ^Game) {
	served := person.count_served(g.scene.people)
	available := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
	stat_font := ui_font(g, PLAYING_HUD_FONT_DESIGN)
	ctrl_font := ui_font(g, PLAYING_HUD_CONTROLS_FONT_DESIGN)
	icon_size := f32(ui_px(g, PLAYING_HUD_ICON_DESIGN))
	pad := ui_px(g, 4)
	inner := pad + ui_px(g, 4)
	stat_line_step := stat_font + ui_px(g, 2)
	ctrl_line_step := ctrl_font + ui_px(g, 1)
	panel_w := ui_px(g, 168)
	stat_lines := 5
	party_line := 0
	bonuses := person.party_bonuses(g.scene.people)
	if g.scene.people.party.count > 0 && person.party_bonus_hud_line(bonuses) != "" {
		party_line = 1
	}
	control_lines := 5
	section_gap := ui_px(g, PLAYING_HUD_SECTION_GAP_DESIGN)
	stats_panel_h := ui_px(g, 2) + i32(stat_lines) * stat_line_step + ui_px(g, 2)
	if party_line > 0 {
		stats_panel_h += stat_line_step
	}
	bar_h := ui_px(g, 5)
	controls_panel_h :=
		ui_px(g, 2) + i32(control_lines) * ctrl_line_step + ui_px(g, 2) + bar_h + ui_px(g, 2)
	stats_y := pad
	controls_y := stats_y + stats_panel_h + section_gap
	mods := person.party_player_modifiers(bonuses)
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
			.People,
			fmt.ctprintf("%d", available.total_served),
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
		if party_line > 0 {
			rl.DrawText(person.party_bonus_hud_line(bonuses), inner, y, stat_font, theme.PARTY_BONUS_GREEN)
		}

		rl.DrawRectangle(pad, controls_y, panel_w, controls_panel_h, theme.OVERLAY_SCRIM_180)
		y = controls_y + ui_px(g, 2)
		rl.DrawText("A / D  Walk", inner, y, ctrl_font, rl.LIGHTGRAY)
		y += ctrl_line_step
		rl.DrawText("Shift  Run", inner, y, ctrl_font, rl.LIGHTGRAY)
		y += ctrl_line_step
		rl.DrawText("F  Give fish", inner, y, ctrl_font, rl.LIGHTGRAY)
		y += ctrl_line_step
		rl.DrawText("B  Give bread", inner, y, ctrl_font, rl.LIGHTGRAY)
		y += ctrl_line_step
		rl.DrawText("E  Recruit apostle", inner, y, ctrl_font, rl.LIGHTGRAY)
		y += ctrl_line_step
		bar_x: i32 = inner
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
	rl.EndMode2D()
}

package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../config"
import "../input"
import "../person"
import "../player"
import "../theme"
import w "../world"

EPILOGUE_FINALE_TRIGGER_X :: 128.0
EPILOGUE_FINALE_WALK_STOP_X :: -12.0
EPILOGUE_FINALE_PAN_DELAY :: 3.0
EPILOGUE_FINALE_PAN_TIME :: 2.2
EPILOGUE_FINALE_TEXT :: "Well done, my good and faithful servant"
EPILOGUE_FINALE_TEXT_FADE_IN :: 5.0
EPILOGUE_FINALE_TEXT_HOLD :: 4.0
EPILOGUE_FINALE_TEXT_FADE_OUT :: 3.0

begin_post_game :: proc(g: ^Game) {
	persist_run(g)
	career_commit_run(g, true)
	epilogue_enter(g, false)
}

epilogue_enter :: proc(g: ^Game, restore: bool) {
	when config.IS_AUTOTEST {
		enter_credits(g, true)
		return
	}
	g.mode = .Post_Game
	g.input.interact_index = -1
	g.input.apostle_interact_index = -1
	g.run.paused = false

	if !restore {
		g.epilogue = {}
		delete(g.epilogue.celebrated)
		delete(g.epilogue.celebrate_delays)
		g.epilogue.sub = .Roam
		bit_len := person.celebrated_bit_bytes(g.run.person_count)
		g.epilogue.celebrated = make([]u8, bit_len)
		g.epilogue.celebrate_delays = person.epilogue_init_celebrate_delays(g.run.person_count)

		ground_y := g.scene.ground.top_y
		person.epilogue_layout(g.scene.people, g.scene.level, ground_y)
		person.epilogue_fill_apostle_rows(g.scene.people, &g.epilogue.apostle_rows)
		person.epilogue_place_player_spawn(g.scene.people, g.scene.level, g.scene.player)
		g.epilogue.roam_max_x = person.epilogue_roam_max_x(
			g.scene.people,
			g.scene.level,
			g.scene.player.size.x,
		)
		player.sync_bounds(g.scene.player)
		person.epilogue_face_player(g.scene.people, g.scene.player.pos.x + g.scene.player.size.x * 0.5)
	} else {
		if len(g.epilogue.celebrated) == 0 {
			bit_len := person.celebrated_bit_bytes(g.run.person_count)
			g.epilogue.celebrated = make([]u8, bit_len)
		}
		if len(g.epilogue.celebrate_delays) != g.run.person_count {
			delete(g.epilogue.celebrate_delays)
			g.epilogue.celebrate_delays = person.epilogue_init_celebrate_delays(g.run.person_count)
		}
		person.epilogue_layout(g.scene.people, g.scene.level, g.scene.ground.top_y)
		person.epilogue_fill_apostle_rows(g.scene.people, &g.epilogue.apostle_rows)
		if g.scene.player != nil {
			person.epilogue_face_player(
				g.scene.people,
				g.scene.player.pos.x + g.scene.player.size.x * 0.5,
			)
		}
	}

	if g.scene.player != nil && g.scene.people != nil && g.scene.level != nil {
		g.epilogue.roam_max_x = person.epilogue_roam_max_x(
			g.scene.people,
			g.scene.level,
			g.scene.player.size.x,
		)
	}

	switch g.epilogue.sub {
	case .Finale_Walk, .Finale_Wait:
		if !g.epilogue.finale_camera_locked {
			post_game_lock_finale_camera_x(g)
		}
		post_game_apply_finale_camera(g, 0)
	case .Finale_Pan:
		if !g.epilogue.finale_camera_locked {
			post_game_lock_finale_camera_x(g)
		}
		pan_t := math.clamp(g.epilogue.finale_pan_t / EPILOGUE_FINALE_PAN_TIME, 0, 1)
		post_game_apply_finale_camera(g, pan_t)
	case .Finale_Text:
		if !g.epilogue.finale_camera_locked {
			post_game_lock_finale_camera_x(g)
		}
		post_game_apply_finale_camera(g, 1)
	case .Roam:
	}

	persist_run(g)
}

update_post_game :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	g.run.play_time += dt

	switch g.epilogue.sub {
	case .Finale_Walk:
		update_post_game_finale_walk(g, dt)
	case .Finale_Wait:
		update_post_game_finale_wait(g, dt)
	case .Finale_Pan:
		update_post_game_finale_pan(g, dt)
	case .Finale_Text:
		update_post_game_finale_text(g, dt)
	case .Roam:
		update_post_game_roam(g, dt)
	}

}

update_post_game_roam :: proc(g: ^Game, dt: f32) {
	pl := g.scene.player
	if pl == nil || g.epilogue.player_locked {
		return
	}

	mods := player.player_modifiers_default()
	mods.ignore_stamina = true
	mods.sprint_mult = player.SPRINT_MULT * 2
	world_w := g.epilogue.roam_max_x + pl.size.x
	moved := player.update(pl, g.scene.ground, world_w, mods, dt)
	if pl.pos.x > g.epilogue.roam_max_x {
		pl.pos.x = g.epilogue.roam_max_x
		player.sync_bounds(pl)
	}
	if moved > 0 {
		person.stat_add(&g.run.run_stats, .Distance_Walked, u32(moved))
	}

	if pl.pos.x <= EPILOGUE_FINALE_TRIGGER_X {
		begin_post_game_finale_walk(g)
		return
	}

	cx := pl.pos.x + pl.size.x * 0.5
	person.epilogue_face_player(g.scene.people, cx)
	chunk := w.chunk_index_at_x(g.scene.level, cx)
	if chunk == person.EPILOGUE_CHUNK_CROWD && !g.epilogue.crowd_face_player {
		g.epilogue.crowd_face_player = true
		persist_run(g)
	}

	update_camera(g)
	view := camera_view_rect(g)
	person.epilogue_tick_celebrations(g.scene.people, view, g.frame, dt)

	pr := player.bounds_rect(pl)
	person.epilogue_tick_celebrate_delays(
		g.scene.people,
		g.epilogue.celebrated,
		g.epilogue.celebrate_delays,
		dt,
	)
	person.epilogue_queue_celebrate_touch(
		g.scene.people,
		g.epilogue.celebrated,
		g.epilogue.celebrate_delays,
		pr,
	)
	person.epilogue_update_apostle_dialogue(
		g.scene.people,
		&g.epilogue.apostle_rows,
		&g.epilogue.apostles,
		pr,
	)
}

begin_post_game_finale_walk :: proc(g: ^Game) {
	g.epilogue.sub = .Finale_Walk
	g.epilogue.player_locked = true
	post_game_lock_finale_camera_x(g)
	persist_run(g)
}

update_post_game_finale_walk :: proc(g: ^Game, dt: f32) {
	pl := g.scene.player
	if pl == nil {
		return
	}

	speed := pl.speed
	pl.pos.x -= speed * dt
	if pl.pos.x <= EPILOGUE_FINALE_WALK_STOP_X {
		pl.pos.x = EPILOGUE_FINALE_WALK_STOP_X
		player.sync_bounds(pl)
		begin_post_game_finale_wait(g)
		return
	}
	player.sync_bounds(pl)
	person.stat_add(&g.run.run_stats, .Distance_Walked, u32(speed * dt))

	cx := pl.pos.x + pl.size.x * 0.5
	person.epilogue_face_player(g.scene.people, cx)
	post_game_apply_finale_camera(g, 0)
}

begin_post_game_finale_wait :: proc(g: ^Game) {
	g.epilogue.sub = .Finale_Wait
	g.epilogue.player_locked = true
	g.epilogue.finale_wait_t = 0
	persist_run(g)
}

update_post_game_finale_wait :: proc(g: ^Game, dt: f32) {
	g.epilogue.finale_wait_t += dt
	post_game_apply_finale_camera(g, 0)
	if g.epilogue.finale_wait_t >= EPILOGUE_FINALE_PAN_DELAY {
		begin_post_game_finale_pan(g)
	}
}

begin_post_game_finale_pan :: proc(g: ^Game) {
	g.epilogue.sub = .Finale_Pan
	g.epilogue.player_locked = true
	g.epilogue.finale_pan_t = 0
	g.epilogue.finale_scrim = 0
	g.epilogue.finale_text_alpha = 0
	g.epilogue.finale_text_t = 0
	persist_run(g)
}

update_post_game_finale_pan :: proc(g: ^Game, dt: f32) {
	g.epilogue.finale_pan_t += dt
	t := math.clamp(g.epilogue.finale_pan_t / EPILOGUE_FINALE_PAN_TIME, 0, 1)
	g.epilogue.finale_scrim = t

	post_game_apply_finale_camera(g, t)

	if t >= 1 {
		g.epilogue.sub = .Finale_Text
		g.epilogue.finale_text_t = 0
		g.epilogue.finale_text_alpha = 0
		persist_run(g)
	}
}

epilogue_finale_text_alpha_at :: proc(t: f32) -> f32 {
	fade_in_end: f32 = EPILOGUE_FINALE_TEXT_FADE_IN
	hold_end := fade_in_end + EPILOGUE_FINALE_TEXT_HOLD
	fade_out_end := hold_end + EPILOGUE_FINALE_TEXT_FADE_OUT

	if t < fade_in_end {
		return math.clamp(t / EPILOGUE_FINALE_TEXT_FADE_IN, 0, 1)
	}
	if t < hold_end {
		return 1
	}
	if t < fade_out_end {
		return math.clamp(1 - (t - hold_end) / EPILOGUE_FINALE_TEXT_FADE_OUT, 0, 1)
	}
	return 0
}

finish_epilogue_to_title :: proc(g: ^Game) {
	if g.scene.people != nil {
		g.scene.people.epilogue_active = false
	}
	delete_run_save(g.persist.save_path)
	teardown_active_run(g)
	g.mode = .Title
}

update_post_game_finale_text :: proc(g: ^Game, dt: f32) {
	g.epilogue.finale_scrim = 1
	g.epilogue.finale_text_t += dt
	g.epilogue.finale_text_alpha = epilogue_finale_text_alpha_at(g.epilogue.finale_text_t)

	total: f32 =
		EPILOGUE_FINALE_TEXT_FADE_IN +
		EPILOGUE_FINALE_TEXT_HOLD +
		EPILOGUE_FINALE_TEXT_FADE_OUT
	if g.epilogue.finale_text_t >= total {
		finish_epilogue_to_title(g)
	}
}

draw_post_game :: proc(g: ^Game) {
	view := camera_view_rect(g)
	rl.BeginMode2D(g.cameras.camera)
		if g.scene.bg != nil {
			draw_parallax_bg(g.scene.bg, g.cameras.camera.target.x, view)
		}
		if g.scene.ground != nil {
			rl.DrawRectangleV(g.scene.ground.pos, g.scene.ground.size, rl.BROWN)
		}
		person.draw_people(g.scene.people, view)
		player.draw(g.scene.player)
		for a in 0 ..< person.APOSTLE_COUNT {
			i := g.epilogue.apostle_rows[a]
			if i < 0 || g.epilogue.apostles[a].speech_timer <= 0 {
				continue
			}
			line := person.epilogue_apostle_speech_text(a)
			person.draw_apostle_epilogue_speech_at(g.scene.people, i, line)
		}
	rl.EndMode2D()

	if g.epilogue.finale_scrim > 0 {
		alpha := u8(g.epilogue.finale_scrim * 255)
		rl.BeginMode2D(g.cameras.ui_camera)
			rl.DrawRectangle(
				0,
				0,
				i32(g.view.game_size.x),
				i32(g.view.game_size.y),
				{0, 0, 0, alpha},
			)
		rl.EndMode2D()
	}

	if g.epilogue.sub == .Finale_Text && g.epilogue.finale_text_alpha > 0 {
		font := ui_font(g, 22)
		rl.BeginMode2D(g.cameras.ui_camera)
			text := fmt.ctprintf("%s", EPILOGUE_FINALE_TEXT)
			tw := rl.MeasureText(text, font)
			x := (i32(g.view.game_size.x) - tw) / 2
			y := i32(g.view.game_size.y * 0.38)
			col := rl.Color{255, 255, 255, u8(g.epilogue.finale_text_alpha * 255)}
			rl.DrawText(text, x, y, font, col)
		rl.EndMode2D()
	} else if g.epilogue.sub == .Roam {
		rl.BeginMode2D(g.cameras.ui_camera)
			font := ui_font(g, 10)
			hint: cstring = "Walk left"
			w := rl.MeasureText(hint, font)
			x := (i32(g.view.game_size.x) - w) / 2
			y: i32 = i32(g.view.game_size.y) - font - ui_px(g, 12)
			rl.DrawText(hint, x, y, font, rl.GRAY)
		rl.EndMode2D()
	}

	when config.IS_DEBUG {
		draw_post_game_debug_overlay(g)
	}
}

when config.IS_DEBUG {
	draw_post_game_debug_overlay :: proc(g: ^Game) {
		if !playing_debug_visible(g) || g.epilogue.sub != .Roam {
			return
		}
		if g.scene.people == nil {
			return
		}
		remaining := person.epilogue_lineup_uncollided_count(
			g.scene.people,
			g.epilogue.celebrated,
		)
		label := fmt.ctprintf("Uncollided %d", remaining)
		font := ui_font(g, 10)
		pad := ui_px(g, 4)
		tw := rl.MeasureText(label, font)
		x := pad
		y := pad
		rl.BeginMode2D(g.cameras.ui_camera)
			rl.DrawRectangle(x - 2, y - 1, tw + 4, font + 2, theme.OVERLAY_SCRIM_160)
			rl.DrawText(label, x, y, font, theme.DEBUG_CYAN)
		rl.EndMode2D()
	}
}

when config.IS_DEBUG {
	debug_enter_post_game :: proc(g: ^Game) {
		begin_post_game(g)
	}

	// lineup_count 0 = full crowd lined up.
	debug_enter_epilogue_roam :: proc(g: ^Game, lineup_count: int) {
		start_run(g, false)
		if g.scene.people != nil {
			person.debug_mark_lineup_count(g.scene.people, lineup_count)
		}
		begin_post_game(g)
	}
}

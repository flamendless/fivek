package game

import "core:log"
import "core:strconv"
import "../config"
import "../person"
import "../player"
import w "../world"

teardown_active_run :: proc(g: ^Game) {
	if g.mode == .Playing && !g.career_committed {
		career_commit_run(g, false)
	}
	if g.scene.level != nil {
		w.free_world(g.scene.level)
		g.scene.level = nil
	}
	if g.scene.people != nil {
		if g.scene.people.epilogue_active {
			g.scene.people.epilogue_active = false
		}
		person.free_people(g.scene.people)
		g.scene.people = nil
	}
	if g.scene.ground != nil {
		free(g.scene.ground)
		g.scene.ground = nil
	}
	if g.scene.player != nil {
		free(g.scene.player)
		g.scene.player = nil
	}
	free_parallax_bg(g.scene.bg)
	g.scene.bg = nil
	delete(g.run.served_bits)
	g.run.served_bits = nil
	delete(g.run.apostle_bits)
	g.run.apostle_bits = nil
	delete(g.run.dropped_coins)
	g.run.dropped_coins = {}
	delete(g.epilogue.celebrated)
	delete(g.epilogue.celebrate_delays)
	g.epilogue = {}
	g.run.paused = false
}

end_run_to_title :: proc(g: ^Game) {
	if g.mode != .Playing && g.mode != .Post_Game {
		return
	}
	persist_run(g)
	if !g.career_committed {
		won := g.mode == .Post_Game
		if g.scene.people != nil {
			won = won || person.count_served(g.scene.people) >= g.run.person_count
		}
		career_commit_run(g, won)
	}
	teardown_active_run(g)
	g.mode = .Title
}

start_run :: proc(g: ^Game, continue_save: bool) {
	if g.mode == .Playing || g.mode == .Post_Game {
		teardown_active_run(g)
	} else {
		if g.scene.level != nil || g.scene.people != nil {
			teardown_active_run(g)
		}
	}

	seed := g.seed.value
	if g.seed.len > 0 {
		if v, ok := strconv.parse_u64(string(g.seed.text[:g.seed.len])); ok {
			seed = v
		}
	}
	g.seed.value = seed
	log.infof("starting run seed=%d continue_save=%v", seed, continue_save)

	if bg, ok := load_parallax_bg(g.seed.value, g.view.game_size.y); ok {
		g.scene.bg = bg
	}

	ground_y := g.view.game_size.y * 0.8
	wparams := w.World_Params{
		seed = seed,
		chunk_width = g.view.game_size.x,
		target_population = g.defs.target_population,
		pop_min = g.defs.chunk_pop_min,
		pop_max = g.defs.chunk_pop_max,
		ground_y = ground_y,
	}
	g.scene.level = w.generate_world(wparams)
	g.view.world_width = g.scene.level.width
	g.scene.ground = w.init_ground(g.view.world_width, g.view.game_size.y)
	g.scene.people = person.init_people(g.scene.level.spawn, g.view.game_size.x, ground_y)
	person.spawn_apostles(g.scene.people, g.seed.value, g.view.game_size.x, ground_y)
	g.run.run_stats = {}
	g.run.stats_pledged = {}
	g.run.coins = 0
	g.run.person_count = g.scene.people.crowd_count

	bit_len := served_bit_bytes(g.run.person_count)
	g.run.served_bits = make([]u8, bit_len)
	apostle_len := apostle_bit_bytes()
	g.run.apostle_bits = make([]u8, apostle_len)

	save_out: Run_Save_Out
	loaded := false
	if continue_save {
		loaded = load_save(
			g.persist.save_path,
			seed,
			g.run.person_count,
			g.run.served_bits,
			g.run.apostle_bits,
			&g.run.run_stats,
			&g.run.stats_pledged,
			&g.run.coins,
			&save_out,
		)
		person.apply_served_bits(g.scene.people, g.run.served_bits)
		person.apply_apostle_bits(g.scene.people, g.run.apostle_bits)
		person.sync_stats_pledged_floor(g.scene.people, g.run.apostle_bits, &g.run.stats_pledged)
	}
	if g.scene.people != nil {
		g.scene.people.run_stats = &g.run.run_stats
		g.scene.people.career_stats = &g.career
		g.scene.people.achievement_state = &g.ach_state
		g.scene.people.achievement_pending = &g.achievement_pending
		g.scene.people.coin_drops = &g.run.dropped_coins
	}

	if continue_save && loaded {
		g.career_committed = false
		g.run.play_time = save_out.play_time
	} else {
		career_on_run_start(g)
		g.run.play_time = 0
	}

	g.scene.player = player.init({PLAYER_START_X, 0}, g.defs.player_speed)
	sync_persist_chunk(g)

	g.frame = 0
	g.run.paused = false
	when config.IS_AUTOTEST {
		g.autotest.autobot_target = -1
		g.autotest.autoplay_done = false
		g.autotest.autoplay_failed = false
	} else {
		g.autotest.autoplay = false
		g.autotest.autoplay_done = false
		g.autotest.autoplay_failed = false
		g.autotest.autoplay_max_frames = 0
		g.autotest.autobot_target = -1
	}

	if continue_save && loaded {
		served := person.count_served(g.scene.people)
		if save_out.run_phase != .Playing {
			g.epilogue.crowd_face_player = save_out.epilogue_face
			switch save_out.epilogue_sub {
			case 0:
				g.epilogue.sub = .Roam
			case 1:
				g.epilogue.sub = .Finale_Pan
			case 2:
				g.epilogue.sub = .Finale_Text
			case 3:
				g.epilogue.sub = .Finale_Walk
			case 4:
				g.epilogue.sub = .Finale_Wait
			case:
				g.epilogue.sub = .Roam
			}
			if save_out.epilogue_sub >= 1 {
				g.epilogue.player_locked = true
				g.epilogue.finale_scrim = 1
				if save_out.epilogue_sub >= 2 {
					g.epilogue.finale_text_alpha = 1
				}
			}
			if save_out.epilogue_player_x > 0 {
				g.scene.player.pos.x = save_out.epilogue_player_x
				player.sync_bounds(g.scene.player)
			}
			g.career_committed = true
			epilogue_enter(g, true)
		} else if served >= g.run.person_count && g.run.person_count > 0 {
			g.career_committed = true
			epilogue_enter(g, false)
		} else {
			g.mode = .Playing
		}
	} else {
		g.mode = .Playing
	}
}

when config.IS_DEBUG {
	debug_reload_current_state :: proc(g: ^Game) {
		switch g.mode {
		case .Splash, .Disclaimer, .Title, .Stats, .Achievements, .Credits:
			reload_title_random(g)
		case .Tutorial:
			reload_title_random(g)
			enter_tutorial(g, g.tutorial.into_play)
		case .Playing, .Post_Game:
			mode := g.mode
			start_run(g, false)
			if mode == .Post_Game {
				begin_post_game(g)
			}
		}
	}
}

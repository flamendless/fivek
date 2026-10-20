package game

import "core:log"
import "core:strconv"
import "../config"
import "../person"
import "../player"
import w "../world"

start_run :: proc(g: ^Game, continue_save: bool) {
	if g.scene.level != nil {
		w.free_world(g.scene.level)
		g.scene.level = nil
	}
	if g.scene.people != nil {
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

	if continue_save {
		load_save(
			g.persist.save_path,
			seed,
			g.run.person_count,
			g.run.served_bits,
			g.run.apostle_bits,
			&g.run.run_stats,
			&g.run.stats_pledged,
			&g.run.coins,
		)
		person.apply_served_bits(g.scene.people, g.run.served_bits)
		person.apply_apostle_bits(g.scene.people, g.run.apostle_bits)
		person.sync_stats_pledged_floor(g.scene.people, g.run.apostle_bits, &g.run.stats_pledged)
	}
	if g.scene.people != nil {
		g.scene.people.run_stats = &g.run.run_stats
		g.scene.people.coin_drops = &g.run.dropped_coins
	}

	g.scene.player = player.init({PLAYER_START_X, 0}, g.defs.player_speed)
	sync_persist_chunk(g)

	g.mode = .Playing
	g.frame = 0
	g.run.play_time = 0
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
}

when config.IS_DEBUG {
	debug_reload_current_state :: proc(g: ^Game) {
		switch g.mode {
		case .Splash, .Disclaimer, .Title, .Credits:
			reload_title_random(g)
		case .Tutorial:
			reload_title_random(g)
			enter_tutorial(g, g.tutorial.into_play)
		case .Playing, .Victory_March, .Victory_Lineup:
			mode := g.mode
			start_run(g, false)
			#partial switch mode {
			case .Victory_March:
				begin_victory_march(g)
			case .Victory_Lineup:
				enter_victory_lineup_pause(g)
			}
		}
	}
}

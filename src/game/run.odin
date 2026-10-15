package game

import "core:strconv"
import rl "vendor:raylib"
import "../config"
import "../person"
import "../player"
import w "../world"

start_run :: proc(g: ^Game, continue_save: bool) {
	if g.level != nil {
		w.free_world(g.level)
		g.level = nil
	}
	if g.people != nil {
		person.free_people(g.people)
		g.people = nil
	}
	if g.ground != nil {
		free(g.ground)
		g.ground = nil
	}
	if g.player != nil {
		free(g.player)
		g.player = nil
	}
	free_parallax_bg(g.bg)
	g.bg = nil
	delete(g.served_bits)
	g.served_bits = nil

	seed := g.seed
	if g.seed_len > 0 {
		if v, ok := strconv.parse_u64(string(g.seed_text[:g.seed_len])); ok {
			seed = v
		}
	}
	g.seed = seed

	if bg, ok := load_parallax_bg(g.seed, g.game_size.y); ok {
		g.bg = bg
	}

	ground_y := g.game_size.y * 0.8
	wparams := w.World_Params{
		seed = seed,
		chunk_width = g.game_size.x,
		target_population = g.defs.target_population,
		pop_min = g.defs.chunk_pop_min,
		pop_max = g.defs.chunk_pop_max,
		ground_y = ground_y,
	}
	g.level = w.generate_world(wparams)
	g.world_width = g.level.width
	g.ground = w.init_ground(g.world_width, g.game_size.y)
	g.people = person.init_people(g.level.spawn, g.game_size.x, ground_y)
	g.person_count = len(g.people.rows)

	bit_len := served_bit_bytes(g.person_count)
	g.served_bits = make([]u8, bit_len)

	if continue_save {
		load_save(g.save_path, seed, g.person_count, g.served_bits)
		person.apply_served_bits(g.people, g.served_bits)
	}

	g.player = player.init({PLAYER_START_X, 0}, g.defs.player_speed)

	g.mode = .Playing
	g.frame = 0
	when config.IS_AUTOTEST {
		g.autobot_target = -1
		g.autoplay_done = false
		g.autoplay_failed = false
	} else {
		g.autoplay = false
		g.autoplay_done = false
		g.autoplay_failed = false
		g.autoplay_max_frames = 0
		g.autobot_target = -1
	}
}

when config.IS_DEBUG {
	debug_reload_new_seed :: proc(g: ^Game) {
		lo := u32(rl.GetRandomValue(0, 0x7fffffff))
		hi := u32(rl.GetRandomValue(0, 0x7fffffff))
		g.seed = (u64(hi) << 32) | u64(lo)
		if g.seed == 0 {
			g.seed = 1
		}
		g.seed_len = write_seed_text(g.seed, &g.seed_text)
		start_run(g, false)
	}
}

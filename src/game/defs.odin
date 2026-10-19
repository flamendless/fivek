package game

import "../config"

PLAYER_START_X :: 32.0
FIRST_CHUNK_SPAWN_PAD :: 16.0

INTERACT_RADIUS :: 48.0
WALK_SPEED :: 28.0
RUN_SPEED :: 56.0
OFFSCREEN_UPDATE_INTERVAL :: 4

CELEBRATE_HOP_MIN :: 2
CELEBRATE_HOP_MAX :: 5
CELEBRATE_HOP_HEIGHT :: 12.0
CELEBRATE_HOP_DURATION :: 0.12

SAVE_FILENAME :: "save_fivek.bin"
INTRO_PREFS_FILENAME :: "intro_seen.bin"
GAME_DISPLAY_TITLE :: "Bread, Fish, Repeat 5000x"

Game_Defs :: struct {
	debug: bool,
	game_size_same: bool,
	title: string,
	version: string,
	target_population: int,
	chunk_pop_min: int,
	chunk_pop_max: int,
	player_speed: f32,
	interact_radius: f32,
}

get_defs :: proc() -> Game_Defs {
	return Game_Defs{
		debug = config.IS_DEBUG,
		game_size_same = config.IS_GAME_SIZE_SAME,
		title = GAME_DISPLAY_TITLE,
		version = config.VERSION,
		target_population = config.TARGET_POPULATION,
		chunk_pop_min = config.CHUNK_POP_MIN,
		chunk_pop_max = config.CHUNK_POP_MAX,
		player_speed = 64,
		interact_radius = INTERACT_RADIUS,
	}
}

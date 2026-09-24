package game

IS_DEBUG :: #config(DEBUG, false)
IS_GAME_SIZE_SAME :: #config(GAME_SIZE_SAME, true)
GRAVITY :: #config(GRAVITY, 256.0)

Game_Defs :: struct {
	debug: bool,
	game_size_same: bool,
	gravity: f32,
	title: string,
}

get_defs :: proc() -> Game_Defs {
	defs := Game_Defs{
		debug = IS_DEBUG,
		game_size_same = IS_GAME_SIZE_SAME,
		gravity = GRAVITY,
		title = "FiveK",
	}
	return defs
}

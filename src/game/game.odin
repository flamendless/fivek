package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../config"
import "../input"
import "../food"
import "../person"
import "../player"
import w "../world"

Game_Mode :: enum {
	Splash,
	Disclaimer,
	Title,
	Playing,
	Victory_March,
	Victory_Lineup,
	Credits,
}

Game :: struct {
	defs: Game_Defs,
	mode: Game_Mode,
	frame: int,

	window_size: rl.Vector2,
	game_size: rl.Vector2,
	scale: f32,
	ui_scale: f32,
	world_width: f32,

	seed: u64,
	seed_text: [32]u8,
	seed_len: int,

	level: ^w.World,
	ground: ^w.Ground,
	people: ^person.People,
	player: ^player.Player,

	served_bits: []u8,
	apostle_bits: []u8,
	person_count: int,

	camera: rl.Camera2D,
	ui_camera: rl.Camera2D,

	fish_was_down: bool,
	bread_was_down: bool,
	interact_index: int,
	apostle_interact_index: int,
	e_was_down: bool,

	autoplay: bool,
	autoplay_done: bool,
	autoplay_failed: bool,
	autoplay_max_frames: int,
	autobot_target: int,
	save_path: string,

	bg: ^Parallax_BG,

	splash_logo: rl.Texture2D,
	intro_seen: bool,
	splash_elapsed: f32,
	disclaimer_elapsed: f32,
}

init :: proc(defs := Game_Defs{}) -> ^Game {
	g := new(Game)
	g.defs = defs
	g.mode = .Splash
	g.intro_seen = load_intro_seen()
	g.window_size = {
		f32(config.GAME_VIEW_WIDTH),
		f32(config.GAME_VIEW_HEIGHT),
	}
	when config.IS_GAME_SIZE_SAME {
		g.game_size = g.window_size
	} else {
		g.game_size = {480, 270}
	}
	g.ui_scale = g.game_size.y / f32(config.UI_DESIGN_HEIGHT)
	g.scale = math.min(
		g.window_size.x / g.game_size.x,
		g.window_size.y / g.game_size.y,
	)

	g.seed = 12345
	g.seed_len = write_seed_text(g.seed, &g.seed_text)
	g.camera = init_game_camera(g.window_size, g.scale * config.GAME_WORLD_ZOOM)
	g.ui_camera = init_ui_camera(g.scale)
	g.save_path = SAVE_FILENAME

	return g
}

write_seed_text :: proc(seed: u64, buf: ^[32]u8) -> int {
	s := fmt.bprintf(buf[:], "%d", seed)
	return len(s)
}

loop :: proc(g: ^Game) {
	for !rl.WindowShouldClose() {
		update(g)
		draw(g)
		g.frame += 1
		free_all(context.temp_allocator)
	}
}

update :: proc(g: ^Game) {
	when config.IS_AUTOTEST {
		if !g.autoplay {
			input.begin_frame()
		}
	} else {
		input.begin_frame()
	}
	when config.IS_DEBUG {
		if rl.IsKeyPressed(.R) {
			debug_reload_new_seed(g)
			return
		}
	}
	switch g.mode {
	case .Splash:
		update_splash(g)
	case .Disclaimer:
		update_disclaimer(g)
	case .Title:
		update_title(g)
	case .Playing:
		update_playing(g)
	case .Victory_March:
		update_victory_march(g)
	case .Victory_Lineup:
		update_victory_lineup(g)
	case .Credits:
		update_credits(g)
	}
}

draw :: proc(g: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch g.mode {
	case .Splash:
		draw_splash(g)
	case .Disclaimer:
		draw_disclaimer(g)
	case .Title:
		draw_title(g)
	case .Playing:
		draw_playing(g)
	case .Victory_March:
		draw_playing(g)
	case .Victory_Lineup:
		draw_playing(g)
		draw_victory_lineup_hint(g)
	case .Credits:
		draw_credits(g)
	}

	rl.EndDrawing()
}

close :: proc(g: ^Game) {
	w.free_world(g.level)
	person.free_people(g.people)
	free(g.ground)
	free(g.player)
	free_parallax_bg(g.bg)
	unload_intro_assets(g)
	food.unload()
	delete(g.served_bits)
	delete(g.apostle_bits)
	free(g)
}

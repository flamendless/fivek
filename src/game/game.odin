package game

import "core:fmt"
import "core:log"
import "core:math"
import rl "vendor:raylib"
import "../config"
import "../currency"
import "../input"
import "../food"
import "../person"
import "../player"
import w "../world"

Game_Mode :: enum {
	Splash,
	Disclaimer,
	Title,
	Tutorial,
	Playing,
	Victory_March,
	Victory_Lineup,
	Credits,
}

Game_View :: struct {
	window_size: rl.Vector2,
	game_size:   rl.Vector2,
	scale:       f32,
	ui_scale:    f32,
	world_width: f32,
}

Game_Seed :: struct {
	value: u64,
	text:  [32]u8,
	len:   int,
}

Game_Scene :: struct {
	level:  ^w.World,
	ground: ^w.Ground,
	people: ^person.People,
	player: ^player.Player,
	bg:     ^Parallax_BG,
}

Game_Run :: struct {
	served_bits:    []u8,
	apostle_bits:   []u8,
	person_count:   int,
	run_stats:      person.Run_Stats,
	stats_pledged:  person.Run_Stats,
	coins:          u32,
	dropped_coins:  [dynamic]currency.Dropped_Coin,
	play_time:      f32,
	paused:         bool,
}

Game_Cameras :: struct {
	camera:    rl.Camera2D,
	ui_camera: rl.Camera2D,
}

Game_Input :: struct {
	fish_was_down:            bool,
	bread_was_down:           bool,
	interact_index:           int,
	apostle_interact_index:   int,
	e_was_down:               bool,
}

Game_Prefs :: struct {
	intro_seen:    bool,
	tutorial_seen: bool,
}

Game_Autotest :: struct {
	autoplay:            bool,
	autoplay_done:       bool,
	autoplay_failed:     bool,
	autoplay_max_frames: int,
	autobot_target:      int,
}

Game_Persist :: struct {
	save_path: string,
}

Game :: struct {
	defs:  Game_Defs,
	mode:  Game_Mode,
	frame: int,

	view:     Game_View,
	seed:     Game_Seed,
	scene:    Game_Scene,
	run:      Game_Run,
	cameras:  Game_Cameras,
	input:      Game_Input,
	prefs:      Game_Prefs,
	splash:     Game_Splash,
	disclaimer: Game_Disclaimer,
	tutorial:   Game_Tutorial,
	title:      Game_Title,
	autotest:   Game_Autotest,
	persist:  Game_Persist,
}

init :: proc(defs := Game_Defs{}) -> ^Game {
	log.infof("initializing game (population target %d)", defs.target_population)
	g := new(Game)
	g.defs = defs
	g.mode = .Splash
	g.prefs.intro_seen = load_intro_seen()
	g.prefs.tutorial_seen = load_tutorial_seen()
	g.title.hovered_menu = -1
	g.title.hovered_social = -1
	g.view.window_size = {
		f32(config.GAME_VIEW_WIDTH),
		f32(config.GAME_VIEW_HEIGHT),
	}
	when config.IS_GAME_SIZE_SAME {
		g.view.game_size = g.view.window_size
	} else {
		g.view.game_size = {480, 270}
	}
	g.view.ui_scale = g.view.game_size.y / f32(config.UI_DESIGN_HEIGHT)
	g.view.scale = math.min(
		g.view.window_size.x / g.view.game_size.x,
		g.view.window_size.y / g.view.game_size.y,
	)

	g.seed.value = 12345
	g.seed.len = write_seed_text(g.seed.value, &g.seed.text)
	g.cameras.camera = init_game_camera(g.view.window_size, g.view.scale * config.GAME_WORLD_ZOOM)
	g.cameras.ui_camera = init_ui_camera(g.view.scale)
	g.persist.save_path = SAVE_FILENAME

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
		if !g.autotest.autoplay {
			input.begin_frame()
		}
	} else {
		input.begin_frame()
	}
	when config.IS_DEBUG {
		if rl.IsKeyPressed(.R) {
			debug_reload_current_state(g)
			return
		}
	}
	if g.mode == .Title {
		title_fx_on_enter(g)
	} else {
		title_fx_on_leave(g)
	}
	switch g.mode {
	case .Splash:
		update_splash(g)
	case .Disclaimer:
		update_disclaimer(g)
	case .Title:
		update_title(g)
	case .Tutorial:
		update_tutorial(g)
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
	case .Tutorial:
		draw_tutorial(g)
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
	log.info("closing game")
	w.free_world(g.scene.level)
	person.free_people(g.scene.people)
	free(g.scene.ground)
	free(g.scene.player)
	free_parallax_bg(g.scene.bg)
	unload_splash_assets(g)
	unload_title_assets(g)
	food.unload()
	delete(g.run.served_bits)
	delete(g.run.apostle_bits)
	free(g)
}

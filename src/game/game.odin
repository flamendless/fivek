package game

import "core:fmt"
import "core:log"
import "core:math"
import rl "vendor:raylib"
import "../achievements"
import "../assets"
import "../config"
import "../currency"
import "../input"
import "../person"
import "../player"
import w "../world"

Game_Mode :: enum {
	Splash,
	Disclaimer,
	Title,
	Stats,
	Achievements,
	Tutorial,
	Playing,
	Post_Game,
	Credits,
}

Epilogue_Sub :: enum u8 {
	Roam         = 0,
	Finale_Pan   = 1,
	Finale_Text  = 2,
	Finale_Walk  = 3,
	Finale_Wait  = 4,
}

Game_Epilogue :: struct {
	sub:               Epilogue_Sub,
	crowd_face_player: bool,
	apostles:          [person.APOSTLE_COUNT]person.Crowd_Apostle_Play,
	apostle_rows:      [person.APOSTLE_COUNT]int,
	celebrated:        []u8,
	celebrate_delays:  []f32,
	roam_max_x:        f32,
	finale_scrim:      f32,
	finale_text_alpha: f32,
	finale_text_t:       f32,
	finale_pan_t:        f32,
	finale_wait_t:       f32,
	finale_camera_x:     f32,
	finale_camera_locked: bool,
	player_locked:       bool,
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
	persist_chunk:  int,
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
	ui:       Game_UI,
	seed:     Game_Seed,
	scene:    Game_Scene,
	run:      Game_Run,
	cameras:  Game_Cameras,
	input:      Game_Input,
	prefs:      Game_Prefs,
	splash:     Game_Splash,
	disclaimer: Game_Disclaimer,
	tutorial:   Game_Tutorial,
	credits:    Game_Credits,
	title:      Game_Title,
	autotest:   Game_Autotest,
	persist:    Game_Persist,
	career:               person.Career_Stats,
	career_committed:     bool,
	ach_state:            achievements.State,
	achievement_pending:  [dynamic]achievements.Id,
	achievement_toasts:   Achievement_Toast_Stack,
	epilogue:             Game_Epilogue,
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
	g.title.hovered_settings = -1
	g.credits.hovered_asset = -1
	g.credits.hovered_apostle = -1
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
	g.career = load_career_stats()
	g.ach_state = load_achievements()
	game_sync_achievements(g)

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
	title_like := g.mode == .Title
	if title_like {
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
	case .Stats:
		update_stats(g)
	case .Achievements:
		update_achievements(g)
	case .Tutorial:
		update_tutorial(g)
	case .Playing:
		update_playing(g)
	case .Post_Game:
		update_post_game(g)
	case .Credits:
		update_credits(g)
	}

	if pattern_screen_mode(g.mode) && g.mode != pattern_screen_last_mode {
		refresh_title_pattern(g)
	}
	pattern_screen_last_mode = g.mode

	dt := rl.GetFrameTime()
	if len(g.achievement_pending) > 0 {
		save_achievements(&g.ach_state)
	}
	update_achievement_toasts(g, dt)
}

@(private = "file")
pattern_screen_last_mode: Game_Mode = .Splash

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
	case .Stats:
		draw_stats(g)
	case .Achievements:
		draw_achievements(g)
	case .Tutorial:
		draw_tutorial(g)
	case .Playing:
		draw_playing(g)
	case .Post_Game:
		draw_post_game(g)
	case .Credits:
		draw_credits(g)
	}

	rl.BeginMode2D(g.cameras.ui_camera)
	when config.IS_DEBUG {
		draw_debug_fps(g)
		draw_dev_version_badge(g)
	}
	draw_bread_pointer(g)
	draw_achievement_toasts(g)
	rl.EndMode2D()

	rl.EndDrawing()
}

close :: proc(g: ^Game) {
	log.info("closing game")
	if (g.mode == .Playing || g.mode == .Post_Game) && !g.career_committed {
		persist_run(g)
		career_commit_run(g, false)
	} else if g.mode == .Playing || g.mode == .Post_Game {
		persist_run(g)
	}
	delete(g.epilogue.celebrated)
	delete(g.epilogue.celebrate_delays)
	credits_free_crowd(g)
	tutorial_free_scene(g)
	w.free_world(g.scene.level)
	person.free_people(g.scene.people)
	free(g.scene.ground)
	free(g.scene.player)
	free_parallax_bg(g.scene.bg)
	unload_title_assets(g)
	assets.unload_gameplay()
	assets.unload_boot()
	assets.cache_log_remaining()
	delete(g.run.served_bits)
	delete(g.run.apostle_bits)
	delete(g.achievement_pending)
	delete(g.achievement_toasts.entries)
	free(g)
}

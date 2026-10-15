package game

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"
import "../config"
import "../input"
import "../person"
import "../player"
import w "../world"

Game_Mode :: enum {
	Title,
	Playing,
	Victory_March,
	Victory_Lineup,
	Credits,
}

VICTORY_MARCH_DEADBAND :: 3.0

Game :: struct {
	defs: Game_Defs,
	mode: Game_Mode,
	frame: int,

	window_size: rl.Vector2,
	game_size: rl.Vector2,
	scale: f32,
	world_width: f32,

	seed: u64,
	seed_text: [32]u8,
	seed_len: int,

	level: ^w.World,
	ground: ^w.Ground,
	people: ^person.People,
	player: ^player.Player,

	served_bits: []u8,
	person_count: int,

	camera: rl.Camera2D,
	ui_camera: rl.Camera2D,

	fish_was_down: bool,
	bread_was_down: bool,
	interact_index: int,

	autoplay: bool,
	autoplay_done: bool,
	autoplay_failed: bool,
	autoplay_max_frames: int,
	autobot_target: int,
	save_path: string,
}

init :: proc(defs := Game_Defs{}) -> ^Game {
	g := new(Game)
	g.defs = defs
	g.mode = .Title
	g.window_size = {640, 480}
	when config.IS_GAME_SIZE_SAME {
		g.game_size = g.window_size
	} else {
		g.game_size = {360, 240}
	}
	g.scale = math.min(
		g.window_size.x / g.game_size.x,
		g.window_size.y / g.game_size.y,
	)

	g.seed = 12345
	g.seed_len = write_seed_text(g.seed, &g.seed_text)
	g.camera = init_game_camera(g.game_size, g.scale)
	g.ui_camera = init_ui_camera(g.scale)
	g.save_path = SAVE_FILENAME

	return g
}

write_seed_text :: proc(seed: u64, buf: ^[32]u8) -> int {
	s := fmt.bprintf(buf[:], "%d", seed)
	return len(s)
}

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
	delete(g.served_bits)
	g.served_bits = nil

	seed := g.seed
	if g.seed_len > 0 {
		if v, ok := strconv.parse_u64(string(g.seed_text[:g.seed_len])); ok {
			seed = v
		}
	}
	g.seed = seed

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

init_window :: proc(g: ^Game) {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(
		auto_cast g.window_size.x,
		auto_cast g.window_size.y,
		strings.clone_to_cstring(g.defs.title),
	)

	monitor_id := rl.GetCurrentMonitor()
	monitor_w := rl.GetMonitorWidth(monitor_id)
	monitor_h := rl.GetMonitorHeight(monitor_id)

	rl.SetWindowPosition(
		(monitor_w / 2) - (auto_cast g.window_size.x / 2),
		(monitor_h / 2) - (auto_cast g.window_size.y / 2),
	)

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)
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
	switch g.mode {
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

update_title :: proc(g: ^Game) {
	for i in 0 ..< 10 {
		if rl.IsKeyPressed(rl.KeyboardKey.ZERO + rl.KeyboardKey(i)) {
			append_seed_digit(g, u8('0' + i))
		}
	}
	if rl.IsKeyPressed(.BACKSPACE) && g.seed_len > 0 {
		g.seed_len -= 1
	}
	if rl.IsKeyPressed(.ENTER) {
		start_run(g, false)
	}
	if rl.IsKeyPressed(.C) {
		start_run(g, true)
	}
}

append_seed_digit :: proc(g: ^Game, ch: u8) {
	if g.seed_len >= len(g.seed_text) - 1 {
		return
	}
	g.seed_text[g.seed_len] = ch
	g.seed_len += 1
}

update_playing :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	when config.IS_AUTOTEST {
		if g.autoplay {
			dt *= AUTOPLAY_SIM_SPEED
			autobot_tick(g)
		}
	}

	player.update(g.player, g.ground, g.world_width, dt)

	view := camera_view_rect(g)
	update_camera(g)
	person.update_people(g.people, view, g.frame, dt)

	fish_down := input.key_down(.F)
	bread_down := input.key_down(.B)
	g.interact_index = person.nearest_interact_index(
		g.people,
		g.player.pos,
		g.player.size,
		g.defs.interact_radius,
	)

	if fish_down && !g.fish_was_down {
		person.try_give_item(
			g.people,
			g.player.pos,
			g.player.size,
			g.defs.interact_radius,
			.Fish,
		)
	}
	if bread_down && !g.bread_was_down {
		person.try_give_item(
			g.people,
			g.player.pos,
			g.player.size,
			g.defs.interact_radius,
			.Bread,
		)
	}
	g.fish_was_down = fish_down
	g.bread_was_down = bread_down

	before := person.count_served(g.people)
	person.sync_served_bits(g.people, g.served_bits)
	after := person.count_served(g.people)
	if after > before {
		save_game(g.save_path, g.seed, g.person_count, g.served_bits)
	}
	if after >= g.person_count && g.person_count > 0 && person.sim_settled(g.people) {
		begin_victory_march(g)
	}
}

begin_victory_march :: proc(g: ^Game) {
	g.mode = .Victory_March
	g.interact_index = -1

	when config.IS_AUTOTEST {
		g.autoplay = false
		g.autobot_target = -1
		g.autoplay_done = true
		g.autoplay_max_frames = 0
	}
}

enter_victory_lineup_pause :: proc(g: ^Game) {
	g.mode = .Victory_Lineup

	g.player.pos.x = PLAYER_START_X
	g.player.pos.y = g.ground.top_y - g.player.size.y
	player.sync_bounds(g.player)

	chunk_center := g.game_size.x * 0.5
	half_w := g.game_size.x * 0.5
	g.camera.target.x = math.clamp(chunk_center, half_w, g.world_width - half_w)
	g.camera.target.y = camera_world_height_y(g.game_size)
}

update_victory_march :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	target_x: f32 = PLAYER_START_X
	speed := g.defs.player_speed

	if g.player.pos.x < target_x - VICTORY_MARCH_DEADBAND {
		g.player.pos.x += speed * dt
		if g.player.pos.x > target_x {
			g.player.pos.x = target_x
		}
	} else if g.player.pos.x > target_x + VICTORY_MARCH_DEADBAND {
		g.player.pos.x -= speed * dt
		if g.player.pos.x < target_x {
			g.player.pos.x = target_x
		}
	} else {
		enter_victory_lineup_pause(g)
		return
	}

	g.player.pos.x = math.clamp(g.player.pos.x, 0, g.world_width - g.player.size.x)
	g.player.pos.y = g.ground.top_y - g.player.size.y
	player.sync_bounds(g.player)
	update_camera(g)
}

update_victory_lineup :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		g.mode = .Credits
	}
	if rl.IsKeyPressed(.ESCAPE) {
		rl.CloseWindow()
	}
}

update_credits :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ESCAPE) {
		g.mode = .Title
	}
}

draw :: proc(g: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch g.mode {
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

draw_title :: proc(g: ^Game) {
	rl.BeginMode2D(g.ui_camera)
		rl.DrawText(fmt.ctprintf("%s", g.defs.title), 20, 40, 20, rl.WHITE)
		rl.DrawText("Seed:", 20, 80, 16, rl.GRAY)
		rl.DrawText(fmt.ctprintf("%.*s", g.seed_len, &g.seed_text[0]), 80, 80, 16, rl.WHITE)
		rl.DrawText("Enter - New game", 20, 120, 16, rl.LIGHTGRAY)
		rl.DrawText("C - Continue (save)", 20, 140, 16, rl.LIGHTGRAY)
		rl.DrawText("0-9 type seed", 20, 160, 16, rl.LIGHTGRAY)

		ver_font: i32 = 12
		ver := fmt.ctprintf("build: v%s", g.defs.version)
		ver_w := rl.MeasureText(ver, ver_font)
		ver_pad: i32 = 8
		ver_x := i32(g.game_size.x) - ver_w - ver_pad
		ver_y := i32(g.game_size.y) - ver_font - ver_pad
		rl.DrawText(ver, ver_x, ver_y, ver_font, rl.GRAY)
	rl.EndMode2D()
}

when config.IS_DEBUG {
	playing_debug_visible :: proc(g: ^Game) -> bool {
		when config.IS_AUTOTEST {
			return g.autoplay || g.defs.debug
		}
		return g.defs.debug
	}

	draw_playing_debug_overlay :: proc(g: ^Game) {
		if !playing_debug_visible(g) {
			return
		}
		speed: f32 = 1.0
		when config.IS_AUTOTEST {
			if g.autoplay {
				speed = AUTOPLAY_SIM_SPEED
			}
		}
		label := fmt.ctprintf("Speed %.1fx", speed)
		FONT :: 8
		PAD :: 4
		w := rl.MeasureText(label, FONT)
		x := i32(g.game_size.x) - w - PAD
		y: i32 = PAD
		rl.BeginMode2D(g.ui_camera)
			rl.DrawRectangle(x - 2, y - 1, w + 4, FONT + 2, {0, 0, 0, 160})
			rl.DrawText(label, x, y, FONT, rl.YELLOW)
		rl.EndMode2D()
	}
}

draw_playing :: proc(g: ^Game) {
	view := camera_view_rect(g)

	rl.BeginMode2D(g.camera)
		rl.DrawRectangleV(g.ground.pos, g.ground.size, rl.BROWN)
		person.draw_people(g.people, view)
		if g.interact_index >= 0 {
			person.draw_person_outline(g.people, g.interact_index, rl.RED)
		}
		player.draw(g.player)
		when config.IS_DEBUG {
			if playing_debug_visible(g) && g.level != nil {
				w.debug_draw_chunks(g.level, g.ground)
			}
		}
	rl.EndMode2D()

	draw_playing_overlay(g)
	when config.IS_DEBUG {
		draw_playing_debug_overlay(g)
		debug_draw_camera(g)
	}
}

draw_playing_overlay :: proc(g: ^Game) {
	served := person.count_served(g.people)
	rl.BeginMode2D(g.ui_camera)
		FONT :: 8
		PAD :: 4
		panel_w: i32 = 148
		panel_h: i32 = 92
		rl.DrawRectangle(PAD, PAD, panel_w, panel_h, {0, 0, 0, 180})
		y: i32 = PAD + 2
		rl.DrawText(fmt.ctprintf("Served %d / %d", served, g.person_count), PAD + 4, y, FONT, rl.WHITE)
		y += FONT + 2
		rl.DrawText("A / D  Walk", PAD + 4, y, FONT, rl.LIGHTGRAY)
		y += FONT + 1
		rl.DrawText("Shift  Run", PAD + 4, y, FONT, rl.LIGHTGRAY)
		y += FONT + 1
		rl.DrawText("F  Give fish", PAD + 4, y, FONT, rl.LIGHTGRAY)
		y += FONT + 1
		rl.DrawText("B  Give bread", PAD + 4, y, FONT, rl.LIGHTGRAY)
		y += FONT + 2
		bar_x: i32 = PAD + 4
		bar_w: i32 = 100
		bar_h: i32 = 5
		rl.DrawRectangle(bar_x, y, bar_w, bar_h, {40, 40, 40, 200})
		ratio := g.player.stamina / player.STAMINA_MAX
		fill_w := i32(f32(bar_w) * ratio)
		if fill_w > 0 {
			fill_col := rl.GREEN
			if ratio < 0.33 {
				fill_col = rl.ORANGE
			}
			if g.player.exhausted {
				if player.exhaust_flash_on() {
					fill_col = rl.RED
				} else {
					fill_col = {40, 40, 40, 200}
				}
			}
			rl.DrawRectangle(bar_x, y, fill_w, bar_h, fill_col)
		} else if g.player.exhausted && player.exhaust_flash_on() {
			rl.DrawRectangle(bar_x, y, bar_w, bar_h, rl.RED)
		}
		y += bar_h + 2
		rl.DrawText(fmt.ctprintf("FPS %d", rl.GetFPS()), PAD + 4, y, FONT, rl.GRAY)
	rl.EndMode2D()
}

draw_victory_lineup_hint :: proc(g: ^Game) {
	rl.BeginMode2D(g.ui_camera)
		FONT :: 10
		msg := fmt.ctprintf("All fed. Enter - Continue")
		w := rl.MeasureText(msg, FONT)
		x := (i32(g.game_size.x) - w) / 2
		y: i32 = i32(g.game_size.y) - FONT - 12
		rl.DrawRectangle(x - 4, y - 2, w + 8, FONT + 4, {0, 0, 0, 180})
		rl.DrawText(msg, x, y, FONT, rl.WHITE)
	rl.EndMode2D()
}

draw_credits :: proc(g: ^Game) {
	rl.BeginMode2D(g.ui_camera)
		rl.DrawText("All fed. Thank you.", 40, 80, 20, rl.WHITE)
		rl.DrawText("Five thousand plus", 40, 110, 16, rl.LIGHTGRAY)
		rl.DrawText("fish and bread.", 40, 130, 16, rl.LIGHTGRAY)
		rl.DrawText("Enter - Title", 40, 180, 16, rl.GRAY)
	rl.EndMode2D()
}

close :: proc(g: ^Game) {
	w.free_world(g.level)
	person.free_people(g.people)
	free(g.ground)
	free(g.player)
	delete(g.served_bits)
	free(g)
}

close_window :: proc() {
	rl.CloseWindow()
}

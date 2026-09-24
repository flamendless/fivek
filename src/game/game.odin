package game

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
import "../player"
import "../world"

Game :: struct {
	defs: Game_Defs,
	window_size: rl.Vector2,
	game_size: rl.Vector2,
	scale: f32,

	ground: ^world.Ground,
	player: ^player.Player,
	camera: ^rl.Camera2D,
	ui_camera: ^rl.Camera2D,
}

init :: proc(defs := Game_Defs{}) -> ^Game {
	g := new(Game)
	g.defs = defs
	g.window_size = {640, 480}
	when IS_GAME_SIZE_SAME {
		g.game_size = g.window_size
		g.scale = 1
	} else {
		g.game_size = {360, 240}
		g.scale = math.min(
			g.window_size.x/g.game_size.x,
			g.window_size.y/g.game_size.y,
		)
	}

	g.ground = world.init_ground(g.game_size)

	//TODO: move to scene/state load
	g.player = player.init({
		auto_cast g.game_size.x/2,
		auto_cast g.game_size.y/2,
	}, defs.gravity)

	g.camera = get_game_camera(g.player.pos, g.window_size, g.scale)
	g.ui_camera = get_ui_camera(g.scale)

	return g
}

init_window :: proc(g: ^Game) {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(auto_cast g.window_size.x, auto_cast g.window_size.y, strings.clone_to_cstring(g.defs.title))

	monitor_id := rl.GetCurrentMonitor()
	monitor_w := rl.GetMonitorWidth(monitor_id)
	monitor_h := rl.GetMonitorHeight(monitor_id)

	rl.SetWindowPosition(
		(monitor_w/2) - (auto_cast g.window_size.x/2),
		(monitor_h/2) - (auto_cast g.window_size.y/2)
	)

	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)
}

loop :: proc(g: ^Game) {
	for !rl.WindowShouldClose() {
		update(g)
		draw(g)
		free_all(context.temp_allocator)
	}
}

update :: proc(g: ^Game) {
	update_camera(g)
	player.update(g.player, g.ground)
}

draw :: proc(g: ^Game) {
	rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.BeginMode2D(g.camera^)
			rl.DrawRectangleV(g.ground.pos, g.ground.size, rl.BROWN)
			player.draw(g.player)
			when IS_DEBUG {
				player.debug_draw(g.player)
			}
		rl.EndMode2D()

		rl.BeginMode2D(g.ui_camera^)
			FONT_SIZE :: 8
			debug_x: i32 = 0
			rl.DrawText(fmt.ctprintf("Title: %s", g.defs.title), 2, debug_x, FONT_SIZE, rl.RED)

			debug_x += FONT_SIZE
			rl.DrawText(fmt.ctprintf("FPS: %d", rl.GetFPS()), 2, debug_x, FONT_SIZE, rl.RED)
		rl.EndMode2D()

		when IS_DEBUG {
			debug_draw_camera(g)
		}

	rl.EndDrawing()
}

close :: proc(g: ^Game) {
	free(g.player)
	free(g.ground)
	free(g)
}

close_window :: proc() {
	rl.CloseWindow()
}

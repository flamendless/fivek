package game

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
import "../player"

Ground :: struct {
	pos: rl.Vector2,
	size: rl.Vector2,
}

Game :: struct {
	title: string,
	window_size: rl.Vector2,
	game_size: rl.Vector2,
	scale: f32,

	ground: ^Ground,
	player: ^player.Player,
}

init :: proc() -> ^Game {
	g := new(Game)
	g.title = "FiveK"
	g.window_size = {640, 480}
	g.game_size = {360, 240}
	g.scale = math.min(
		g.window_size.x/g.game_size.x,
		g.window_size.y/g.game_size.y,
	)

	g.ground = new(Ground)
	g.ground.pos = {0, auto_cast g.game_size.y*0.8}
	g.ground.size = {auto_cast g.game_size.x, auto_cast g.game_size.y}

	//TODO: move to scene/state load
	g.player = player.init({
		auto_cast g.game_size.x/2,
		auto_cast g.game_size.y/2,
	})

	return g
}

init_window :: proc(g: ^Game) {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(auto_cast g.window_size.x, auto_cast g.window_size.y, strings.clone_to_cstring(g.title))

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
	player.update(g.player)
}

draw :: proc(g: ^Game) {
	rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.BeginMode2D(get_game_camera(g))
			rl.DrawRectangleV(g.ground.pos, g.ground.size, rl.BROWN)
			player.draw(g.player)
		rl.EndMode2D()

		rl.BeginMode2D(get_ui_camera(g))
			FONT_SIZE :: 8
			debug_x: i32 = 0
			rl.DrawText(fmt.ctprintf("Title: %s", g.title), 2, debug_x, FONT_SIZE, rl.RED)

			debug_x += FONT_SIZE
			rl.DrawText(fmt.ctprintf("FPS: %d", rl.GetFPS()), 2, debug_x, FONT_SIZE, rl.RED)
		rl.EndMode2D()

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

package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

get_game_camera :: proc(target: rl.Vector2, offset: rl.Vector2, scale: f32) -> ^rl.Camera2D {
	camera := new(rl.Camera2D)
	camera.target = [2]f32{target.x, target.y}
	camera.offset = [2]f32{
		auto_cast offset.x/2,
		auto_cast offset.y/2,
	}
	camera.zoom = scale
	return camera
}

get_ui_camera :: proc(scale: f32) -> ^rl.Camera2D {
	camera := new(rl.Camera2D)
	camera.zoom = scale
	return camera
}

update_camera :: proc(g: ^Game) {
	g.camera.target.x = g.player.pos.x
	g.camera.target.y = g.player.pos.y
	// g.camera.offset.x = math.clamp(g.camera.offset.x, 0, g.game_size.x)
	// g.camera.offset.y = math.clamp(g.camera.offset.y, 0, g.game_size.y)
}

debug_draw_camera :: proc(g: ^Game) {
	rl.BeginMode2D(g.camera^)
		rl.DrawCircleV(g.camera.target, 8.0, rl.RED)
		rl.DrawCircleV(g.camera.offset, 8.0, rl.BLUE)
	rl.EndMode2D()
}

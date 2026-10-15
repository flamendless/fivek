package game

import "core:math"
import rl "vendor:raylib"
import "../config"

init_game_camera :: proc(game_size: rl.Vector2, scale: f32) -> rl.Camera2D {
	return rl.Camera2D{
		offset = {game_size.x * 0.5, game_size.y * 0.5},
		zoom = scale,
	}
}

init_ui_camera :: proc(scale: f32) -> rl.Camera2D {
	return rl.Camera2D{zoom = scale}
}

camera_world_height_y :: proc(game_size: rl.Vector2) -> f32 {
	return game_size.y * 0.5
}

update_camera :: proc(g: ^Game) {
	g.camera.target.x = g.player.pos.x + g.player.size.x * 0.5
	g.camera.target.y = camera_world_height_y(g.game_size)

	half_w := g.game_size.x * 0.5
	world_w := g.world_width
	if world_w > g.game_size.x {
		min_x := half_w
		max_x := world_w - half_w
		g.camera.target.x = math.clamp(g.camera.target.x, min_x, max_x)
	}
}

camera_view_rect :: proc(g: ^Game) -> rl.Rectangle {
	half_w := g.game_size.x * 0.5
	half_h := g.game_size.y * 0.5
	cx := g.camera.target.x
	cy := g.camera.target.y
	return {
		cx - half_w,
		cy - half_h,
		g.game_size.x,
		g.game_size.y,
	}
}

when config.IS_DEBUG {
	debug_draw_camera :: proc(g: ^Game) {
		rl.BeginMode2D(g.camera)
			rl.DrawCircleV(g.camera.target, 4.0, rl.RED)
		rl.EndMode2D()
	}
}

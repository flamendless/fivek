package game

import rl "vendor:raylib"

get_game_camera :: proc(g: ^Game) -> rl.Camera2D {
	return {
		zoom = g.scale,
		target = rl.Vector2{
			g.player.pos.x,
			g.player.pos.y,
		},
		offset = rl.Vector2{
			auto_cast g.window_size.x/2,
			auto_cast g.window_size.y/2,
		}
	}
}

get_ui_camera :: proc(g: ^Game) -> rl.Camera2D {
	return {
		zoom = g.scale,
	}
}

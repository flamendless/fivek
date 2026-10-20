package world

import rl "vendor:raylib"

Ground :: struct {
	pos: rl.Vector2,
	size: rl.Vector2,
	bb: rl.Rectangle,
	top_y: f32,
}

init_ground :: proc(world_width: f32, game_height: f32, top_y_frac: f32 = 0.8) -> ^Ground {
	ground := new(Ground)
	ground.top_y = game_height * top_y_frac
	ground.pos = {0, ground.top_y}
	ground.size = {world_width, game_height - ground.top_y}
	ground.bb = {ground.pos.x, ground.pos.y, ground.size.x, ground.size.y}
	return ground
}

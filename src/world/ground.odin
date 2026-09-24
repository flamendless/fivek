package world

import rl "vendor:raylib"

Ground :: struct {
	pos: rl.Vector2,
	size: rl.Vector2,
	bb: rl.Rectangle,
}

init_ground :: proc(game_size: rl.Vector2) -> ^Ground {
	ground := new(Ground)
	ground.pos = {0, auto_cast game_size.y*0.8}
	ground.size = {auto_cast game_size.x, auto_cast game_size.y}
	ground.bb = {ground.pos.x, ground.pos.y, ground.size.x, ground.size.y}
	return ground
}

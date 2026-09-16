package player

import "core:math/linalg"
import rl "vendor:raylib"
import "../world"

Player :: struct {
	pos: rl.Vector2,
	size: rl.Vector2,
	speed: f32,
}

init :: proc(pos: rl.Vector2) -> ^Player {
	p := new(Player)
	p.pos = pos
	p.size = {32, 32}
	p.speed = 64
	return p
}

update :: proc(p: ^Player) {
	movement: rl.Vector2

	up := rl.IsKeyDown(.UP) || rl.IsKeyDown(.W)
	down := rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S)
	left := rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)
	right := rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)

	if up { movement.y -= 1 }
	if down { movement.y += 1 }
	if left { movement.x -= 1 }
	if right { movement.x += 1 }

	movement.y += world.GRAVITY * rl.GetFrameTime()
	movement = linalg.normalize0(movement)
	p.pos += movement * rl.GetFrameTime() * p.speed
}

draw :: proc(p: ^Player) {
	rl.DrawCircleV(p.pos, p.size.x, rl.WHITE)
	// rl.DrawTextureEx(g.player_texture, g.player_pos, 0, 1, rl.WHITE)
}

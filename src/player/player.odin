package player

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"
import "../world"

Player :: struct {
	gravity: f32,
	pos: rl.Vector2,
	size: rl.Vector2,
	speed: f32,
	bb: rl.Rectangle,
}

init :: proc(pos: rl.Vector2, gravity: f32) -> ^Player {
	p := new(Player)
	p.gravity = gravity
	p.pos = pos
	p.size = {32, 32}
	p.speed = 64
	p.bb = {p.pos.x, p.pos.y, p.size.x, p.size.y}
	return p
}

update :: proc(p: ^Player, g: ^world.Ground) {
	movement: rl.Vector2

	up := rl.IsKeyDown(.UP) || rl.IsKeyDown(.W)
	down := rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S)
	left := rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)
	right := rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)

	if up { movement.y -= 1 }
	if down { movement.y += 1 }
	if left { movement.x -= 1 }
	if right { movement.x += 1 }
	movement = linalg.normalize0(movement)
	p.pos += movement * rl.GetFrameTime() * p.speed

	projected_bb := p.bb
	projected_bb.y += p.gravity * rl.GetFrameTime()
	if !rl.CheckCollisionRecs(projected_bb, g.bb) {
		p.pos.y = projected_bb.y
	}

	p.bb.x = p.pos.x
	p.bb.y = p.pos.y
}

draw :: proc(p: ^Player) {
	rl.DrawRectangleV(p.pos, p.size, rl.WHITE)
	// rl.DrawTextureEx(g.player_texture, g.player_pos, 0, 1, rl.WHITE)
}

debug_draw :: proc(p: ^Player) {
	rl.DrawRectangleLines(auto_cast p.bb.x, auto_cast p.bb.y, auto_cast p.bb.width, auto_cast p.bb.height, rl.RED)
}

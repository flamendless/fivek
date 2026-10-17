package player

import "core:math"
import rl "vendor:raylib"
import "../config"
import "../input"
import "../world"

PLAYER_W :: 12
PLAYER_H :: 24

SPRINT_MULT :: 1.5
DEBUG_SPRINT_MULT :: 3.0
STAMINA_MAX :: 3.0
STAMINA_REGEN :: 0.35
EXHAUST_FLASH_HZ :: 8.0

Player :: struct {
	pos: rl.Vector2,
	size: rl.Vector2,
	speed: f32,
	bb: rl.Rectangle,
	stamina: f32,
	exhausted: bool,
	facing: f32,
}

init :: proc(pos: rl.Vector2, speed: f32) -> ^Player {
	p := new(Player)
	p.pos = pos
	p.size = {f32(PLAYER_W), f32(PLAYER_H)}
	p.speed = speed
	p.stamina = STAMINA_MAX
	p.exhausted = false
	p.facing = 1
	sync_bounds(p)
	return p
}

exhaust_flash_on :: proc() -> bool {
	return i32(rl.GetTime() * EXHAUST_FLASH_HZ) % 2 == 0
}

update :: proc(p: ^Player, ground: ^world.Ground, world_width: f32, dt: f32) {
	move_x: f32

	if input.key_down(.A) || input.key_down(.LEFT) {
		move_x -= 1
	}
	if input.key_down(.D) || input.key_down(.RIGHT) {
		move_x += 1
	}

	shift := input.key_down(.LEFT_SHIFT)

	speed_mult: f32 = 1.0
	when config.IS_AUTOTEST || config.IS_DEBUG {
		p.exhausted = false
		p.stamina = STAMINA_MAX
		if shift && move_x != 0 {
			when config.IS_DEBUG {
				speed_mult = DEBUG_SPRINT_MULT
			} else {
				speed_mult = SPRINT_MULT
			}
		}
	} else {
		p.exhausted = shift && p.stamina <= 0
		if p.exhausted {
			move_x = 0
		} else {
			sprinting := shift && move_x != 0 && p.stamina > 0
			if sprinting {
				speed_mult = SPRINT_MULT
				p.stamina -= dt
				if p.stamina < 0 {
					p.stamina = 0
				}
			} else {
				p.stamina += STAMINA_REGEN * dt
				if p.stamina > STAMINA_MAX {
					p.stamina = STAMINA_MAX
				}
			}
		}
	}

	if move_x != 0 {
		p.facing = move_x
	}

	p.pos.x += move_x * p.speed * speed_mult * dt
	p.pos.x = math.clamp(p.pos.x, 0, world_width - p.size.x)

	p.pos.y = ground.top_y - p.size.y
	sync_bounds(p)
}

sync_bounds :: proc(p: ^Player) {
	p.bb = {p.pos.x, p.pos.y, p.size.x, p.size.y}
}

bounds_rect :: proc(p: ^Player) -> rl.Rectangle {
	return {p.pos.x, p.pos.y, p.size.x, p.size.y}
}

draw_rect_outline :: proc(rect: rl.Rectangle, color: rl.Color) {
	rl.DrawRectangleLinesEx(rect, 1, color)
}

draw :: proc(p: ^Player) {
	rect := bounds_rect(p)
	fill := rl.WHITE
	if p.exhausted && exhaust_flash_on() {
		fill = rl.RED
	}
	rl.DrawRectangleV(p.pos, p.size, fill)
	draw_rect_outline(rect, rl.RED)
}

when config.IS_DEBUG {
	debug_draw :: proc(p: ^Player) {
		draw_rect_outline(bounds_rect(p), rl.RED)
	}
}

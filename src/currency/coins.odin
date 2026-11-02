package currency

import "core:math"
import "../assets"
import rl "vendor:raylib"

COIN_DROP_MAX :: 32
COIN_SPIN_SPEED :: 4.0

Dropped_Coin :: struct {
	pos:  rl.Vector2,
	icon: u8,
	spin: f32,
}

draw_coin_icon_scaled :: proc(index: int, center: rl.Vector2, scale_x: f32) {
	layout := assets.coin_layout()
	if index < 0 || index >= layout.icon_count {
		return
	}
	tex := assets.coin(index)
	if tex.id == 0 {
		return
	}
	draw_size := layout.icon_draw_size
	w := draw_size * scale_x
	half_h := draw_size * 0.5
	half_w := math.abs(w) * 0.5
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - half_w, center.y - half_h, w, draw_size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

draw_coin_icon :: proc(index: int, center: rl.Vector2) {
	draw_coin_icon_scaled(index, center, 1)
}

draw_coin_icon_sized :: proc(index: int, center: rl.Vector2, size: f32) {
	layout := assets.coin_layout()
	if index < 0 || index >= layout.icon_count {
		return
	}
	tex := assets.coin(index)
	if tex.id == 0 {
		return
	}
	half := size * 0.5
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - half, center.y - half, size, size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

spawn_drop :: proc(coins: ^[dynamic]Dropped_Coin, pos: rl.Vector2, icon: u8) {
	if coins == nil || len(coins) >= COIN_DROP_MAX {
		return
	}
	append(coins, Dropped_Coin{pos = pos, icon = icon})
}

tick_drops :: proc(coins: ^[dynamic]Dropped_Coin, dt: f32) {
	if coins == nil {
		return
	}
	for &c in coins {
		c.spin += dt * COIN_SPIN_SPEED
	}
}

draw_drops :: proc(coins: ^[dynamic]Dropped_Coin, view: rl.Rectangle) {
	if coins == nil || !assets.gameplay_ready() {
		return
	}
	draw_size := assets.coin_layout().icon_draw_size
	half := draw_size * 0.5
	for c in coins {
		bounds := rl.Rectangle{c.pos.x - half, c.pos.y - half, draw_size, draw_size}
		if !rl.CheckCollisionRecs(bounds, view) {
			continue
		}
		draw_coin_icon_scaled(int(c.icon), c.pos, math.cos(c.spin))
	}
}

try_pickup :: proc(coins: ^[dynamic]Dropped_Coin, player_rect: rl.Rectangle, wallet: ^u32) -> bool {
	if coins == nil || wallet == nil {
		return false
	}
	draw_size := assets.coin_layout().icon_draw_size
	half := draw_size * 0.5
	for i := len(coins) - 1; i >= 0; i -= 1 {
		c := coins[i]
		bounds := rl.Rectangle{c.pos.x - half, c.pos.y - half, draw_size, draw_size}
		if !rl.CheckCollisionRecs(bounds, player_rect) {
			continue
		}
		wallet^ += 1
		ordered_remove(coins, i)
		return true
	}
	return false
}

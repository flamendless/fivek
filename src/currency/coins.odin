package currency

import "core:log"
import "core:math"
import rl "vendor:raylib"

COIN_ICON_DRAW_SIZE: f32 : 16
COIN_ICON_COUNT :: 8
HUD_COIN_ICON :: 0
COIN_DROP_MAX :: 32
COIN_SPIN_SPEED :: 4.0

COIN_PATHS: [COIN_ICON_COUNT]cstring = {
	"assets/coins/1.png",
	"assets/coins/2.png",
	"assets/coins/3.png",
	"assets/coins/4.png",
	"assets/coins/5.png",
	"assets/coins/6.png",
	"assets/coins/7.png",
	"assets/coins/8.png",
}

Dropped_Coin :: struct {
	pos:  rl.Vector2,
	icon: u8,
	spin: f32,
}

coin_tex: [COIN_ICON_COUNT]rl.Texture2D

ready :: proc() -> bool {
	for t in coin_tex {
		if t.id != 0 {
			return true
		}
	}
	return false
}

load :: proc() {
	if ready() {
		return
	}
	for i in 0 ..< COIN_ICON_COUNT {
		if coin_tex[i].id != 0 {
			continue
		}
		path := COIN_PATHS[i]
		log.infof("loading coin texture %s", path)
		tex := rl.LoadTexture(path)
		if tex.id != 0 {
			rl.SetTextureFilter(tex, .POINT)
			coin_tex[i] = tex
		} else {
			log.warnf("failed to load coin texture %s", path)
		}
	}
}

unload :: proc() {
	for i in 0 ..< COIN_ICON_COUNT {
		if coin_tex[i].id != 0 {
			log.infof("unloading coin texture %s", COIN_PATHS[i])
			rl.UnloadTexture(coin_tex[i])
			coin_tex[i] = {}
		}
	}
}

draw_coin_icon_scaled :: proc(index: int, center: rl.Vector2, scale_x: f32) {
	if index < 0 || index >= COIN_ICON_COUNT {
		return
	}
	tex := coin_tex[index]
	if tex.id == 0 {
		return
	}
	w := COIN_ICON_DRAW_SIZE * scale_x
	half_h := COIN_ICON_DRAW_SIZE * 0.5
	half_w := math.abs(w) * 0.5
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - half_w, center.y - half_h, w, COIN_ICON_DRAW_SIZE}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

draw_coin_icon :: proc(index: int, center: rl.Vector2) {
	draw_coin_icon_scaled(index, center, 1)
}

draw_coin_icon_sized :: proc(index: int, center: rl.Vector2, size: f32) {
	if index < 0 || index >= COIN_ICON_COUNT {
		return
	}
	tex := coin_tex[index]
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
	if coins == nil || !ready() {
		return
	}
	half := COIN_ICON_DRAW_SIZE * 0.5
	for c in coins {
		bounds := rl.Rectangle{c.pos.x - half, c.pos.y - half, COIN_ICON_DRAW_SIZE, COIN_ICON_DRAW_SIZE}
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
	half := COIN_ICON_DRAW_SIZE * 0.5
	for i := len(coins) - 1; i >= 0; i -= 1 {
		c := coins[i]
		bounds := rl.Rectangle{c.pos.x - half, c.pos.y - half, COIN_ICON_DRAW_SIZE, COIN_ICON_DRAW_SIZE}
		if !rl.CheckCollisionRecs(bounds, player_rect) {
			continue
		}
		wallet^ += 1
		ordered_remove(coins, i)
		return true
	}
	return false
}

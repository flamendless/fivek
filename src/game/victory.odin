package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../config"
import "../player"

VICTORY_MARCH_DEADBAND :: 3.0

begin_victory_march :: proc(g: ^Game) {
	g.mode = .Victory_March
	g.interact_index = -1

	when config.IS_AUTOTEST {
		g.autoplay = false
		g.autobot_target = -1
		g.autoplay_done = true
		g.autoplay_max_frames = 0
	}
}

enter_victory_lineup_pause :: proc(g: ^Game) {
	g.mode = .Victory_Lineup

	g.player.pos.x = PLAYER_START_X
	g.player.pos.y = g.ground.top_y - g.player.size.y
	player.sync_bounds(g.player)

	chunk_center := g.game_size.x * 0.5
	half_w := g.game_size.x * 0.5
	g.camera.target.x = math.clamp(chunk_center, half_w, g.world_width - half_w)
	g.camera.target.y = camera_world_height_y(g.game_size)
}

update_victory_march :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	target_x: f32 = PLAYER_START_X
	speed := g.defs.player_speed

	if g.player.pos.x < target_x - VICTORY_MARCH_DEADBAND {
		g.player.pos.x += speed * dt
		if g.player.pos.x > target_x {
			g.player.pos.x = target_x
		}
	} else if g.player.pos.x > target_x + VICTORY_MARCH_DEADBAND {
		g.player.pos.x -= speed * dt
		if g.player.pos.x < target_x {
			g.player.pos.x = target_x
		}
	} else {
		enter_victory_lineup_pause(g)
		return
	}

	g.player.pos.x = math.clamp(g.player.pos.x, 0, g.world_width - g.player.size.x)
	g.player.pos.y = g.ground.top_y - g.player.size.y
	player.sync_bounds(g.player)
	update_camera(g)
}

update_victory_lineup :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		g.mode = .Credits
	}
	if rl.IsKeyPressed(.ESCAPE) {
		rl.CloseWindow()
	}
}

update_credits :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ESCAPE) {
		g.mode = .Title
	}
}

draw_victory_lineup_hint :: proc(g: ^Game) {
	font := ui_font(g, 10)
	rl.BeginMode2D(g.ui_camera)
		msg := fmt.ctprintf("All fed. Enter - Continue")
		w := rl.MeasureText(msg, font)
		x := (i32(g.game_size.x) - w) / 2
		y: i32 = i32(g.game_size.y) - font - ui_px(g, 12)
		rl.DrawRectangle(x - ui_px(g, 4), y - ui_px(g, 2), w + ui_px(g, 8), font + ui_px(g, 4), {0, 0, 0, 180})
		rl.DrawText(msg, x, y, font, rl.WHITE)
	rl.EndMode2D()
}

draw_credits :: proc(g: ^Game) {
	title_font := ui_font(g, 20)
	body_font := ui_font(g, 16)
	x := ui_px(g, 40)
	rl.BeginMode2D(g.ui_camera)
		rl.DrawText("All fed. Thank you.", x, ui_px(g, 80), title_font, rl.WHITE)
		rl.DrawText("Five thousand plus", x, ui_px(g, 110), body_font, rl.LIGHTGRAY)
		rl.DrawText("fish and bread.", x, ui_px(g, 130), body_font, rl.LIGHTGRAY)
		rl.DrawText("Enter - Title", x, ui_px(g, 180), body_font, rl.GRAY)
	rl.EndMode2D()
}

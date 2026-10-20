package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../config"
import "../player"
import "../theme"

VICTORY_MARCH_DEADBAND :: 3.0

begin_victory_march :: proc(g: ^Game) {
	persist_run(g)
	g.mode = .Victory_March
	g.input.interact_index = -1

	when config.IS_AUTOTEST {
		g.autotest.autoplay = false
		g.autotest.autobot_target = -1
		g.autotest.autoplay_done = true
		g.autotest.autoplay_max_frames = 0
	}
}

enter_victory_lineup_pause :: proc(g: ^Game) {
	g.mode = .Victory_Lineup

	g.scene.player.pos.x = PLAYER_START_X
	g.scene.player.pos.y = g.scene.ground.top_y - g.scene.player.size.y
	player.sync_bounds(g.scene.player)

	chunk_center := g.view.game_size.x * 0.5
	half_w := camera_world_half_w(g)
	g.cameras.camera.target.x = math.clamp(chunk_center, half_w, g.view.world_width - half_w)
	g.cameras.camera.target.y = camera_world_height_y(g.view.game_size)
}

update_victory_march :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	target_x: f32 = PLAYER_START_X
	speed := g.defs.player_speed

	if g.scene.player.pos.x < target_x - VICTORY_MARCH_DEADBAND {
		g.scene.player.pos.x += speed * dt
		if g.scene.player.pos.x > target_x {
			g.scene.player.pos.x = target_x
		}
	} else if g.scene.player.pos.x > target_x + VICTORY_MARCH_DEADBAND {
		g.scene.player.pos.x -= speed * dt
		if g.scene.player.pos.x < target_x {
			g.scene.player.pos.x = target_x
		}
	} else {
		enter_victory_lineup_pause(g)
		return
	}

	g.scene.player.pos.x = math.clamp(g.scene.player.pos.x, 0, g.view.world_width - g.scene.player.size.x)
	g.scene.player.pos.y = g.scene.ground.top_y - g.scene.player.size.y
	player.sync_bounds(g.scene.player)
	update_camera(g)
}

update_victory_lineup :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		enter_credits(g, true)
	}
	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	update_nav_button_hover(g, "Quit", mouse)
	if nav_back_pressed() || nav_button_clicked(g, "Quit", mouse, clicked) {
		request_app_shutdown()
	}
}

draw_victory_lineup_hint :: proc(g: ^Game) {
	font := ui_font(g, 10)
	rl.BeginMode2D(g.cameras.ui_camera)
		msg := fmt.ctprintf("All fed. Enter - Continue")
		w := rl.MeasureText(msg, font)
		x := (i32(g.view.game_size.x) - w) / 2
		y: i32 = i32(g.view.game_size.y) - font - ui_px(g, 12)
		rl.DrawRectangle(x - ui_px(g, 4), y - ui_px(g, 2), w + ui_px(g, 8), font + ui_px(g, 4), theme.OVERLAY_SCRIM_180)
		rl.DrawText(msg, x, y, font, rl.WHITE)
		draw_nav_button(g, "Quit")
	rl.EndMode2D()
}


package game

import "core:math"
import rl "vendor:raylib"
import "../config"
import "../player"

init_game_camera :: proc(window_size: rl.Vector2, scale: f32) -> rl.Camera2D {
	return rl.Camera2D{
		offset = {window_size.x * 0.5, window_size.y * 0.5},
		zoom = scale,
	}
}

init_ui_camera :: proc(scale: f32) -> rl.Camera2D {
	return rl.Camera2D{zoom = scale}
}

camera_world_zoom :: proc(g: ^Game) -> f32 {
	return g.cameras.camera.zoom / g.view.scale
}

camera_world_half_w :: proc(g: ^Game) -> f32 {
	return g.view.game_size.x * 0.5 / camera_world_zoom(g)
}

camera_world_half_h :: proc(g: ^Game) -> f32 {
	return g.view.game_size.y * 0.5 / camera_world_zoom(g)
}

camera_world_height_y :: proc(game_size: rl.Vector2) -> f32 {
	return game_size.y * 0.5
}

// Keeps world point `focus_y` at the same screen Y when zoom changes (zoom=1 → legacy mid-frame target).
camera_target_y_for_focus :: proc(focus_y: f32, offset_y: f32, zoom: f32) -> f32 {
	mid := offset_y
	return mid + (focus_y - mid) * (1.0 - 1.0 / zoom)
}

active_game_player :: proc(g: ^Game) -> ^player.Player {
	if g.mode == .Tutorial && g.tutorial.player != nil {
		return g.tutorial.player
	}
	return g.scene.player
}

update_camera :: proc(g: ^Game) {
	pl := active_game_player(g)
	if pl == nil {
		return
	}
	player_cx := pl.pos.x + pl.size.x * 0.5
	player_cy := pl.pos.y + pl.size.y * 0.5
	g.cameras.camera.target.x = player_cx
	g.cameras.camera.target.y = camera_target_y_for_focus(
		player_cy,
		g.cameras.camera.offset.y,
		g.cameras.camera.zoom,
	)

	half_w := camera_world_half_w(g)
	world_w := g.view.world_width
	if world_w > half_w * 2 {
		min_x := half_w
		max_x := world_w - half_w
		g.cameras.camera.target.x = math.clamp(g.cameras.camera.target.x, min_x, max_x)
	}

	z := g.cameras.camera.zoom
	if z > 0 {
		g.cameras.camera.target.x = math.round(g.cameras.camera.target.x * z) / z
		g.cameras.camera.target.y = math.round(g.cameras.camera.target.y * z) / z
	}
}

camera_view_rect :: proc(g: ^Game) -> rl.Rectangle {
	half_w := camera_world_half_w(g)
	half_h := camera_world_half_h(g)
	cx := g.cameras.camera.target.x
	cy := g.cameras.camera.target.y
	return {
		cx - half_w,
		cy - half_h,
		half_w * 2,
		half_h * 2,
	}
}

when config.IS_DEBUG {
	debug_draw_camera :: proc(g: ^Game) {
		rl.BeginMode2D(g.cameras.camera)
			rl.DrawCircleV(g.cameras.camera.target, 4.0, rl.RED)
		rl.EndMode2D()
	}
}

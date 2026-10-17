package game

import "core:math"
import rl "vendor:raylib"
import "../config"

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
	return g.camera.zoom / g.scale
}

camera_world_half_w :: proc(g: ^Game) -> f32 {
	return g.game_size.x * 0.5 / camera_world_zoom(g)
}

camera_world_half_h :: proc(g: ^Game) -> f32 {
	return g.game_size.y * 0.5 / camera_world_zoom(g)
}

camera_world_height_y :: proc(game_size: rl.Vector2) -> f32 {
	return game_size.y * 0.5
}

// Keeps world point `focus_y` at the same screen Y when zoom changes (zoom=1 → legacy mid-frame target).
camera_target_y_for_focus :: proc(focus_y: f32, offset_y: f32, zoom: f32) -> f32 {
	mid := offset_y
	return mid + (focus_y - mid) * (1.0 - 1.0 / zoom)
}

update_camera :: proc(g: ^Game) {
	player_cx := g.player.pos.x + g.player.size.x * 0.5
	player_cy := g.player.pos.y + g.player.size.y * 0.5
	g.camera.target.x = player_cx
	g.camera.target.y = camera_target_y_for_focus(
		player_cy,
		g.camera.offset.y,
		g.camera.zoom,
	)

	half_w := camera_world_half_w(g)
	world_w := g.world_width
	if world_w > half_w * 2 {
		min_x := half_w
		max_x := world_w - half_w
		g.camera.target.x = math.clamp(g.camera.target.x, min_x, max_x)
	}

	z := g.camera.zoom
	if z > 0 {
		g.camera.target.x = math.round(g.camera.target.x * z) / z
		g.camera.target.y = math.round(g.camera.target.y * z) / z
	}
}

camera_view_rect :: proc(g: ^Game) -> rl.Rectangle {
	half_w := camera_world_half_w(g)
	half_h := camera_world_half_h(g)
	cx := g.camera.target.x
	cy := g.camera.target.y
	return {
		cx - half_w,
		cy - half_h,
		half_w * 2,
		half_h * 2,
	}
}

when config.IS_DEBUG {
	debug_draw_camera :: proc(g: ^Game) {
		rl.BeginMode2D(g.camera)
			rl.DrawCircleV(g.camera.target, 4.0, rl.RED)
		rl.EndMode2D()
	}
}

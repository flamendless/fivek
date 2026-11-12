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

post_game_first_chunk_camera_x :: proc(g: ^Game, preferred_x: f32) -> f32 {
	if g.scene.level == nil || len(g.scene.level.chunks) == 0 {
		return preferred_x
	}
	chunk := g.scene.level.chunks[0]
	half_w := camera_world_half_w(g)
	min_x := chunk.x_min + half_w
	max_x := chunk.x_max - half_w
	if max_x < min_x {
		return (chunk.x_min + chunk.x_max) * 0.5
	}
	return math.clamp(preferred_x, min_x, max_x)
}

post_game_lock_finale_camera_x :: proc(g: ^Game) {
	g.epilogue.finale_camera_x = post_game_first_chunk_camera_x(g, g.cameras.camera.target.x)
	g.epilogue.finale_camera_locked = true
	g.cameras.camera.target.x = g.epilogue.finale_camera_x
}

post_game_apply_finale_camera :: proc(g: ^Game, sky_pan_t: f32) {
	pl := g.scene.player
	if pl == nil {
		return
	}
	if g.epilogue.finale_camera_locked {
		g.cameras.camera.target.x = g.epilogue.finale_camera_x
	} else {
		post_game_lock_finale_camera_x(g)
	}

	player_cy := pl.pos.y + pl.size.y * 0.5
	fy := camera_target_y_for_focus(
		player_cy,
		g.cameras.camera.offset.y,
		g.cameras.camera.zoom,
	)
	if sky_pan_t > 0 {
		sky_y := g.view.game_size.y * -0.35
		g.cameras.camera.target.y = fy + (sky_y - fy) * sky_pan_t
	} else {
		g.cameras.camera.target.y = fy
	}

	z := g.cameras.camera.zoom
	if z > 0 {
		g.cameras.camera.target.x = math.round(g.cameras.camera.target.x * z) / z
		g.cameras.camera.target.y = math.round(g.cameras.camera.target.y * z) / z
	}
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

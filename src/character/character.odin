package character

import "../assets"
import "../wardrobe"
import rl "vendor:raylib"

ANIM_FPS :: wardrobe.CROWD_ANIM_FPS

draw_sheet_cell :: proc(tex: rl.Texture2D, grid: assets.Grid_Atlas, index: int, dest: rl.Rectangle, flip_h: bool) {
	if tex.id == 0 {
		return
	}
	src := assets.atlas_src_rect(index, grid)
	if flip_h {
		src.width = -src.width
	}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

crowd_idle_overlay_sheet :: proc(layer: wardrobe.Idle_Layer) -> assets.Crowd_Sheet {
	switch layer {
	case .Upper:
		return .Upper
	case .Head:
		return .Head
	case .Hair:
		return .Hair
	}
	return .Upper
}

crowd_walk_overlay_sheet :: proc(layer: wardrobe.Idle_Layer) -> assets.Crowd_Sheet {
	switch layer {
	case .Upper:
		return .Upper_Right
	case .Head:
		return .Head_Right
	case .Hair:
		return .Hair_Right
	}
	return .Upper_Right
}

draw_crowd :: proc(
	dest: rl.Rectangle,
	appearance: wardrobe.Appearance,
	motion: wardrobe.Motion_Kind,
	dir: f32,
	idle_anim_t: f32,
	walk_anim_t: f32,
) {
	if !assets.crowd_ready() {
		return
	}
	flip_h := motion == .Walk && dir < 0

	switch motion {
	case .Idle:
		frame := wardrobe.idle_base_frame(idle_anim_t)
		draw_sheet_cell(assets.crowd_sheet(.Char), assets.CROWD_IDLE_BASE_GRID, frame, dest, false)
		for layer in wardrobe.Idle_Layer {
			look := wardrobe.idle_layer_look(appearance, layer)
			col := wardrobe.overlay_column(look)
			sheet := crowd_idle_overlay_sheet(layer)
			draw_sheet_cell(assets.crowd_sheet(sheet), assets.CROWD_IDLE_OVERLAY_GRID, col, dest, false)
		}
	case .Walk:
		body := wardrobe.walk_body_frame(walk_anim_t)
		draw_sheet_cell(assets.crowd_sheet(.Char_Right), assets.CROWD_WALK_GRID, body, dest, flip_h)
		for layer in wardrobe.Idle_Layer {
			look := wardrobe.idle_layer_look(appearance, layer)
			idx := wardrobe.walk_overlay_index(look, walk_anim_t)
			sheet := crowd_walk_overlay_sheet(layer)
			draw_sheet_cell(assets.crowd_sheet(sheet), assets.CROWD_WALK_GRID, idx, dest, flip_h)
		}
	}
}

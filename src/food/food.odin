package food

import "core:math"
import rl "vendor:raylib"

FOOD_ICON_DRAW_SIZE: f32 : 16

atlas_src_rect :: proc(index: int, cell: f32, cols: int) -> rl.Rectangle {
	col := index % cols
	row := index / cols
	return {f32(col) * cell, f32(row) * cell, cell, cell}
}

draw_icon :: proc(
	tex: rl.Texture2D,
	index: int,
	cell: f32,
	cols: int,
	center: rl.Vector2,
	size: f32 = FOOD_ICON_DRAW_SIZE,
) {
	draw_icon_tinted_rotated(tex, index, cell, cols, center, size, rl.WHITE, 0)
}

icon_dest_rect :: proc(center: rl.Vector2, size: f32) -> rl.Rectangle {
	half := size * 0.5
	return {center.x - half, center.y - half, size, size}
}

draw_icon_tinted_rotated :: proc(
	tex: rl.Texture2D,
	index: int,
	cell: f32,
	cols: int,
	center: rl.Vector2,
	size: f32,
	tint: rl.Color,
	rotation_deg: f32,
) {
	dest := icon_dest_rect(center, size)
	draw_icon_tinted_in_dest(tex, index, cell, cols, dest, tint, rotation_deg)
}

draw_icon_tinted_in_dest :: proc(
	tex: rl.Texture2D,
	index: int,
	cell: f32,
	cols: int,
	dest: rl.Rectangle,
	tint: rl.Color,
	rotation_deg: f32,
) {
	src := atlas_src_rect(index, cell, cols)
	// raylib: when rotation==0, top-left is (dest.x - origin.x, dest.y - origin.y); use {} so dest matches hit rects (coins/social).
	rl.DrawTexturePro(tex, src, dest, {}, rotation_deg, tint)
}

point_in_oriented_icon :: proc(
	mouse: rl.Vector2,
	center: rl.Vector2,
	size: f32,
	rotation_deg: f32,
) -> bool {
	half := size * 0.5
	d := mouse - center
	rad := -rotation_deg * (math.PI / 180.0)
	c := math.cos(rad)
	s := math.sin(rad)
	local_x := d.x * c - d.y * s
	local_y := d.x * s + d.y * c
	return math.abs(local_x) <= half && math.abs(local_y) <= half
}

oriented_icon_corners :: proc(center: rl.Vector2, size: f32, rotation_deg: f32) -> [4]rl.Vector2 {
	half := size * 0.5
	locals := [4]rl.Vector2{{-half, -half}, {half, -half}, {half, half}, {-half, half}}
	rad := rotation_deg * (math.PI / 180.0)
	c := math.cos(rad)
	s := math.sin(rad)
	corners: [4]rl.Vector2
	for i in 0 ..< 4 {
		p := locals[i]
		corners[i] = center + {p.x * c - p.y * s, p.x * s + p.y * c}
	}
	return corners
}

draw_oriented_icon_outline :: proc(
	center: rl.Vector2,
	size: f32,
	rotation_deg: f32,
	line_w: f32,
	color: rl.Color,
) {
	corners := oriented_icon_corners(center, size, rotation_deg)
	for i in 0 ..< 4 {
		j := (i + 1) % 4
		rl.DrawLineEx(corners[i], corners[j], line_w, color)
	}
}

ready :: proc() -> bool {
	return fish_ready() && bread_ready()
}

load :: proc() {
	if ready() {
		return
	}
	if !load_fish() || !load_bread() {
		unload_fish()
		unload_bread()
	}
}

unload :: proc() {
	unload_fish()
	unload_bread()
}

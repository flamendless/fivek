package food

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
	half := size * 0.5
	src := atlas_src_rect(index, cell, cols)
	dest := rl.Rectangle{center.x - half, center.y - half, size, size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
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

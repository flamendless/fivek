package food

import rl "vendor:raylib"

FISH_ATLAS_PATH :: "assets/fishes/fishes.png"
FISH_CELL_SIZE :: 16
FISH_ATLAS_COLS :: 6
FISH_ICON_COUNT :: 30

@(private = "package")
fish_tex: rl.Texture2D

fish_ready :: proc() -> bool {
	return fish_tex.id != 0
}

load_fish :: proc() -> bool {
	if fish_tex.id != 0 {
		return true
	}
	tex := rl.LoadTexture(FISH_ATLAS_PATH)
	if tex.id == 0 {
		return false
	}
	rl.SetTextureFilter(tex, .POINT)
	fish_tex = tex
	return true
}

unload_fish :: proc() {
	if fish_tex.id != 0 {
		rl.UnloadTexture(fish_tex)
		fish_tex = {}
	}
}

draw_fish_icon :: proc(index: int, center: rl.Vector2) {
	draw_icon(fish_tex, index, f32(FISH_CELL_SIZE), FISH_ATLAS_COLS, center)
}

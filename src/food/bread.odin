package food

import rl "vendor:raylib"

BREAD_ATLAS_PATH :: "assets/breads/breads.png"
BREAD_CELL_SIZE :: 32
BREAD_ATLAS_COLS :: 8
BREAD_ICON_COUNT :: 32

@(private = "package")
bread_tex: rl.Texture2D

bread_ready :: proc() -> bool {
	return bread_tex.id != 0
}

load_bread :: proc() -> bool {
	if bread_tex.id != 0 {
		return true
	}
	tex := rl.LoadTexture(BREAD_ATLAS_PATH)
	if tex.id == 0 {
		return false
	}
	rl.SetTextureFilter(tex, .POINT)
	bread_tex = tex
	return true
}

unload_bread :: proc() {
	if bread_tex.id != 0 {
		rl.UnloadTexture(bread_tex)
		bread_tex = {}
	}
}

draw_bread_icon :: proc(index: int, center: rl.Vector2) {
	draw_icon(bread_tex, index, f32(BREAD_CELL_SIZE), BREAD_ATLAS_COLS, center)
}

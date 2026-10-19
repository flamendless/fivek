package food

import "core:log"
import rl "vendor:raylib"

BREAD_ATLAS_PATH :: "assets/breads/breads.png"
BREAD_CELL_SIZE :: 32
BREAD_ATLAS_COLS :: 8
BREAD_ICON_COUNT :: 32

bread_tex: rl.Texture2D

bread_ready :: proc() -> bool {
	return bread_tex.id != 0
}

load_bread :: proc() -> bool {
	if bread_tex.id != 0 {
		return true
	}
	log.infof("loading food atlas %s", BREAD_ATLAS_PATH)
	tex := rl.LoadTexture(BREAD_ATLAS_PATH)
	if tex.id == 0 {
		log.warnf("failed to load food atlas %s", BREAD_ATLAS_PATH)
		return false
	}
	rl.SetTextureFilter(tex, .POINT)
	bread_tex = tex
	return true
}

unload_bread :: proc() {
	if bread_tex.id != 0 {
		log.infof("unloading food atlas %s", BREAD_ATLAS_PATH)
		rl.UnloadTexture(bread_tex)
		bread_tex = {}
	}
}

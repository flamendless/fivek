package food

import "core:log"
import rl "vendor:raylib"

FISH_ATLAS_PATH :: "assets/fishes/fishes.png"
FISH_CELL_SIZE :: 16
FISH_ATLAS_COLS :: 6
FISH_ICON_COUNT :: 30

fish_tex: rl.Texture2D

fish_ready :: proc() -> bool {
	return fish_tex.id != 0
}

load_fish :: proc() -> bool {
	if fish_tex.id != 0 {
		return true
	}
	log.infof("loading food atlas %s", FISH_ATLAS_PATH)
	tex := rl.LoadTexture(FISH_ATLAS_PATH)
	if tex.id == 0 {
		log.warnf("failed to load food atlas %s", FISH_ATLAS_PATH)
		return false
	}
	rl.SetTextureFilter(tex, .POINT)
	fish_tex = tex
	return true
}

unload_fish :: proc() {
	if fish_tex.id != 0 {
		log.infof("unloading food atlas %s", FISH_ATLAS_PATH)
		rl.UnloadTexture(fish_tex)
		fish_tex = {}
	}
}

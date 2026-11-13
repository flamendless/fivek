package assets

import "core:log"

@(private = "file")
gameplay_loaded: bool

load_gameplay :: proc() {
	if gameplay_loaded {
		return
	}
	ok := true
	_, fish_ok := acquire_texture(FISH_ATLAS_PATH, OPT_POINT_CLAMP)
	ok = ok && fish_ok
	_, bread_ok := acquire_texture(BREAD_ATLAS_PATH, OPT_POINT_CLAMP)
	ok = ok && bread_ok
	for i in 0 ..< COIN_ICON_COUNT {
		_, coin_ok := acquire_texture(COIN_PATHS[i], OPT_POINT_CLAMP)
		ok = ok && coin_ok
	}
	for key in UI_Texture {
		_, ui_ok := acquire_texture(UI_TEXTURE_PATHS[key], OPT_POINT_CLAMP)
		ok = ok && ui_ok
	}
	ok = ok && load_crowd_sheets()
	ok = ok && load_cozy_textures()
	ok = ok && load_emote_textures()
	if !ok {
		log.warn("assets: gameplay load had failures")
		release_gameplay_textures()
		return
	}
	gameplay_loaded = true
}

@(private = "file")
release_gameplay_textures :: proc() {
	unload_crowd_sheets()
	release_cozy_textures()
	release_emote_textures()
	release_texture(FISH_ATLAS_PATH)
	release_texture(BREAD_ATLAS_PATH)
	for i in 0 ..< COIN_ICON_COUNT {
		release_texture(COIN_PATHS[i])
	}
	for key in UI_Texture {
		release_texture(UI_TEXTURE_PATHS[key])
	}
}

unload_gameplay :: proc() {
	if !gameplay_loaded {
		return
	}
	release_gameplay_textures()
	gameplay_loaded = false
}

package assets

import "core:log"

@(private = "file")
boot_loaded: bool

load_boot :: proc() {
	if boot_loaded {
		return
	}
	_, ok := acquire_texture(SPLASH_LOGO_PATH, OPT_POINT_CLAMP)
	if !ok {
		log.warn("assets: boot splash failed")
	}
	_, ok = acquire_font(TITLE_FONT_PATH)
	if !ok {
		log.warn("assets: boot title font failed")
	}
	_, ok = acquire_texture(SOCIAL_ATLAS_PATH, OPT_POINT_CLAMP)
	if !ok {
		log.warn("assets: boot social atlas failed")
	}
	boot_loaded = true
}

unload_boot :: proc() {
	if !boot_loaded {
		return
	}
	release_texture(SPLASH_LOGO_PATH)
	release_font(TITLE_FONT_PATH)
	release_texture(SOCIAL_ATLAS_PATH)
	boot_loaded = false
}

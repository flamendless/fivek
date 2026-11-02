package assets

import "core:log"
import rl "vendor:raylib"

load_texture_raw :: proc(path: cstring) -> rl.Texture2D {
	log.infof("loading texture %s", path)
	tex := rl.LoadTexture(path)
	if tex.id == 0 {
		log.warnf("failed to load texture %s", path)
	}
	return tex
}

apply_texture_opts :: proc(tex: rl.Texture2D, opts: Texture_Opts) {
	if tex.id == 0 {
		return
	}
	rl.SetTextureFilter(tex, opts.filter)
	rl.SetTextureWrap(tex, opts.wrap)
}

load_font_raw :: proc(path: cstring) -> rl.Font {
	log.infof("loading font %s", path)
	font := rl.LoadFont(path)
	if font.texture.id == 0 {
		log.warnf("failed to load font %s", path)
	} else {
		rl.SetTextureFilter(font.texture, .POINT)
	}
	return font
}

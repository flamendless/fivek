package assets

import "core:log"
import "core:strings"
import rl "vendor:raylib"

Texture_Opts :: struct {
	filter: rl.TextureFilter,
	wrap:   rl.TextureWrap,
}

OPT_POINT_CLAMP :: Texture_Opts{.POINT, .CLAMP}
OPT_POINT_REPEAT :: Texture_Opts{.POINT, .REPEAT}
OPT_BILINEAR_REPEAT :: Texture_Opts{.BILINEAR, .REPEAT}

PARALLAX_LAYER_OPTS :: OPT_POINT_CLAMP
PATTERN_TEXTURE_OPTS :: OPT_BILINEAR_REPEAT

@(private = "file")
Texture_Cache_Entry :: struct {
	tex:  rl.Texture2D,
	opts: Texture_Opts,
	refs: int,
}

@(private = "file")
Font_Cache_Entry :: struct {
	font: rl.Font,
	refs: int,
}

@(private = "file")
texture_cache: map[string]Texture_Cache_Entry

@(private = "file")
font_cache: map[string]Font_Cache_Entry

@(private = "file")
opts_match :: proc(a, b: Texture_Opts) -> bool {
	return a.filter == b.filter && a.wrap == b.wrap
}

@(private = "file")
path_key :: proc(path: cstring) -> string {
	return string(path)
}

peek_texture :: proc(path: cstring) -> rl.Texture2D {
	key := path_key(path)
	if e, ok := texture_cache[key]; ok {
		return e.tex
	}
	return {}
}

@(private = "file")
ensure_cache_maps :: proc() {
	if texture_cache == nil {
		texture_cache = make(map[string]Texture_Cache_Entry)
	}
	if font_cache == nil {
		font_cache = make(map[string]Font_Cache_Entry)
	}
}

acquire_texture :: proc(path: cstring, opts: Texture_Opts) -> (tex: rl.Texture2D, ok: bool) {
	ensure_cache_maps()
	key := path_key(path)
	if e, found := texture_cache[key]; found {
		if !opts_match(e.opts, opts) {
			log.errorf("assets: texture opts mismatch for %s", path)
			return {}, false
		}
		e.refs += 1
		texture_cache[key] = e
		return e.tex, true
	}
	tex = load_texture_raw(path)
	if tex.id == 0 {
		return {}, false
	}
	apply_texture_opts(tex, opts)
	key_owned := strings.clone_from_cstring(path)
	texture_cache[key_owned] = Texture_Cache_Entry{tex = tex, opts = opts, refs = 1}
	return tex, true
}

release_texture :: proc(path: cstring) {
	release_texture_key(string(path))
}

release_texture_key :: proc(path: string) {
	ensure_cache_maps()
	key := path
	e, found := texture_cache[key]
	if !found {
		log.warnf("assets: release_texture missing entry %v", path)
		return
	}
	e.refs -= 1
	if e.refs > 0 {
		texture_cache[key] = e
		return
	}
	log.infof("unloading texture %v", path)
	rl.UnloadTexture(e.tex)
	delete_key(&texture_cache, key)
}

acquire_font :: proc(path: cstring) -> (font: rl.Font, ok: bool) {
	ensure_cache_maps()
	key := path_key(path)
	if e, found := font_cache[key]; found {
		e.refs += 1
		font_cache[key] = e
		return e.font, true
	}
	font = load_font_raw(path)
	if font.texture.id == 0 {
		return {}, false
	}
	key_owned := strings.clone_from_cstring(path)
	font_cache[key_owned] = Font_Cache_Entry{font = font, refs = 1}
	return font, true
}

release_font :: proc(path: cstring) {
	ensure_cache_maps()
	key := path_key(path)
	e, found := font_cache[key]
	if !found {
		log.warnf("assets: release_font missing entry %v", path)
		return
	}
	e.refs -= 1
	if e.refs > 0 {
		font_cache[key] = e
		return
	}
	log.infof("unloading font %v", path)
	rl.UnloadFont(e.font)
	delete_key(&font_cache, key)
}

peek_font :: proc(path: cstring) -> rl.Font {
	key := path_key(path)
	if e, ok := font_cache[key]; ok {
		return e.font
	}
	return {}
}

cache_log_remaining :: proc() {
	for key, e in texture_cache {
		log.warnf("assets: texture cache leak %s refs=%d", key, e.refs)
	}
	for key, e in font_cache {
		log.warnf("assets: font cache leak %s refs=%d", key, e.refs)
	}
}

package pattern_bg

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../theme"

PATH_BUF_SIZE :: 96

Variant :: enum {
	Basketweave,
	Checker,
	Crosshatch,
	Diagonal,
	Distress,
	Hatching,
	Herringbone,
	Screentones,
	Stars,
}

VARIANT_COUNT :: int(Variant.Stars) + 1

Variant_Info :: struct {
	folder:    cstring,
	prefix:    cstring,
	sub_count: u8,
}

@(private = "file")
VARIANT_INFO: [Variant]Variant_Info = {
	.Basketweave = {"basketweave", "basketweave", 3},
	.Checker     = {"checker", "checker", 3},
	.Crosshatch  = {"crosshatch", "crosshatch", 3},
	.Diagonal    = {"diagonal", "diagonal", 3},
	.Distress    = {"distress", "distress", 5},
	.Hatching    = {"hatching", "hatching", 3},
	.Herringbone = {"herringbone", "herringbone", 3},
	.Screentones = {"screentones", "stipple", 6},
	.Stars       = {"stars", "stars", 3},
}

Config :: struct {
	bg_color:   rl.Color,
	variant:    Variant,
	subvariant: u8,
	direction:  rl.Vector2,
	speed:      f32,
	zoom:       f32,
}

Screen_Pattern :: struct {
	config:          Config,
	tex:             rl.Texture2D,
	offset:          rl.Vector2,
	loaded_variant:  Variant,
	loaded_sub:      u8,
}

DEFAULT_CONFIG :: Config {
	bg_color   = theme.PATTERN_DARK_BG,
	variant    = .Checker,
	subvariant = 1,
	direction  = {1, 0},
	speed      = 0,
	zoom       = 1,
}

subvariant_count :: proc(variant: Variant) -> u8 {
	return VARIANT_INFO[variant].sub_count
}

random_variant :: proc() -> Variant {
	return Variant(rand.int_max(VARIANT_COUNT))
}

random_subvariant :: proc(variant: Variant) -> u8 {
	n := subvariant_count(variant)
	return u8(rand.int_max(int(n)) + 1)
}

random_direction :: proc() -> rl.Vector2 {
	dirs := [4]rl.Vector2{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	return dirs[rand.int_max(len(dirs))]
}

@(private = "file")
pattern_path :: proc(variant: Variant, sub: u8, buf: []u8) -> (cstring, bool) {
	info := VARIANT_INFO[variant]
	if sub < 1 || sub > info.sub_count {
		return "", false
	}
	s := fmt.bprintf(
		buf[:len(buf) - 1],
		"assets/patterns/%s/%s_%02d.png",
		info.folder,
		info.prefix,
		sub,
	)
	if len(s) == 0 {
		return "", false
	}
	buf[len(s)] = 0
	return cstring(&buf[0]), true
}

@(private = "file")
unload_tex :: proc(p: ^Screen_Pattern) {
	if p.tex.id != 0 {
		rl.UnloadTexture(p.tex)
		p.tex = {}
	}
	p.loaded_sub = 0
}

@(private = "file")
load_tex :: proc(p: ^Screen_Pattern, variant: Variant, sub: u8) -> bool {
	path_buf: [PATH_BUF_SIZE]u8
	path, ok := pattern_path(variant, sub, path_buf[:])
	if !ok {
		log.warnf("pattern_bg: invalid subvariant %d for %v", sub, variant)
		return false
	}
	log.infof("pattern_bg: loading %s", path)
	tex := rl.LoadTexture(path)
	if tex.id == 0 {
		log.warnf("pattern_bg: failed to load %s", path)
		return false
	}
	rl.SetTextureFilter(tex, .BILINEAR)
	rl.SetTextureWrap(tex, .REPEAT)
	unload_tex(p)
	p.tex = tex
	p.loaded_variant = variant
	p.loaded_sub = sub
	return true
}

create :: proc(cfg: Config = DEFAULT_CONFIG) -> (^Screen_Pattern, bool) {
	p := new(Screen_Pattern)
	p.config = cfg
	if !load_tex(p, cfg.variant, cfg.subvariant) {
		destroy(p)
		return nil, false
	}
	return p, true
}

destroy :: proc(p: ^Screen_Pattern) {
	if p == nil {
		return
	}
	unload_tex(p)
	free(p)
}

set_config :: proc(p: ^Screen_Pattern, cfg: Config) -> bool {
	if p == nil {
		return false
	}
	need_reload := cfg.variant != p.loaded_variant || cfg.subvariant != p.loaded_sub
	p.config = cfg
	if need_reload {
		return load_tex(p, cfg.variant, cfg.subvariant)
	}
	return true
}

@(private = "file")
norm_direction :: proc(dir: rl.Vector2) -> rl.Vector2 {
	len_sq := dir.x * dir.x + dir.y * dir.y
	if len_sq <= 0 {
		return {1, 0}
	}
	inv_len := 1.0 / math.sqrt(len_sq)
	return dir * inv_len
}

@(private = "file")
positive_mod :: proc(v: f64, span: f64) -> f32 {
	if span <= 0 {
		return 0
	}
	m := v - math.floor(v / span) * span
	if m < 0 {
		m += span
	}
	return f32(m)
}

@(private = "file")
scroll_offset :: proc(cfg: Config, tile_w, tile_h: f32, t: f64) -> (ox: f32, oy: f32) {
	if cfg.speed <= 0 || tile_w <= 0 || tile_h <= 0 {
		return 0, 0
	}
	dir := norm_direction(cfg.direction)
	along := t * f64(cfg.speed)
	ox = positive_mod(f64(dir.x) * along, f64(tile_w))
	oy = positive_mod(f64(dir.y) * along, f64(tile_h))
	return ox, oy
}

@(private = "file")
config_zoom :: proc(zoom: f32) -> f32 {
	return math.max(zoom, 1)
}

@(private = "file")
draw_tiles :: proc(p: ^Screen_Pattern, bounds: rl.Rectangle, tile_w, tile_h: f32) {
	if p.tex.id == 0 || tile_w <= 0 || tile_h <= 0 {
		return
	}

	ox, oy := scroll_offset(p.config, tile_w, tile_h, rl.GetTime())

	tex_w := f32(p.tex.width)
	tex_h := f32(p.tex.height)

	u0 := ox / tile_w * tex_w
	v0 := oy / tile_h * tex_h
	src := rl.Rectangle{
		u0,
		v0,
		(bounds.width / tile_w) * tex_w,
		(bounds.height / tile_h) * tex_h,
	}
	rl.DrawTexturePro(p.tex, src, bounds, {}, 0, rl.WHITE)
}

draw :: proc(p: ^Screen_Pattern, bounds: rl.Rectangle, tile_size: f32) {
	if p == nil {
		return
	}
	rl.DrawRectangleRec(bounds, p.config.bg_color)
	if tile_size <= 0 {
		return
	}
	z := config_zoom(p.config.zoom)
	draw_tiles(p, bounds, tile_size * z, tile_size * z)
}

draw_grid :: proc(p: ^Screen_Pattern, bounds: rl.Rectangle, cells_across: int) {
	if p == nil {
		return
	}
	rl.DrawRectangleRec(bounds, p.config.bg_color)
	if cells_across < 1 {
		return
	}
	tile := bounds.width / f32(cells_across)
	tile = max(tile, bounds.height) * config_zoom(p.config.zoom)
	draw_tiles(p, bounds, tile, tile)
}

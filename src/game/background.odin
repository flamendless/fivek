package game

import "core:log"
import "core:math"
import rl "vendor:raylib"

PARALLAX_MAX :: 0.75
PARALLAX_ZOOM :: 1.0

BG_Set :: struct {
	name: cstring,
	layers: []cstring,
}

Parallax_Layer :: struct {
	tex: rl.Texture2D,
	tile_w: f32,
	draw_h: f32,
}

Parallax_BG :: struct {
	set_name: cstring,
	layers: [dynamic]Parallax_Layer,
	game_h: f32,
	zoom:   f32,
}

PARALLAX_BG_SETS := []BG_Set{
	{
		name = "nature_1",
		layers = {
			"assets/bg/nature_1/1.png",
			"assets/bg/nature_1/2.png",
			"assets/bg/nature_1/3.png",
			"assets/bg/nature_1/5.png",
			"assets/bg/nature_1/6.png",
			"assets/bg/nature_1/7.png",
			"assets/bg/nature_1/8.png",
		},
	},
	{
		name = "nature_2",
		layers = {
			"assets/bg/nature_2/1.png",
			"assets/bg/nature_2/2.png",
			"assets/bg/nature_2/3.png",
			"assets/bg/nature_2/4.png",
		},
	},
	{
		name = "nature_3",
		layers = {
			"assets/bg/nature_3/1.png",
			"assets/bg/nature_3/2.png",
			"assets/bg/nature_3/3.png",
			"assets/bg/nature_3/4.png",
		},
	},
	{
		name = "nature_4",
		layers = {
			"assets/bg/nature_4/1.png",
			"assets/bg/nature_4/2.png",
			"assets/bg/nature_4/3.png",
			"assets/bg/nature_4/4.png",
		},
	},
	{
		name = "nature_5",
		layers = {
			"assets/bg/nature_5/1.png",
			"assets/bg/nature_5/2.png",
			"assets/bg/nature_5/3.png",
			"assets/bg/nature_5/4.png",
			"assets/bg/nature_5/5.png",
		},
	},
}

load_parallax_bg :: proc(seed: u64, game_h: f32) -> (^Parallax_BG, bool) {
	if len(PARALLAX_BG_SETS) == 0 {
		return nil, false
	}
	set := PARALLAX_BG_SETS[int(seed % u64(len(PARALLAX_BG_SETS)))]
	log.infof("loading parallax set %s (seed %d)", set.name, seed)
	bg := new(Parallax_BG)
	bg.set_name = set.name
	bg.game_h = game_h
	bg.zoom = PARALLAX_ZOOM

	for path in set.layers {
		tex := rl.LoadTexture(path)
		if tex.id == 0 {
			log.errorf("failed to load parallax layer %s", path)
			continue
		}
		log.infof("loading parallax layer %s", path)
		rl.SetTextureFilter(tex, .POINT)
		scale := game_h / f32(tex.height)
		tile_w := f32(tex.width) * scale
		append(&bg.layers, Parallax_Layer{tex = tex, tile_w = tile_w, draw_h = game_h})
	}

	if len(bg.layers) == 0 {
		free(bg)
		return nil, false
	}
	return bg, true
}

free_parallax_bg :: proc(bg: ^Parallax_BG) {
	if bg == nil {
		return
	}
	log.infof("freeing parallax set %s", bg.set_name)
	for &layer in bg.layers {
		rl.UnloadTexture(layer.tex)
	}
	delete(bg.layers)
	free(bg)
}

draw_parallax_bg :: proc(bg: ^Parallax_BG, cam_x: f32, view: rl.Rectangle) {
	if bg == nil || len(bg.layers) == 0 {
		return
	}
	n := len(bg.layers)
	denom := f32(max(n - 1, 1))

	zoom := bg.zoom
	if zoom <= 0 {
		zoom = 1
	}

	for &layer, i in bg.layers {
		depth := (f32(i) / denom) - 1.0
		scroll := cam_x * depth * PARALLAX_MAX * zoom
		tile_w := layer.tile_w * zoom
		if tile_w <= 0 {
			continue
		}
		draw_h := layer.draw_h * zoom
		y := bg.game_h - draw_h

		first := int(math.floor((view.x + scroll) / tile_w)) - 1
		last := int(math.ceil((view.x + view.width + scroll) / tile_w))
		src := rl.Rectangle{0, 0, f32(layer.tex.width), f32(layer.tex.height)}
		for ti in first ..= last {
			x := f32(ti) * tile_w - scroll
			dest := rl.Rectangle{x, y, tile_w, draw_h}
			rl.DrawTexturePro(layer.tex, src, dest, {}, 0, rl.WHITE)
		}
	}
}

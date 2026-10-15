package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

PARALLAX_MAX :: 0.65

BG_Set :: struct {
	name: cstring,
	layers: []cstring,
}

@(private = "file")
BG_SETS := []BG_Set{
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
			"assets/bg/nature_1/10.png",
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

Parallax_Layer :: struct {
	tex: rl.Texture2D,
	tile_w: f32,
	draw_h: f32,
}

Parallax_BG :: struct {
	set_name: cstring,
	layers: [dynamic]Parallax_Layer,
	game_h: f32,
}

load_parallax_bg :: proc(seed: u64, game_h: f32) -> (^Parallax_BG, bool) {
	if len(BG_SETS) == 0 {
		return nil, false
	}
	set := BG_SETS[int(seed % u64(len(BG_SETS)))]
	bg := new(Parallax_BG)
	bg.set_name = set.name
	bg.game_h = game_h

	for path in set.layers {
		tex := rl.LoadTexture(path)
		if tex.id == 0 {
			fmt.eprintf("background: failed to load %s\n", path)
			continue
		}
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

	for &layer, i in bg.layers {
		t := (f32(i) / denom) * PARALLAX_MAX
		scroll := cam_x * t
		tile_w := layer.tile_w
		if tile_w <= 0 {
			continue
		}
		y := bg.game_h - layer.draw_h

		first := int(math.floor((view.x + scroll) / tile_w)) - 1
		last := int(math.ceil((view.x + view.width + scroll) / tile_w))
		src := rl.Rectangle{0, 0, f32(layer.tex.width), f32(layer.tex.height)}
		for ti in first ..= last {
			x := f32(ti) * tile_w - scroll
			dest := rl.Rectangle{x, y, tile_w, layer.draw_h}
			rl.DrawTexturePro(layer.tex, src, dest, {}, 0, rl.WHITE)
		}
	}
}

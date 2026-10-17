package world

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../config"

PERSON_MARGIN :: 4
ROAM_MIN_EXTRA :: 8.0
LINEUP_CHUNK_INDEX :: 0

Spawn_Person :: struct {
	pos_x, pos_y: f32,
	bound_min_x, bound_max_x: f32,
	size_w, size_h: f32,
	speed_scale: f32,
	age: u8,
	color: u32,
}

Chunk :: struct {
	index: int,
	x_min: f32,
	x_max: f32,
	person_start: int,
	person_count: int,
}

World :: struct {
	seed: u64,
	chunk_width: f32,
	chunk_count: int,
	width: f32,
	chunks: []Chunk,
	spawn: #soa[]Spawn_Person,
}

World_Params :: struct {
	seed: u64,
	chunk_width: f32,
	target_population: int,
	pop_min, pop_max: int,
	ground_y: f32,
}

rand_range :: proc(lo, hi: int) -> int {
	if hi <= lo {
		return lo
	}
	return lo + rand.int_max(hi - lo + 1)
}

roll_age :: proc() -> u8 {
	roll := rand.int_max(100)
	if roll < 50 {
		return 0
	}
	if roll < 80 {
		return 1
	}
	return 2
}

roll_size_for_age :: proc(age: u8) -> (w, h: f32) {
	switch age {
	case 2:
		w = f32(rand_range(10, 12))
		h = f32(rand_range(20, 24))
	case 1:
		w = f32(rand_range(16, 18))
		h = f32(rand_range(22, 26))
	case:
		w = f32(rand_range(22, 24))
		h = f32(rand_range(32, 36))
	}
	return w, h
}

roll_speed_scale :: proc() -> f32 {
	return 0.8 + rand.float32() * 0.4
}

random_color :: proc() -> u32 {
	r8 := u32(rand.int_max(256))
	g8 := u32(rand.int_max(256))
	b8 := u32(rand.int_max(256))
	return (255 << 24) | (r8 << 16) | (g8 << 8) | b8
}

generate_world :: proc(params: World_Params) -> ^World {
	rand.reset(params.seed)

	w := new(World)
	w.seed = params.seed
	w.chunk_width = params.chunk_width

	Chunk_Spec :: struct {
		count: int,
	}
	chunk_specs: [dynamic]Chunk_Spec
	defer delete(chunk_specs)

	// Chunk 0: lineup staging — player only, no NPCs.
	append(&chunk_specs, Chunk_Spec{count = 0})

	total := 0
	for total < params.target_population {
		n := rand_range(params.pop_min, params.pop_max)
		append(&chunk_specs, Chunk_Spec{count = n})
		total += n
	}

	if len(chunk_specs) % 2 != 0 {
		append(&chunk_specs, Chunk_Spec{count = 0})
	}

	w.chunk_count = len(chunk_specs)
	w.width = f32(w.chunk_count) * params.chunk_width
	w.chunks = make([]Chunk, w.chunk_count)

	spawn_count := 0
	for spec in chunk_specs {
		spawn_count += spec.count
	}

	w.spawn = make_soa_slice(#soa[]Spawn_Person, spawn_count) or_else panic("spawn alloc failed")

	person_i := 0
	for spec, idx in chunk_specs {
		x_min := f32(idx) * params.chunk_width
		x_max := x_min + params.chunk_width
		w.chunks[idx] = Chunk{
			index = idx,
			x_min = x_min,
			x_max = x_max,
			person_start = person_i,
			person_count = spec.count,
		}

		if idx == LINEUP_CHUNK_INDEX {
			continue
		}

		for _ in 0 ..< spec.count {
			margin := f32(PERSON_MARGIN)
			chunk_lo := x_min + margin
			chunk_hi := x_max - margin
			span := max(chunk_hi - chunk_lo, 8)
			chunk_hi = chunk_lo + span
			bound_min := chunk_lo + f32(rand.int_max(max(int(span * 0.5), 1)))
			bound_max := chunk_lo + f32(rand.int_max(max(int(span), 1)))
			bound_max = math.clamp(bound_max, bound_min + 8, chunk_hi)
			bound_min = math.max(bound_min, chunk_lo)

			pos_span := bound_max - bound_min
			pos_x: f32
			if pos_span < 1 {
				pos_x = bound_min
			} else {
				pos_x = bound_min + f32(rand.int_max(int(pos_span)))
			}
			age := roll_age()
			size_w, size_h := roll_size_for_age(age)
			pos_y := params.ground_y - size_h

			min_span := size_w + ROAM_MIN_EXTRA
			for bound_max - bound_min < min_span {
				grew := false
				if bound_max < chunk_hi {
					bound_max = math.min(bound_max + 1, chunk_hi)
					grew = true
				}
				if bound_max - bound_min >= min_span {
					break
				}
				if bound_min > chunk_lo {
					bound_min = math.max(bound_min - 1, chunk_lo)
					grew = true
				}
				if !grew {
					break
				}
			}
			if bound_max - bound_min < min_span {
				bound_min = chunk_lo
				bound_max = chunk_hi
			}
			legal_max := bound_max - size_w
			if legal_max >= bound_min {
				pos_x = math.clamp(pos_x, bound_min, legal_max)
			} else {
				pos_x = (bound_min + bound_max) * 0.5 - size_w * 0.5
			}

			w.spawn[person_i] = Spawn_Person{
				pos_x = pos_x,
				pos_y = pos_y,
				bound_min_x = bound_min,
				bound_max_x = bound_max,
				size_w = size_w,
				size_h = size_h,
				speed_scale = roll_speed_scale(),
				age = age,
				color = random_color(),
			}
			person_i += 1
		}
	}

	return w
}

free_world :: proc(w: ^World) {
	if w == nil {
		return
	}
	delete(w.chunks)
	delete(w.spawn)
	free(w)
}

when config.IS_DEBUG {
	// label_screen_px: on-screen size at zoom 1; world_zoom: g.camera.zoom (game world camera).
	debug_draw_chunks :: proc(
		w: ^World,
		ground: ^Ground,
		label_screen_px: i32,
		world_zoom: f32,
	) {
		if w == nil || ground == nil {
			return
		}
		label_font := max(i32(f32(label_screen_px) / world_zoom + 0.5), 1)
		for c in w.chunks {
			chunk_w := c.x_max - c.x_min
			rect := rl.Rectangle{c.x_min, ground.top_y, chunk_w, ground.size.y}
			outline := rl.Color{0, 220, 255, 220}
			if c.index % 2 != 0 {
				outline = rl.Color{255, 200, 64, 220}
			}
			rl.DrawRectangleLinesEx(rect, 1, outline)

			name := c.index == LINEUP_CHUNK_INDEX ? "lineup" : "chunk"
			label := fmt.ctprintf("%s id=%d #%d", name, c.index, c.person_count)
			tw := f32(rl.MeasureText(label, label_font))
			cx := c.x_min + chunk_w * 0.5
			tx := i32(cx - tw * 0.5)
			ty := i32(ground.top_y + 4)
			rl.DrawRectangle(tx - 1, ty - 1, i32(tw) + 2, label_font + 2, {0, 0, 0, 150})
			rl.DrawText(label, tx, ty, label_font, rl.WHITE)
		}
	}
}

package person

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../player"
import w "../world"

EPILOGUE_CHUNK_CROWD :: 0
EPILOGUE_CHUNK_GAP :: 1
EPILOGUE_LINEUP_MIN_X :: 48.0
EPILOGUE_CELEBRATE_DELAY_MAX :: 1.8
EPILOGUE_CELEBRATE_DELAY_NONE :: -1.0

epilogue_init_celebrate_delays :: proc(crowd_count: int) -> []f32 {
	delays := make([]f32, crowd_count)
	for i in 0 ..< crowd_count {
		delays[i] = EPILOGUE_CELEBRATE_DELAY_NONE
	}
	return delays
}

epilogue_begin_lineup_celebrate :: proc(p: ^People, i: int) {
	p.rows[i].motion.state = .Celebrating
	p.rows[i].motion.hop_step = 0
	p.rows[i].motion.hop_count = u8(
		CELEBRATE_HOP_MIN + (i % (CELEBRATE_HOP_MAX - CELEBRATE_HOP_MIN + 1)),
	)
	p.rows[i].motion.hop_timer = CELEBRATE_HOP_DURATION
}

celebrated_bit_bytes :: proc(crowd_count: int) -> int {
	return (crowd_count + 7) / 8
}

celebrated_get :: proc(bits: []u8, i: int) -> bool {
	if i < 0 || len(bits) == 0 {
		return false
	}
	return (bits[i / 8] >> u8(i % 8)) & 1 != 0
}

celebrated_set :: proc(bits: []u8, i: int) {
	if i < 0 || len(bits) == 0 {
		return
	}
	bits[i / 8] |= 1 << u8(i % 8)
}

epilogue_lineup_uncollided_count :: proc(p: ^People, bits: []u8) -> int {
	if p == nil {
		return 0
	}
	n := 0
	for i in 0 ..< p.crowd_count {
		if p.rows[i].motion.phase != .In_Lineup {
			continue
		}
		if celebrated_get(bits, i) {
			continue
		}
		n += 1
	}
	return n
}

epilogue_chunks_for_span :: proc(span_x, chunk_w: f32) -> int {
	if chunk_w <= 0 {
		return 1
	}
	return max(1, int(math.ceil(span_x / chunk_w)))
}

epilogue_apostle_row_x :: proc(world: ^w.World, apostle_chunk: int, apostle_slot: int, count: int) -> f32 {
	center := w.chunk_center_x(world, apostle_chunk)
	size_w: f32 = 23
	pitch: f32 = size_w + 32
	row_w := f32(max(count - 1, 0)) * pitch + size_w
	x0 := center - row_w * 0.5
	return x0 + f32(apostle_slot) * pitch
}

epilogue_layout :: proc(p: ^People, world: ^w.World, ground_y: f32) {
	if p == nil || world == nil || len(world.chunks) < 2 {
		return
	}
	p.epilogue_active = true
	p.lineup.next_slot = 0
	p.epilogue_apostle_chunk = EPILOGUE_CHUNK_CROWD + EPILOGUE_CHUNK_GAP + 1
	p.epilogue_spawn_chunk = p.epilogue_apostle_chunk + 1

	chunk0 := world.chunks[EPILOGUE_CHUNK_CROWD].x_min
	chunk_w := world.chunks[EPILOGUE_CHUNK_CROWD].x_max - chunk0
	inner := chunk_w - LINEUP_PAD * 2
	served_n := 0
	for i in 0 ..< p.crowd_count {
		if p.rows[i].food.served {
			served_n += 1
		}
	}
	pitch: f32 = LINEUP_SLOT_PITCH
	if served_n > 0 && f32(served_n) * pitch > inner {
		pitch = max(inner / f32(served_n), f32(6))
	}

	crowd_span := LINEUP_PAD * 2 + f32(served_n) * pitch
	crowd_chunks := epilogue_chunks_for_span(crowd_span, chunk_w)
	last_chunk := len(world.chunks) - 1
	apostle_chunk := crowd_chunks + EPILOGUE_CHUNK_GAP
	spawn_chunk := apostle_chunk + 1
	apostle_chunk = min(apostle_chunk, last_chunk)
	spawn_chunk = min(max(spawn_chunk, apostle_chunk + 1), last_chunk)
	p.epilogue_apostle_chunk = apostle_chunk
	p.epilogue_spawn_chunk = spawn_chunk

	lineup_start := chunk0 + LINEUP_PAD
	lineup_start = max(lineup_start, EPILOGUE_LINEUP_MIN_X)

	slot: int = 0
	for i in 0 ..< p.crowd_count {
		row := &p.rows[i]
		if row.food.served {
			y := ground_y - row.transform.size_h
			x :=
				lineup_start +
				f32(slot) * pitch +
				(pitch - row.transform.size_w) * 0.5
			row.nav.target_x = x
			row.nav.target_y = y
			row.nav.line_row = 0
			row.transform.pos_x = x
			row.transform.pos_y = y
			row.transform.base_y = y
			row.motion.phase = .In_Lineup
			row.motion.state = .Idle
			row.transform.dir = -1
			row.behavior.subbehavior = .None
			slot += 1
		} else {
			row.motion.phase = .Gone
			row.motion.state = .Idle
		}
	}

	apostle_seen: [APOSTLE_COUNT]bool
	for i in p.crowd_count ..< len(p.rows) {
		row := &p.rows[i]
		if row.identity.role != .Apostle {
			row.motion.phase = .Gone
			continue
		}
		a := int(row.identity.apostle_idx)
		if a < 0 || a >= APOSTLE_COUNT {
			row.motion.phase = .Gone
			continue
		}
		if apostle_seen[a] {
			row.motion.phase = .Gone
			continue
		}
		apostle_seen[a] = true
		pos_x := epilogue_apostle_row_x(world, apostle_chunk, a, APOSTLE_COUNT)
		pos_y := ground_y - row.transform.size_h
		row.transform.pos_x = pos_x
		row.transform.pos_y = pos_y
		row.transform.base_y = pos_y
		row.motion.phase = .In_Lineup
		row.motion.state = .Idle
		row.motion.timer = 9999
		row.transform.dir = -1
		row.perk.apostle_perk = .Follow
	}
}

epilogue_face_player :: proc(p: ^People, player_x: f32) {
	for i in 0 ..< len(p.rows) {
		row := &p.rows[i]
		if row.motion.phase != .In_Lineup {
			continue
		}
		if row.motion.state == .Celebrating {
			continue
		}
		pcx := row.transform.pos_x + row.transform.size_w * 0.5
		if player_x > pcx {
			row.transform.dir = 1
		} else if player_x < pcx {
			row.transform.dir = -1
		}
	}
}

epilogue_tick_celebrations :: proc(p: ^People, view: rl.Rectangle, frame: int, dt: f32) {
	for i in 0 ..< p.crowd_count {
		if p.rows[i].motion.phase == .Gone {
			continue
		}
		if p.rows[i].motion.state != .Celebrating {
			continue
		}
		pr := person_rect_at(p, i)
		visible := rl.CheckCollisionRecs(pr, view)
		if visible || (frame+i)%OFFSCREEN_UPDATE_INTERVAL == 0 {
			update_person_at(p, i, dt)
		}
	}
}

epilogue_queue_celebrate_touch :: proc(
	p: ^People,
	bits: []u8,
	delays: []f32,
	player: rl.Rectangle,
) {
	if len(delays) < p.crowd_count {
		return
	}
	for i in 0 ..< p.crowd_count {
		if p.rows[i].motion.phase != .In_Lineup {
			continue
		}
		if celebrated_get(bits, i) {
			continue
		}
		if delays[i] >= 0 {
			continue
		}
		if !rl.CheckCollisionRecs(player, person_rect_at(p, i)) {
			continue
		}
		delays[i] = rand.float32() * EPILOGUE_CELEBRATE_DELAY_MAX
	}
}

epilogue_tick_celebrate_delays :: proc(p: ^People, bits: []u8, delays: []f32, dt: f32) {
	if len(delays) < p.crowd_count {
		return
	}
	for i in 0 ..< p.crowd_count {
		if delays[i] < 0 {
			continue
		}
		delays[i] -= dt
		if delays[i] > 0 {
			continue
		}
		delays[i] = EPILOGUE_CELEBRATE_DELAY_NONE
		if celebrated_get(bits, i) {
			continue
		}
		if p.rows[i].motion.phase != .In_Lineup {
			continue
		}
		celebrated_set(bits, i)
		epilogue_begin_lineup_celebrate(p, i)
	}
}

epilogue_update_apostle_dialogue :: proc(
	p: ^People,
	apostle_rows: ^[APOSTLE_COUNT]int,
	plays: ^[APOSTLE_COUNT]Crowd_Apostle_Play,
	player: rl.Rectangle,
) {
	for a in 0 ..< APOSTLE_COUNT {
		plays[a].speech_timer = 0
		plays[a].speech_show_reqs = false
	}
	for a in 0 ..< APOSTLE_COUNT {
		i := apostle_rows[a]
		if i < 0 {
			continue
		}
		if !rl.CheckCollisionRecs(player, person_rect_at(p, i)) {
			continue
		}
		plays[a].speech_timer = 1
	}
}

epilogue_fill_apostle_rows :: proc(p: ^People, out: ^[APOSTLE_COUNT]int) {
	for a in 0 ..< APOSTLE_COUNT {
		out[a] = -1
	}
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.identity.role != .Apostle || row.motion.phase == .Gone {
			continue
		}
		a := int(row.identity.apostle_idx)
		if a >= 0 && a < APOSTLE_COUNT && out[a] < 0 {
			out[a] = i
		}
	}
}

epilogue_place_player_spawn :: proc(p: ^People, world: ^w.World, pl: ^player.Player) {
	if p == nil || world == nil || pl == nil {
		return
	}
	idx := p.epilogue_spawn_chunk
	if idx < 0 || idx >= len(world.chunks) {
		return
	}
	cx := w.chunk_center_x(world, idx)
	pl.pos.x = cx - pl.size.x * 0.5
}

epilogue_roam_max_x :: proc(p: ^People, world: ^w.World, player_w: f32) -> f32 {
	if p == nil || world == nil {
		return 0
	}
	idx := p.epilogue_spawn_chunk
	if idx < 0 || idx >= len(world.chunks) {
		return 0
	}
	return world.chunks[idx].x_max - player_w
}

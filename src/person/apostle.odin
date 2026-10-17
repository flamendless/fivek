package person

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import w "../world"

APOSTLE_COUNT :: 12
APOSTLE_CHUNK_INDEX :: w.LINEUP_CHUNK_INDEX
APOSTLE_X_FRAC_LO: f32 = 0.35
APOSTLE_X_FRAC_HI: f32 = 0.75
PARTY_GAP_BEHIND_PLAYER :: 8.0
PARTY_MEMBER_GAP :: 2.0
PARTY_TRAIL_MIN_STEP :: 2.0
REJECT_FLASH_DURATION :: 0.4
APOSTLE_LABEL_FONT :: 8
BUBBLE_PAD :: 3.0

Apostle_Def :: struct {
	name: cstring,
	color: rl.Color,
	required_served: u16,
}

APOSTLE_DEFS: [APOSTLE_COUNT]Apostle_Def = {
	{"Peter", {220, 60, 60, 255}, 2},
	{"Andrew", {230, 120, 50, 255}, 4},
	{"James", {230, 190, 40, 255}, 5},
	{"John", {180, 210, 50, 255}, 6},
	{"Philip", {80, 180, 70, 255}, 7},
	{"Bartholomew", {50, 170, 150, 255}, 8},
	{"Thomas", {60, 190, 220, 255}, 9},
	{"Matthew", {70, 110, 220, 255}, 10},
	{"Jude", {90, 80, 200, 255}, 12},
	{"Thaddaeus", {150, 80, 200, 255}, 14},
	{"Simon", {200, 70, 180, 255}, 16},
	{"Judas", {140, 30, 40, 255}, 24},
}

apostle_bit_bytes :: proc() -> int {
	return 2
}

apostle_bit_get :: proc(bits: []u8, idx: int) -> bool {
	if idx < 0 || idx >= APOSTLE_COUNT || len(bits) < apostle_bit_bytes() {
		return false
	}
	return (bits[idx / 8] >> u8(idx % 8)) & 1 != 0
}

apostle_bit_set :: proc(bits: []u8, idx: int) {
	if idx < 0 || idx >= APOSTLE_COUNT || len(bits) < apostle_bit_bytes() {
		return
	}
	bits[idx / 8] |= 1 << u8(idx % 8)
}

count_crowd_served :: proc(p: ^People) -> int {
	return count_served(p)
}

spawn_apostles :: proc(p: ^People, chunk_width: f32, ground_y: f32) {
	old_n := len(p.rows)
	new_n := old_n + APOSTLE_COUNT
	new_rows := make_soa_slice(#soa[]Person, new_n) or_else panic("apostle rows alloc failed")
	for i in 0 ..< old_n {
		new_rows[i] = p.rows[i]
	}
	delete(p.rows)
	p.rows = new_rows

	x_base := f32(APOSTLE_CHUNK_INDEX) * chunk_width
	span := APOSTLE_X_FRAC_HI - APOSTLE_X_FRAC_LO
	size_w: f32 = 23
	size_h: f32 = 34

	for a in 0 ..< APOSTLE_COUNT {
		frac := APOSTLE_X_FRAC_LO + span * f32(a) / f32(APOSTLE_COUNT - 1)
		pos_x := x_base + chunk_width * frac - size_w * 0.5
		pos_y := ground_y - size_h
		def := APOSTLE_DEFS[a]
		i := old_n + a
		p.rows[i] = Person{
			pos_x = pos_x,
			pos_y = pos_y,
			size_w = size_w,
			size_h = size_h,
			base_y = pos_y,
			bound_min_x = pos_x,
			bound_max_x = pos_x,
			state = .Idle,
			phase = .Active,
			age = .Adult,
			timer = 9999,
			dir = 1,
			speed_scale = 1,
			color = def.color,
			role = .Apostle,
			apostle_idx = u8(a),
			required_served = def.required_served,
			party_slot = -1,
		}
	}
}

begin_apostle_follow :: proc(p: ^People, person_i: int) {
	row := &p.rows[person_i]
	if row.role != .Apostle || row.phase == .Following {
		return
	}
	row.party_slot = p.party_count
	p.party_count += 1
	row.phase = .Following
	row.state = .Idle
	row.subbehavior = .None
}

finish_apostle_celebrate :: proc(p: ^People, i: int) {
	p.rows[i].pos_y = p.rows[i].base_y
	p.rows[i].hop_step = 0
	begin_apostle_follow(p, i)
}

is_apostle_interactable :: proc(p: ^People, i: int) -> bool {
	if i < 0 || i >= len(p.rows) {
		return false
	}
	row := p.rows[i]
	return row.role == .Apostle &&
		row.phase == .Active &&
		row.state != .Celebrating &&
		row.subbehavior == .None
}

nearest_apostle_interact_index :: proc(
	p: ^People,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
) -> int {
	best := -1
	best_dist := radius
	player_cx := player_pos.x + player_size.x * 0.5
	player_cy := player_pos.y + player_size.y * 0.5

	for i in 0 ..< len(p.rows) {
		if !is_apostle_interactable(p, i) {
			continue
		}
		if !player_in_interact_range(p, i, player_pos, player_size, radius) {
			continue
		}
		cx := p.rows[i].pos_x + p.rows[i].size_w * 0.5
		cy := p.rows[i].pos_y + p.rows[i].size_h * 0.5
		dx := cx - player_cx
		dy := cy - player_cy
		d := math.sqrt(dx * dx + dy * dy)
		if d < best_dist {
			best_dist = d
			best = i
		}
	}
	return best
}

try_interact_apostle :: proc(
	p: ^People,
	at: rl.Vector2,
	player_size: rl.Vector2,
	radius: f32,
) -> int {
	best := nearest_apostle_interact_index(p, at, player_size, radius)
	if best < 0 {
		return -1
	}
	served := count_crowd_served(p)
	if served < int(p.rows[best].required_served) {
		p.rows[best].reject_flash = REJECT_FLASH_DURATION
		return best
	}
	p.rows[best].subbehavior = .None
	begin_celebrating(p, best)
	return best
}

sync_apostle_bits :: proc(p: ^People, bits: []u8) {
	if len(bits) < apostle_bit_bytes() {
		return
	}
	for i in 0 ..< apostle_bit_bytes() {
		bits[i] = 0
	}
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.role == .Apostle && row.phase == .Following {
			apostle_bit_set(bits, int(row.apostle_idx))
		}
	}
}

apply_apostle_bits :: proc(p: ^People, bits: []u8) {
	if len(bits) < apostle_bit_bytes() {
		return
	}
	p.party_count = 0
	for a in 0 ..< APOSTLE_COUNT {
		if !apostle_bit_get(bits, a) {
			continue
		}
		for i in p.crowd_count ..< len(p.rows) {
			if p.rows[i].role == .Apostle && int(p.rows[i].apostle_idx) == a {
				begin_apostle_follow(p, i)
				break
			}
		}
	}
}

tick_apostle_reject_flash :: proc(p: ^People, dt: f32) {
	for i in p.crowd_count ..< len(p.rows) {
		if p.rows[i].reject_flash > 0 {
			p.rows[i].reject_flash -= dt
		}
	}
}

apostle_follow_index_by_slot :: proc(p: ^People, slot: int) -> int {
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.phase == .Following && row.party_slot == slot {
			return i
		}
	}
	return -1
}

push_party_trail :: proc(p: ^People, x: f32) {
	if p.party_trail_count > 0 {
		if math.abs(x - p.party_trail_x[p.party_trail_head]) < PARTY_TRAIL_MIN_STEP {
			return
		}
	}
	p.party_trail_head = (p.party_trail_head + 1) % PARTY_TRAIL_CAP
	p.party_trail_x[p.party_trail_head] = x
	if p.party_trail_count < PARTY_TRAIL_CAP {
		p.party_trail_count += 1
	}
}

bootstrap_party_trail :: proc(p: ^People, x: f32) {
	for k in 0 ..< 32 {
		p.party_trail_x[k] = x
	}
	p.party_trail_head = 31
	p.party_trail_count = 32
}

party_trail_x_at_dist :: proc(p: ^People, start_x: f32, dist: f32) -> f32 {
	if p.party_trail_count == 0 {
		return start_x - dist
	}
	remaining := dist
	cur := start_x
	idx := p.party_trail_head
	head_x := p.party_trail_x[idx]
	seg := math.abs(cur - head_x)
	if seg > 0 {
		if remaining <= seg {
			if cur > head_x {
				return cur - remaining
			}
			return cur + remaining
		}
		remaining -= seg
		cur = head_x
	}
	for _ in 0 ..< p.party_trail_count - 1 {
		prev := (idx - 1 + PARTY_TRAIL_CAP) % PARTY_TRAIL_CAP
		prev_x := p.party_trail_x[prev]
		seg := math.abs(cur - prev_x)
		if seg <= 0 {
			idx = prev
			cur = prev_x
			continue
		}
		if remaining <= seg {
			if cur > prev_x {
				return cur - remaining
			}
			return cur + remaining
		}
		remaining -= seg
		idx = prev
		cur = prev_x
	}
	return cur
}

party_slot_leash :: proc(p: ^People, slot: int, player_w: f32) -> f32 {
	i := apostle_follow_index_by_slot(p, slot)
	if i < 0 {
		return PARTY_GAP_BEHIND_PLAYER
	}
	w := p.rows[i].size_w
	if slot == 0 {
		return PARTY_GAP_BEHIND_PLAYER + player_w * 0.5 + w * 0.5
	}
	prev_i := apostle_follow_index_by_slot(p, slot - 1)
	if prev_i < 0 {
		return PARTY_GAP_BEHIND_PLAYER + player_w * 0.5 + w * 0.5
	}
	prev_w := p.rows[prev_i].size_w
	return party_slot_leash(p, slot - 1, player_w) + prev_w * 0.5 + PARTY_MEMBER_GAP + w * 0.5
}

move_follower_toward_x :: proc(p: ^People, i: int, target_x: f32, speed: f32, dt: f32) {
	p.rows[i].target_x = target_x
	p.rows[i].target_y = p.rows[i].base_y
	dx := target_x - p.rows[i].pos_x
	if math.abs(dx) < 1 {
		p.rows[i].pos_x = target_x
	} else if dx < 0 {
		p.rows[i].dir = -1
		p.rows[i].pos_x -= speed * dt
		if p.rows[i].pos_x < target_x {
			p.rows[i].pos_x = target_x
		}
	} else {
		p.rows[i].dir = 1
		p.rows[i].pos_x += speed * dt
		if p.rows[i].pos_x > target_x {
			p.rows[i].pos_x = target_x
		}
	}
	p.rows[i].pos_y = p.rows[i].base_y
}

update_apostle_follow :: proc(
	p: ^People,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
	dt: f32,
) {
	if p.party_count == 0 {
		p.party_trail_count = 0
		return
	}
	speed: f32 = RUN_SPEED * POST_SERVE_SPEED_MULT
	player_cx := player_pos.x + player_size.x * 0.5
	if p.party_trail_count == 0 {
		bootstrap_party_trail(p, player_cx)
	}
	push_party_trail(p, player_cx)

	for slot in 0 ..< p.party_count {
		i := apostle_follow_index_by_slot(p, slot)
		if i < 0 {
			continue
		}
		leash := party_slot_leash(p, slot, player_size.x)
		target_cx := party_trail_x_at_dist(p, player_cx, leash)
		target_x := target_cx - p.rows[i].size_w * 0.5
		move_follower_toward_x(p, i, target_x, speed, dt)
	}
}

draw_apostle_overlays :: proc(
	p: ^People,
	view: rl.Rectangle,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
) {
	player_rect := rl.Rectangle{player_pos.x, player_pos.y, player_size.x, player_size.y}
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.role != .Apostle || row.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		if row.phase == .Active &&
		   is_apostle_interactable(p, i) &&
		   rl.CheckCollisionRecs(player_rect, pr) {
			def := APOSTLE_DEFS[int(row.apostle_idx)]
			cx := row.pos_x + row.size_w * 0.5
			label := fmt.ctprintf("%s: needs %d served", def.name, row.required_served)
			font: i32 = APOSTLE_LABEL_FONT
			tw := f32(rl.MeasureText(label, font))
			bubble_w := tw + BUBBLE_PAD * 2
			bubble_h := f32(font) + BUBBLE_PAD * 2
			bx := cx - bubble_w * 0.5
			by := row.pos_y - bubble_h - 4
			rl.DrawRectangleRec({bx, by, bubble_w, bubble_h}, {255, 255, 255, 230})
			rl.DrawRectangleLinesEx({bx, by, bubble_w, bubble_h}, 1, {40, 40, 40, 255})
			rl.DrawText(label, i32(bx + BUBBLE_PAD), i32(by + BUBBLE_PAD), font, {20, 20, 20, 255})
		}
	}
}

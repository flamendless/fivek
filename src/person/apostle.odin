package person

import "core:math"
import rl "vendor:raylib"
import "../config"
import w "../world"

APOSTLE_COUNT :: 12
APOSTLE_CHUNK_INDEX :: w.LINEUP_CHUNK_INDEX
APOSTLE_X_FRAC_LO: f32 = 0.35
APOSTLE_X_FRAC_HI: f32 = 0.75
PARTY_GAP_BEHIND_PLAYER :: 8.0
PARTY_MEMBER_GAP :: 2.0
PARTY_TRAIL_MIN_STEP :: 2.0
PETER_APOSTLE_IDX :: 0
THOMAS_APOSTLE_IDX :: 6
JUDAS_APOSTLE_IDX :: 11
APOSTLE_LABEL_FONT :: 8
BUBBLE_PAD :: 3.0
REQ_NUM_GAP :: 4.0

spawn_apostles :: proc(p: ^People, seed: u64, chunk_width: f32, ground_y: f32) {
	for a in 0 ..< APOSTLE_COUNT {
		p.apostle_requirements[a] = roll_apostle_requirements(seed, a)
		p.apostle_reject_speech[a] = roll_apostle_reject_speech(seed, a)
	}
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
			transform = {
				pos_x = pos_x,
				pos_y = pos_y,
				size_w = size_w,
				size_h = size_h,
				base_y = pos_y,
				bound_min_x = pos_x,
				bound_max_x = pos_x,
				dir = 1,
			},
			motion = {
				state = .Idle,
				phase = .Active,
				timer = 9999,
			},
			traits = {
				age = .Adult,
				speed_scale = 1,
				color = def.color,
				draw_alpha = 1,
			},
			identity = {
				role = .Apostle,
				apostle_idx = u8(a),
				party_slot = -1,
			},
		}
	}
}

spawn_apostles_lineup_center :: proc(p: ^People, seed: u64, screen_w: f32, ground_y: f32, count: int) {
	for a in 0 ..< APOSTLE_COUNT {
		p.apostle_requirements[a] = roll_apostle_requirements(seed, a)
		p.apostle_reject_speech[a] = roll_apostle_reject_speech(seed, a)
	}
	n := count
	if n <= 0 {
		n = APOSTLE_COUNT
	}
	n = min(n, APOSTLE_COUNT)
	old_n := len(p.rows)
	new_n := old_n + n
	new_rows := make_soa_slice(#soa[]Person, new_n) or_else panic("apostle rows alloc failed")
	for i in 0 ..< old_n {
		new_rows[i] = p.rows[i]
	}
	delete(p.rows)
	p.rows = new_rows

	size_w: f32 = 23
	size_h: f32 = 34
	pitch: f32 = size_w + 32
	row_w := f32(max(n - 1, 0)) * pitch + size_w
	edge_margin: f32 = 72
	x0 := (screen_w - row_w) * 0.5
	x0 = math.clamp(x0, edge_margin, max(screen_w - edge_margin - row_w, edge_margin))
	pos_y := ground_y - size_h

	for a in 0 ..< n {
		def := APOSTLE_DEFS[a]
		i := old_n + a
		pos_x := x0 + f32(a) * pitch
		p.rows[i] = Person{
			transform = {
				pos_x = pos_x,
				pos_y = pos_y,
				size_w = size_w,
				size_h = size_h,
				base_y = pos_y,
				bound_min_x = pos_x,
				bound_max_x = pos_x,
				dir = 1,
			},
			motion = {
				state = .Idle,
				phase = .Active,
				timer = 9999,
			},
			traits = {
				age = .Adult,
				speed_scale = 1,
				color = def.color,
				draw_alpha = 1,
			},
			identity = {
				role = .Apostle,
				apostle_idx = u8(a),
				party_slot = -1,
			},
		}
	}
}

begin_apostle_follow :: proc(p: ^People, person_i: int) {
	row := &p.rows[person_i]
	if row.identity.role != .Apostle || row.motion.phase == .Following {
		return
	}
	row.identity.party_slot = p.party.count
	p.party.count += 1
	row.motion.phase = .Following
	row.motion.state = .Idle
	row.behavior.subbehavior = .None
	init_apostle_perk_on_follow(p, person_i)
}

finish_apostle_celebrate :: proc(p: ^People, i: int) {
	p.rows[i].transform.pos_y = p.rows[i].transform.base_y
	p.rows[i].motion.hop_step = 0
	begin_apostle_follow(p, i)
}

is_apostle_interactable :: proc(p: ^People, i: int) -> bool {
	if i < 0 || i >= len(p.rows) {
		return false
	}
	row := p.rows[i]
	return row.identity.role == .Apostle &&
		row.motion.phase == .Active &&
		row.motion.state != .Celebrating &&
		row.behavior.subbehavior == .None
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
		cx := p.rows[i].transform.pos_x + p.rows[i].transform.size_w * 0.5
		cy := p.rows[i].transform.pos_y + p.rows[i].transform.size_h * 0.5
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
	available: Run_Stats,
	pledged: ^Run_Stats,
) -> (person_i: int, pledged_now: bool) {
	best := nearest_apostle_interact_index(p, at, player_size, radius)
	if best < 0 {
		return -1, false
	}
	idx := int(p.rows[best].identity.apostle_idx)
	reqs := p.apostle_requirements[idx]
	if !requirements_met(available, reqs) {
		p.rows[best].behavior.reject_speech_show = true
		return best, false
	}
	p.rows[best].behavior.reject_speech_show = false
	pledge_requirements(pledged, reqs)
	p.rows[best].behavior.subbehavior = .None
	begin_celebrating(p, best)
	return best, true
}

pledged_floor_from_party :: proc(p: ^People, bits: []u8) -> Run_Stats {
	out: Run_Stats
	if len(bits) < apostle_bit_bytes() {
		return out
	}
	for a in 0 ..< APOSTLE_COUNT {
		if !apostle_bit_get(bits, a) {
			continue
		}
		pledge_requirements(&out, p.apostle_requirements[a])
	}
	return out
}

sync_stats_pledged_floor :: proc(p: ^People, bits: []u8, pledged: ^Run_Stats) {
	floor := pledged_floor_from_party(p, bits)
	for k in Stat_Kind {
		fv := stat_value(floor, k)
		if stat_value(pledged^, k) < fv {
			stat_set(pledged, k, fv)
		}
	}
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
		if row.identity.role == .Apostle && row.motion.phase == .Following {
			apostle_bit_set(bits, int(row.identity.apostle_idx))
		}
	}
}

apply_apostle_bits :: proc(p: ^People, bits: []u8) {
	if len(bits) < apostle_bit_bytes() {
		return
	}
	p.party.count = 0
	for a in 0 ..< APOSTLE_COUNT {
		if !apostle_bit_get(bits, a) {
			continue
		}
		for i in p.crowd_count ..< len(p.rows) {
			if p.rows[i].identity.role == .Apostle && int(p.rows[i].identity.apostle_idx) == a {
				begin_apostle_follow(p, i)
				break
			}
		}
	}
}

tick_apostle_reject_speech :: proc(p: ^People, player_pos: rl.Vector2, player_size: rl.Vector2) {
	player_rect := rl.Rectangle{player_pos.x, player_pos.y, player_size.x, player_size.y}
	for i in p.crowd_count ..< len(p.rows) {
		if !p.rows[i].behavior.reject_speech_show {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(player_rect, pr) {
			p.rows[i].behavior.reject_speech_show = false
		}
	}
}

apostle_follow_index_by_slot :: proc(p: ^People, slot: int) -> int {
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.motion.phase == .Following && row.identity.party_slot == slot {
			return i
		}
	}
	return -1
}

judas_in_party :: proc(p: ^People) -> bool {
	for slot in 0 ..< p.party.count {
		i := apostle_follow_index_by_slot(p, slot)
		if i >= 0 && p.rows[i].identity.apostle_idx == JUDAS_APOSTLE_IDX {
			return true
		}
	}
	return false
}

push_party_trail :: proc(p: ^People, x: f32) {
	if p.party.trail_count > 0 {
		if math.abs(x - p.party.trail_x[p.party.trail_head]) < PARTY_TRAIL_MIN_STEP {
			return
		}
	}
	p.party.trail_head = (p.party.trail_head + 1) % PARTY_TRAIL_CAP
	p.party.trail_x[p.party.trail_head] = x
	if p.party.trail_count < PARTY_TRAIL_CAP {
		p.party.trail_count += 1
	}
}

bootstrap_party_trail :: proc(p: ^People, x: f32) {
	for k in 0 ..< 32 {
		p.party.trail_x[k] = x
	}
	p.party.trail_head = 31
	p.party.trail_count = 32
}

party_trail_x_at_dist :: proc(p: ^People, start_x: f32, dist: f32) -> f32 {
	if p.party.trail_count == 0 {
		return start_x - dist
	}
	remaining := dist
	cur := start_x
	idx := p.party.trail_head
	head_x := p.party.trail_x[idx]
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
	for _ in 0 ..< p.party.trail_count - 1 {
		prev := (idx - 1 + PARTY_TRAIL_CAP) % PARTY_TRAIL_CAP
		prev_x := p.party.trail_x[prev]
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
	w := p.rows[i].transform.size_w
	if slot == 0 {
		return PARTY_GAP_BEHIND_PLAYER + player_w * 0.5 + w * 0.5
	}
	prev_i := apostle_follow_index_by_slot(p, slot - 1)
	if prev_i < 0 {
		return PARTY_GAP_BEHIND_PLAYER + player_w * 0.5 + w * 0.5
	}
	prev_w := p.rows[prev_i].transform.size_w
	return party_slot_leash(p, slot - 1, player_w) + prev_w * 0.5 + PARTY_MEMBER_GAP + w * 0.5
}

move_follower_toward_x :: proc(p: ^People, i: int, target_x: f32, speed: f32, dt: f32) {
	p.rows[i].nav.target_x = target_x
	p.rows[i].nav.target_y = p.rows[i].transform.base_y
	dx := target_x - p.rows[i].transform.pos_x
	if math.abs(dx) < 1 {
		p.rows[i].transform.pos_x = target_x
	} else if dx < 0 {
		p.rows[i].transform.dir = -1
		p.rows[i].transform.pos_x -= speed * dt
		if p.rows[i].transform.pos_x < target_x {
			p.rows[i].transform.pos_x = target_x
		}
	} else {
		p.rows[i].transform.dir = 1
		p.rows[i].transform.pos_x += speed * dt
		if p.rows[i].transform.pos_x > target_x {
			p.rows[i].transform.pos_x = target_x
		}
	}
	p.rows[i].transform.pos_y = p.rows[i].transform.base_y
}

update_apostle_follow :: proc(
	p: ^People,
	ctx: Apostle_Perk_Ctx,
	dt: f32,
) {
	if p.party.count == 0 {
		p.party.trail_count = 0
		return
	}
	tick_apostle_party(p, ctx, dt)

	speed: f32 = RUN_SPEED * POST_SERVE_SPEED_MULT
	player_cx := ctx.player_pos.x + ctx.player_size.x * 0.5
	if p.party.trail_count == 0 {
		bootstrap_party_trail(p, player_cx)
	}
	push_party_trail(p, player_cx)

	for slot in 0 ..< p.party.count {
		i := apostle_follow_index_by_slot(p, slot)
		if i < 0 {
			continue
		}
		if !apostle_uses_trail(p.rows[i].perk.apostle_perk) {
			continue
		}
		leash := party_slot_leash(p, slot, ctx.player_size.x)
		target_cx := party_trail_x_at_dist(p, player_cx, leash)
		target_x := target_cx - p.rows[i].transform.size_w * 0.5
		move_follower_toward_x(p, i, target_x, speed, dt)
	}
}

when config.IS_DEBUG {
	debug_recruit_nearest_apostle :: proc(
		p: ^People,
		at: rl.Vector2,
		player_size: rl.Vector2,
		radius: f32,
	) -> bool {
		best := nearest_apostle_interact_index(p, at, player_size, radius)
		if best < 0 {
			return false
		}
		p.rows[best].behavior.subbehavior = .None
		begin_celebrating(p, best)
		return true
	}
}

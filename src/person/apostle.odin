package person

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../config"
import "../food"
import "../ui"
import "../theme"
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
REQ_NUM_GAP :: 4.0
JUDAS_APOSTLE_IDX :: 11

Apostle_Def :: struct {
	name: cstring,
	color: rl.Color,
}

Req_Tier :: enum {
	Low,
	High,
	Judas,
}

Apostle_Rng :: struct {
	state: u64,
}

APOSTLE_DEFS: [APOSTLE_COUNT]Apostle_Def = {
	{"Peter", theme.APOSTLE_IDENTITY_COLORS[0]},
	{"Andrew", theme.APOSTLE_IDENTITY_COLORS[1]},
	{"James", theme.APOSTLE_IDENTITY_COLORS[2]},
	{"John", theme.APOSTLE_IDENTITY_COLORS[3]},
	{"Philip", theme.APOSTLE_IDENTITY_COLORS[4]},
	{"Bartholomew", theme.APOSTLE_IDENTITY_COLORS[5]},
	{"Thomas", theme.APOSTLE_IDENTITY_COLORS[6]},
	{"Matthew", theme.APOSTLE_IDENTITY_COLORS[7]},
	{"Jude", theme.APOSTLE_IDENTITY_COLORS[8]},
	{"Thaddaeus", theme.APOSTLE_IDENTITY_COLORS[9]},
	{"Simon", theme.APOSTLE_IDENTITY_COLORS[10]},
	{"Judas", theme.APOSTLE_IDENTITY_COLORS[11]},
}

apostle_rng_init :: proc(seed: u64) -> Apostle_Rng {
	return {state = seed != 0 ? seed : 1}
}

apostle_rng_u32 :: proc(r: ^Apostle_Rng) -> u32 {
	r.state = r.state * 6364136223846793005 + 1
	return u32(r.state >> 32)
}

roll_u32_inclusive :: proc(r: ^Apostle_Rng, lo, hi: u32) -> u32 {
	if hi <= lo {
		return lo
	}
	span := hi - lo + 1
	return lo + apostle_rng_u32(r) % span
}

roll_stat_amount :: proc(r: ^Apostle_Rng, kind: Stat_Kind, tier: Req_Tier) -> u32 {
	switch kind {
	case .Total_Served:
		switch tier {
		case .Low:
			return roll_u32_inclusive(r, 80, 200)
		case .High:
			return roll_u32_inclusive(r, 250, 600)
		case .Judas:
			return roll_u32_inclusive(r, 1800, 3500)
		}
	case .Fish_Given, .Bread_Given:
		switch tier {
		case .Low:
			return roll_u32_inclusive(r, 60, 180)
		case .High:
			return roll_u32_inclusive(r, 200, 500)
		case .Judas:
			return roll_u32_inclusive(r, 500, 1000)
		}
	case .Fed_Kids:
		switch tier {
		case .Low:
			return roll_u32_inclusive(r, 40, 120)
		case .High:
			return roll_u32_inclusive(r, 150, 350)
		case .Judas:
			return roll_u32_inclusive(r, 700, 1200)
		}
	case .Fed_Young:
		switch tier {
		case .Low:
			return roll_u32_inclusive(r, 30, 100)
		case .High:
			return roll_u32_inclusive(r, 120, 280)
		case .Judas:
			return roll_u32_inclusive(r, 500, 900)
		}
	case .Fed_Adults:
		switch tier {
		case .Low:
			return roll_u32_inclusive(r, 50, 150)
		case .High:
			return roll_u32_inclusive(r, 200, 450)
		case .Judas:
			return roll_u32_inclusive(r, 800, 1500)
		}
	case .Distance_Walked:
		switch tier {
		case .Low:
			return roll_u32_inclusive(r, 3000, 8000)
		case .High:
			return roll_u32_inclusive(r, 10000, 25000)
		case .Judas:
			return roll_u32_inclusive(r, 40000, 80000)
		}
	}
	return 0
}

pick_distinct_kinds :: proc(r: ^Apostle_Rng, n: int) -> [STAT_KIND_COUNT]Stat_Kind {
	all := [STAT_KIND_COUNT]Stat_Kind {
		.Total_Served,
		.Fish_Given,
		.Bread_Given,
		.Fed_Kids,
		.Fed_Young,
		.Fed_Adults,
		.Distance_Walked,
	}
	for i in 0 ..< STAT_KIND_COUNT {
		j := i + int(apostle_rng_u32(r) % u32(STAT_KIND_COUNT - i))
		all[i], all[j] = all[j], all[i]
	}
	out: [STAT_KIND_COUNT]Stat_Kind
	for i in 0 ..< n {
		out[i] = all[i]
	}
	return out
}

roll_apostle_requirements :: proc(seed: u64, slot: int) -> Apostle_Requirements {
	mix := u64(slot + 1) * 0x9E3779B97F4A7C15
	rng := apostle_rng_init(seed ~ mix)
	out: Apostle_Requirements

	if slot == JUDAS_APOSTLE_IDX {
		kinds := pick_distinct_kinds(&rng, STAT_KIND_COUNT)
		for i in 0 ..< STAT_KIND_COUNT {
			out.reqs[i] = Apostle_Req {
				kind = kinds[i],
				amount = roll_stat_amount(&rng, kinds[i], .Judas),
			}
		}
		out.count = u8(STAT_KIND_COUNT)
		return out
	}

	two_req := apostle_rng_u32(&rng) % 2 == 0
	tier := two_req ? Req_Tier.Low : Req_Tier.High
	n := two_req ? 2 : 1
	kinds := pick_distinct_kinds(&rng, n)
	for i in 0 ..< n {
		out.reqs[i] = Apostle_Req {
			kind = kinds[i],
			amount = roll_stat_amount(&rng, kinds[i], tier),
		}
	}
	out.count = u8(n)
	return out
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

spawn_apostles :: proc(p: ^People, seed: u64, chunk_width: f32, ground_y: f32) {
	for a in 0 ..< APOSTLE_COUNT {
		p.apostle_requirements[a] = roll_apostle_requirements(seed, a)
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
		p.rows[best].behavior.reject_flash = REJECT_FLASH_DURATION
		return best, false
	}
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

tick_apostle_reject_flash :: proc(p: ^People, dt: f32) {
	for i in p.crowd_count ..< len(p.rows) {
		if p.rows[i].behavior.reject_flash > 0 {
			p.rows[i].behavior.reject_flash -= dt
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

apostle_req_row_width :: proc(kind: Stat_Kind, avail: u32, req: u32, font: i32) -> f32 {
	symbol_w := stat_symbol_width(kind, font)
	nums := stat_req_numbers(avail, req)
	return symbol_w + REQ_NUM_GAP + f32(rl.MeasureText(nums, font))
}

draw_apostle_overlays :: proc(
	p: ^People,
	view: rl.Rectangle,
	player_pos: rl.Vector2,
	player_size: rl.Vector2,
	available: Run_Stats,
) {
	player_rect := rl.Rectangle{player_pos.x, player_pos.y, player_size.x, player_size.y}
	font: i32 = APOSTLE_LABEL_FONT
	line_gap: f32 = 1
	title_h := f32(font)
	req_row_h := math.max(title_h, ui.UI_ICON_DRAW_SIZE)

	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.identity.role != .Apostle || row.motion.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		if row.motion.phase == .Active &&
		   is_apostle_interactable(p, i) &&
		   rl.CheckCollisionRecs(player_rect, pr) {
			def := APOSTLE_DEFS[int(row.identity.apostle_idx)]
			reqs := p.apostle_requirements[int(row.identity.apostle_idx)]
			cx := row.transform.pos_x + row.transform.size_w * 0.5

			idx := int(row.identity.apostle_idx)
			bonus_kind := apostle_bonus_kind(idx)
			bonus_line: cstring = ""
			if bonus_kind != .None {
				bonus_line = fmt.ctprintf("Bonus: %s", apostle_bonus_label(bonus_kind))
			}

			title := fmt.ctprintf("%s:", def.name)
			tw := f32(rl.MeasureText(title, font))
			if bonus_line != "" {
				bw := f32(rl.MeasureText(bonus_line, font))
				if bw > tw {
					tw = bw
				}
			}
			n := int(reqs.count)
			for j in 0 ..< n {
				r := reqs.reqs[j]
				avail := stat_value(available, r.kind)
				rw := apostle_req_row_width(r.kind, avail, r.amount, font)
				if rw > tw {
					tw = rw
				}
			}
			bubble_w := tw + BUBBLE_PAD * 2
			bubble_h := BUBBLE_PAD + title_h + line_gap + f32(n) * req_row_h
			if n > 0 {
				bubble_h += f32(n - 1) * line_gap
			}
			if bonus_line != "" {
				bubble_h += line_gap + title_h
			}
			bubble_h += BUBBLE_PAD
			bx := cx - bubble_w * 0.5
			by := row.transform.pos_y - bubble_h - 4
			rl.DrawRectangleRec({bx, by, bubble_w, bubble_h}, theme.BUBBLE_FILL)
			rl.DrawRectangleLinesEx({bx, by, bubble_w, bubble_h}, 1, theme.BUBBLE_BORDER)

			content_x := bx + BUBBLE_PAD
			ty := by + BUBBLE_PAD
			rl.DrawText(title, i32(content_x), i32(ty), font, theme.TEXT_INK)
			ty += title_h + line_gap
			if bonus_line != "" {
				rl.DrawText(bonus_line, i32(content_x), i32(ty), font, theme.REQ_MET)
				ty += title_h + line_gap
			}

			for j in 0 ..< n {
				r := reqs.reqs[j]
				avail := stat_value(available, r.kind)
				symbol_w := stat_symbol_width(r.kind, font)
				draw_stat_symbol(r.kind, content_x, ty, req_row_h, font, theme.TEXT_INK)
				nums := stat_req_numbers(avail, r.amount)
				num_col :=
					stat_req_met(avail, r.amount) ? theme.REQ_MET : theme.REQ_SHORT
				num_ty := i32(ty + req_row_h) - font
				rl.DrawText(nums, i32(content_x + symbol_w + REQ_NUM_GAP), num_ty, font, num_col)
				ty += req_row_h + line_gap
			}
		}
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

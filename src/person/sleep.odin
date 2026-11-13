package person

import "core:math/rand"

SLEEP_CHUNK_PERCENT :: 15
SLEEP_ON_IDLE_ENTER_CHANCE :: 10
SLEEP_COUNT_MIN :: 1
SLEEP_COUNT_MAX :: 3

FIRST_GIVE_EMOTE_CHANCE_MIN :: 15
FIRST_GIVE_EMOTE_CHANCE_MAX :: 25
REACTION_EMOTE_DURATION :: 1.5
EMOTE_HEAD_TOP_FRAC :: 0.1
EMOTE_TAIL_GAP :: 1.0

WAKE_EMOTE_FADE :: 0.5
WAKE_EMOTE_SHAKE :: 0.3
SLEEP_EMOTE_SWAY_DEG :: 10.0
SLEEP_EMOTE_SWAY_SPEED :: 3.2

person_chunk_index :: proc(p: ^People, i: int) -> int {
	if p.lineup.chunk_width <= 0 {
		return 0
	}
	cx := p.rows[i].transform.pos_x + p.rows[i].transform.size_w * 0.5
	idx := int(cx / p.lineup.chunk_width)
	if idx < 0 {
		return 0
	}
	return idx
}

chunk_sleep_cap :: proc(crowd_in_chunk: int) -> int {
	if crowd_in_chunk <= 0 {
		return 0
	}
	return (crowd_in_chunk * SLEEP_CHUNK_PERCENT + 99) / 100
}

count_chunk_sleepers :: proc(p: ^People, chunk_idx: int) -> int {
	n := 0
	for i in 0 ..< p.crowd_count {
		if person_chunk_index(p, i) != chunk_idx {
			continue
		}
		if p.rows[i].behavior.sleep_remaining > 0 {
			n += 1
		}
	}
	return n
}

person_can_sleep :: proc(p: ^People, i: int) -> bool {
	if i < 0 || i >= p.crowd_count {
		return false
	}
	row := p.rows[i]
	return row.identity.role == .Crowd &&
		row.motion.phase == .Active &&
		!row.food.served &&
		row.behavior.sleep_remaining == 0 &&
		row.motion.state == .Idle &&
		row.behavior.subbehavior == .None
}

roll_sleep_depth :: proc() -> u8 {
	n := SLEEP_COUNT_MAX - SLEEP_COUNT_MIN + 1
	return u8(SLEEP_COUNT_MIN + rand.int_max(n))
}

maybe_begin_sleep_on_idle_enter :: proc(p: ^People, i: int) {
	if !person_can_sleep(p, i) {
		return
	}
	chunk := person_chunk_index(p, i)
	if count_chunk_sleepers(p, chunk) >= chunk_sleep_cap(chunk_crowd_count(p, chunk)) {
		return
	}
	if rand.int_max(100) >= SLEEP_ON_IDLE_ENTER_CHANCE {
		return
	}
	p.rows[i].behavior.sleep_remaining = roll_sleep_depth()
}

chunk_crowd_count :: proc(p: ^People, chunk_idx: int) -> int {
	n := 0
	for i in 0 ..< p.crowd_count {
		if person_chunk_index(p, i) == chunk_idx {
			n += 1
		}
	}
	return n
}

seed_initial_chunk_sleepers :: proc(p: ^People) {
	if p.crowd_count == 0 || p.lineup.chunk_width <= 0 {
		return
	}
	max_chunk := 0
	for i in 0 ..< p.crowd_count {
		max_chunk = max(max_chunk, person_chunk_index(p, i))
	}
	for chunk in 0 ..= max_chunk {
		cap := chunk_sleep_cap(chunk_crowd_count(p, chunk))
		if cap <= 0 {
			continue
		}
		pool: [512]int
		n := 0
		for i in 0 ..< p.crowd_count {
			if person_chunk_index(p, i) != chunk {
				continue
			}
			if n >= len(pool) {
				break
			}
			pool[n] = i
			n += 1
		}
		for k in 0 ..< min(cap, n) {
			j := k + rand.int_max(n - k)
			pool[k], pool[j] = pool[j], pool[k]
			p.rows[pool[k]].behavior.sleep_remaining = roll_sleep_depth()
		}
	}
}

begin_wake_emote_pulse :: proc(p: ^People, i: int) {
	p.rows[i].behavior.wake_emote_timer = WAKE_EMOTE_FADE
	p.rows[i].behavior.wake_emote_shake_t = WAKE_EMOTE_SHAKE
}

tick_wake_emote :: proc(p: ^People, i: int, dt: f32) {
	row := &p.rows[i].behavior
	if row.wake_emote_timer > 0 {
		row.wake_emote_timer -= dt
		if row.wake_emote_timer < 0 {
			row.wake_emote_timer = 0
		}
	}
	if row.wake_emote_shake_t > 0 {
		row.wake_emote_shake_t -= dt
		if row.wake_emote_shake_t < 0 {
			row.wake_emote_shake_t = 0
		}
	}
}

person_is_sleeping :: proc(p: ^People, i: int) -> bool {
	return i >= 0 && i < len(p.rows) && p.rows[i].behavior.sleep_remaining > 0
}

roll_first_give_emote :: proc() -> bool {
	span := FIRST_GIVE_EMOTE_CHANCE_MAX - FIRST_GIVE_EMOTE_CHANCE_MIN + 1
	threshold := FIRST_GIVE_EMOTE_CHANCE_MIN + rand.int_max(span)
	return rand.int_max(100) < threshold
}

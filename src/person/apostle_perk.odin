package person

import "core:fmt"
import "core:math"
import "core:math/rand"
import "../config"
import rl "vendor:raylib"
import "../currency"
import "../food"
import "../theme"
import w "../world"

PERK_INTERACT_RADIUS :: 48.0
MINISTER_SPEED_MULT :: 1.5
PETER_SPRINT_MULT :: 3.0
REPEL_RADIUS :: 80.0
DRAW_RADIUS :: 96.0
SCARE_RADIUS :: 88.0
JUDAS_RANGE :: 64.0

Apostle_Perk_Ctx :: struct {
	world:           ^w.World,
	player_pos:      rl.Vector2,
	player_size:     rl.Vector2,
	player_facing:   f32,
	interact_radius: f32,
	run_stats:       ^Run_Stats,
	coins:           ^u32,
}

JUDAS_ANGRY_LINES: [5]cstring = {"ugh", "silly", "hmph", "tch", "no way"}
MINISTER_INTENT: [2]cstring = {"Take and eat", "Here, friend"}

set_apostle_perk :: proc(p: ^People, i: int, next: Apostle_Perk) {
	prev := p.rows[i].perk.apostle_perk
	if prev == next {
		return
	}
	p.rows[i].perk.apostle_perk = next
	when config.IS_DEBUG {
		if !p.debug.apostle_perk_log || p.debug.apostle_inspector_open {
			return
		}
		idx := int(p.rows[i].identity.apostle_idx)
		name: cstring = "?"
		if idx >= 0 && idx < APOSTLE_COUNT {
			name = APOSTLE_DEFS[idx].name
		}
		fmt.printf("apostle %s: %v -> %v\n", name, prev, next)
	}
}

init_apostle_perk_on_follow :: proc(p: ^People, person_i: int) {
	row := &p.rows[person_i]
	set_apostle_perk(p, person_i, .Follow)
	row.perk.perk_timer = 0
	row.perk.perk_cooldown = rand_float_range(8, 25)
	row.perk.minister_cooldown = rand_float_range(12, 30)
	row.perk.perk_target_i = -1
	row.perk.perk_aux = 0
	row.traits.draw_alpha = 1
	row.perk.perk_bubble = {}
	row.perk.passive_timer = rand_float_range(3, 8)
}

apostle_intent_line :: proc(apostle_idx: int, perk: Apostle_Perk) -> cstring {
	if apostle_idx == int(JUDAS_APOSTLE_IDX) {
		return ""
	}
	switch apostle_idx {
	case 0:
		if perk == .Peter_To_Chunk0 {
			return "I must go back to my Lord"
		}
	case 1:
		return "I'll bring some to you"
	case 2:
		return "Make way!"
	case 3:
		return "Come, see"
	case 5:
		return "I need quiet"
	case 6:
		if perk == .Thomas_Fade_Out {
			return "..."
		}
	case 7:
		return "Room, please"
	case 10:
		return "Step aside"
	case 8:
		return "???"
	case 9:
		return "..."
	}
	if perk == .Minister_Approach || perk == .Minister_Give {
		return MINISTER_INTENT[rand.int_max(len(MINISTER_INTENT))]
	}
	return ""
}

set_perk_bubble_text :: proc(p: ^People, i: int, kind: Perk_Bubble_Kind, text: cstring, duration: f32) {
	p.rows[i].perk.perk_bubble = {
		kind = kind,
		timer = duration,
		text = text,
	}
}

set_intent_bubble :: proc(p: ^People, i: int, text: cstring) {
	if text == "" {
		return
	}
	set_perk_bubble_text(p, i, .Intent_Text, text, rand_float_range(2, 4))
}

start_apostle_perk :: proc(p: ^People, i: int, perk: Apostle_Perk, duration: f32) {
	row := &p.rows[i]
	set_apostle_perk(p, i, perk)
	row.perk.perk_timer = duration
	line := apostle_intent_line(int(row.identity.apostle_idx), perk)
	if perk == .Philip_Think {
		row.perk.perk_bubble = {
			kind = .Philip_Calc,
			timer = duration,
			philip_fish = u8(rand.int_max(12) + 1),
			philip_bread = u8(rand.int_max(12) + 1),
		}
	} else if line != "" {
		set_intent_bubble(p, i, line)
	}
	row.perk.perk_cooldown = rand_float_range(8, 25)
	if perk == .James_Hop || perk == .John_Hop {
		row.motion.hop_step = 0
		row.motion.hop_timer = CELEBRATE_HOP_DURATION
		row.motion.state = .Celebrating
	}
}

end_apostle_perk :: proc(p: ^People, i: int) {
	row := &p.rows[i]
	set_apostle_perk(p, i, .Follow)
	row.perk.perk_timer = 0
	row.perk.perk_target_i = -1
	row.perk.perk_aux = 0
	p.escort.count = 0
	row.motion.state = .Idle
	row.motion.hop_step = 0
}

tick_perk_bubble :: proc(p: ^People, i: int, dt: f32) {
	if p.rows[i].perk.perk_bubble.kind == .None {
		return
	}
	p.rows[i].perk.perk_bubble.timer -= dt
	if p.rows[i].perk.perk_bubble.timer <= 0 {
		p.rows[i].perk.perk_bubble.kind = .None
	}
}

person_cx :: proc(p: ^People, i: int) -> f32 {
	return p.rows[i].transform.pos_x + p.rows[i].transform.size_w * 0.5
}

dist_x :: proc(ax: f32, bx: f32) -> f32 {
	return math.abs(ax - bx)
}

crowd_in_chunk :: proc(p: ^People, world: ^w.World, crowd_i: int, chunk_idx: int) -> bool {
	if !is_crowd_row(p, crowd_i) {
		return false
	}
	cx := person_cx(p, crowd_i)
	return w.chunk_index_at_x(world, cx) == chunk_idx
}

nearest_minister_target :: proc(p: ^People, world: ^w.World, apostle_i: int) -> int {
	chunk := w.chunk_index_at_x(world, person_cx(p, apostle_i))
	best := -1
	best_d: f32 = PERK_INTERACT_RADIUS * 4
	acx := person_cx(p, apostle_i)
	for i in 0 ..< p.crowd_count {
		if !needs_food(p, i) {
			continue
		}
		if !crowd_in_chunk(p, world, i, chunk) {
			continue
		}
		d := dist_x(acx, person_cx(p, i))
		if d < best_d {
			best_d = d
			best = i
		}
	}
	return best
}

judas_valid_target :: proc(p: ^People, i: int) -> bool {
	if !is_crowd_row(p, i) || p.rows[i].food.served {
		return false
	}
	row := p.rows[i]
	if row.motion.phase != .Active {
		return false
	}
	return row.food.has_fish || row.food.has_bread
}

nearest_judas_target :: proc(p: ^People, apostle_i: int) -> int {
	best := -1
	best_d: f32 = JUDAS_RANGE
	acx := person_cx(p, apostle_i)
	for i in 0 ..< p.crowd_count {
		if !judas_valid_target(p, i) {
			continue
		}
		d := dist_x(acx, person_cx(p, i))
		if d < best_d {
			best_d = d
			best = i
		}
	}
	return best
}

refusal_chance :: proc(age: Person_Age) -> int {
	switch age {
	case .Kid:
		return 75
	case .Young:
		return 50
	case .Adult:
		return 10
	}
	return 10
}

try_start_minister :: proc(p: ^People, i: int, ctx: Apostle_Perk_Ctx) -> bool {
	row := &p.rows[i]
	if int(row.identity.apostle_idx) == JUDAS_APOSTLE_IDX {
		return false
	}
	if row.perk.minister_cooldown > 0 {
		return false
	}
	tgt := nearest_minister_target(p, ctx.world, i)
	if tgt < 0 {
		return false
	}
	if rand.int_max(100) >= 12 {
		row.perk.minister_cooldown = rand_float_range(8, 18)
		return false
	}
	row.perk.perk_target_i = tgt
	row.perk.minister_cooldown = rand_float_range(12, 30)
	start_apostle_perk(p, i, .Minister_Approach, 30)
	return true
}

try_start_unique_perk :: proc(p: ^People, i: int, ctx: Apostle_Perk_Ctx) -> bool {
	row := &p.rows[i]
	if row.perk.perk_cooldown > 0 {
		return false
	}
	idx := int(row.identity.apostle_idx)
	chance := 8
	if idx == 0 {
		chance = 14
	}
	if rand.int_max(100) >= chance {
		row.perk.perk_cooldown = rand_float_range(5, 15)
		return false
	}
	switch idx {
	case 0:
		start_apostle_perk(p, i, .Peter_To_Chunk0, 60)
	case 1:
		start_apostle_perk(p, i, .Andrew_Go, 45)
	case 2:
		start_apostle_perk(p, i, .James_Hop, rand_float_range(2, 4))
	case 3:
		start_apostle_perk(p, i, .John_Hop, rand_float_range(2, 4))
	case 4:
		start_apostle_perk(p, i, .Philip_Think, rand_float_range(3, 10))
	case 5:
		start_apostle_perk(p, i, .Bartholomew_Visit, rand_float_range(8, 20))
	case 6:
		start_apostle_perk(p, i, .Thomas_Fade_Out, rand_float_range(1, 2))
	case 7, 10:
		row.perk.perk_aux = 1
		row.perk.perk_timer = rand_float_range(1.5, 3)
		set_apostle_perk(p, i, .Follow)
		set_intent_bubble(p, i, apostle_intent_line(idx, .Follow))
	case 8, 9:
		set_perk_bubble_text(
			p,
			i,
			.Passive_Text,
			apostle_intent_line(idx, .Follow),
			rand_float_range(1, 2),
		)
		row.perk.perk_cooldown = rand_float_range(6, 14)
		return true
	case 11:
		tgt := nearest_judas_target(p, i)
		if tgt < 0 {
			row.perk.perk_cooldown = rand_float_range(5, 12)
			return false
		}
		row.perk.perk_target_i = tgt
		start_apostle_perk(p, i, .Judas_Approach, 20)
	case:
		row.perk.perk_cooldown = rand_float_range(8, 20)
		return false
	}
	return true
}

tick_repel_aura :: proc(p: ^People, apostle_i: int, dt: f32) {
	acx := person_cx(p, apostle_i)
	for i in 0 ..< p.crowd_count {
		if !is_interactable(p, i) && p.rows[i].behavior.subbehavior == .None {
			if p.rows[i].motion.phase != .Active || p.rows[i].food.served {
				continue
			}
		}
		row := &p.rows[i]
		if row.food.served || row.motion.phase != .Active {
			continue
		}
		cx := person_cx(p, i)
		if dist_x(acx, cx) > REPEL_RADIUS {
			continue
		}
		push: f32 = 18 * dt
		if cx < acx {
			row.transform.pos_x -= push
		} else {
			row.transform.pos_x += push
		}
		row.transform.pos_x = math.clamp(row.transform.pos_x, row.transform.bound_min_x, row.transform.bound_max_x)
	}
}

tick_draw_aura :: proc(p: ^People, apostle_i: int, dt: f32) {
	acx := person_cx(p, apostle_i)
	for i in 0 ..< p.crowd_count {
		row := &p.rows[i]
		if row.food.served || row.motion.phase != .Active {
			continue
		}
		cx := person_cx(p, i)
		if dist_x(acx, cx) > DRAW_RADIUS {
			continue
		}
		step: f32 = 24 * dt
		if cx < acx {
			row.transform.pos_x += step
		} else {
			row.transform.pos_x -= step
		}
		row.transform.pos_x = math.clamp(row.transform.pos_x, row.transform.bound_min_x, row.transform.bound_max_x)
	}
}

tick_scare_aura :: proc(p: ^People, apostle_i: int, ctx: Apostle_Perk_Ctx) {
	acx := person_cx(p, apostle_i)
	dir: f32 = ctx.player_facing >= 0 ? 1 : -1
	if dir == 0 {
		dir = 1
	}
	for i in 0 ..< p.crowd_count {
		row := &p.rows[i]
		if row.food.served || row.motion.phase != .Active {
			continue
		}
		if dist_x(acx, person_cx(p, i)) > SCARE_RADIUS {
			continue
		}
		row.behavior.subbehavior = .Scared_To_Chunk
		row.motion.state = .Running
		row.transform.dir = dir
		row.behavior.flee_remaining = rand_float_range(40, 90)
	}
}

minister_give_apostle :: proc(p: ^People, apostle_i: int, crowd_i: int, stats: ^Run_Stats) {
	acx := person_cx(p, apostle_i)
	row := &p.rows[crowd_i]
	if !row.food.has_fish {
		apply_give_item(p, crowd_i, .Fish, acx, stats)
	}
	if !row.food.has_bread {
		apply_give_item(p, crowd_i, .Bread, acx, stats)
	}
}

tick_active_perk :: proc(p: ^People, i: int, ctx: Apostle_Perk_Ctx, dt: f32) {
	row := &p.rows[i]
	row.perk.perk_timer -= dt
	speed: f32 = RUN_SPEED * POST_SERVE_SPEED_MULT * MINISTER_SPEED_MULT
	switch row.perk.apostle_perk {
	case .Follow:
		return
	case .Minister_Approach:
		tgt := row.perk.perk_target_i
		if tgt < 0 || !needs_food(p, tgt) {
			end_apostle_perk(p, i)
			return
		}
		tx := person_cx(p, tgt) - row.transform.size_w * 0.5
		move_follower_toward_x(p, i, tx, speed, dt)
		if dist_x(person_cx(p, i), person_cx(p, tgt)) <= ctx.interact_radius {
			set_apostle_perk(p, i, .Minister_Give)
			row.perk.perk_timer = 8
		}
		if row.perk.perk_timer <= 0 {
			end_apostle_perk(p, i)
		}
	case .Minister_Give:
		tgt := row.perk.perk_target_i
		if tgt >= 0 {
			minister_give_apostle(p, i, tgt, ctx.run_stats)
		}
		end_apostle_perk(p, i)
	case .Peter_To_Chunk0:
		tx := w.chunk_center_x(ctx.world, 0) - row.transform.size_w * 0.5
		move_follower_toward_x(p, i, tx, speed * PETER_SPRINT_MULT, dt)
		if dist_x(person_cx(p, i), w.chunk_center_x(ctx.world, 0)) < 8 {
			set_apostle_perk(p, i, .Peter_Return)
			row.perk.perk_timer = 40
		}
		if row.perk.perk_timer <= 0 {
			end_apostle_perk(p, i)
		}
	case .Peter_Return:
		pcx := ctx.player_pos.x + ctx.player_size.x * 0.5
		tx := pcx - row.transform.size_w * 0.5 - 40
		move_follower_toward_x(p, i, tx, speed * PETER_SPRINT_MULT, dt)
		if dist_x(person_cx(p, i), pcx) < 56 || row.perk.perk_timer <= 0 {
			end_apostle_perk(p, i)
		}
	case .Andrew_Go:
		pcx0 := ctx.player_pos.x + ctx.player_size.x * 0.5
		pchunk := w.chunk_index_at_x(ctx.world, pcx0)
		dir := ctx.player_facing >= 0 ? 1 : -1
		next := w.chunk_clamp_index(ctx.world, pchunk + dir)
		tx := w.chunk_center_x(ctx.world, next) - row.transform.size_w * 0.5
		move_follower_toward_x(p, i, tx, speed, dt)
		if dist_x(person_cx(p, i), w.chunk_center_x(ctx.world, next)) < 20 {
			n := rand.int_max(5) + 1
			p.escort.count = 0
			for j in 0 ..< p.crowd_count {
				if p.escort.count >= n {
					break
				}
				if !crowd_in_chunk(p, ctx.world, j, next) {
					continue
				}
				if p.rows[j].food.served || p.rows[j].motion.phase != .Active {
					continue
				}
				p.escort.targets[p.escort.count] = j
				p.escort.count += 1
				p.rows[j].behavior.subbehavior = .Escort_To_Player
				p.rows[j].motion.state = .Walking
			}
			set_apostle_perk(p, i, .Andrew_Escort)
			row.perk.perk_timer = 25
		}
		if row.perk.perk_timer <= 0 {
			end_apostle_perk(p, i)
		}
	case .Andrew_Escort:
		pcx := ctx.player_pos.x + ctx.player_size.x * 0.5
		tx := pcx - row.transform.size_w * 0.5 - 30
		move_follower_toward_x(p, i, tx, speed, dt)
		done := true
		for k in 0 ..< p.escort.count {
			ci := p.escort.targets[k]
			if ci < 0 {
				continue
			}
			if p.rows[ci].behavior.subbehavior == .Escort_To_Player {
				done = false
			}
		}
		if done || row.perk.perk_timer <= 0 {
			for k in 0 ..< p.escort.count {
				ci := p.escort.targets[k]
				if ci >= 0 && p.rows[ci].behavior.subbehavior == .Escort_To_Player {
					p.rows[ci].behavior.subbehavior = .None
					roam_to_idle(p, ci)
				}
			}
			end_apostle_perk(p, i)
		}
	case .James_Hop:
		row.motion.state = .Celebrating
		row.motion.hop_timer -= dt
		if row.motion.hop_timer <= 0 {
			row.motion.hop_step += 1
			row.motion.hop_timer = CELEBRATE_HOP_DURATION
		}
		if row.motion.hop_step < 3 {
			t := math.max(row.motion.hop_timer / CELEBRATE_HOP_DURATION, 0)
			row.transform.pos_y = row.transform.base_y - CELEBRATE_HOP_HEIGHT * math.abs(math.sin(t * math.PI))
		} else {
			row.transform.pos_y = row.transform.base_y
			if rand.int_max(100) < 55 {
				tick_scare_aura(p, i, ctx)
			}
			end_apostle_perk(p, i)
		}
	case .John_Hop:
		row.motion.state = .Celebrating
		row.motion.hop_timer -= dt
		if row.motion.hop_timer <= 0 {
			row.motion.hop_step += 1
			row.motion.hop_timer = CELEBRATE_HOP_DURATION
		}
		if row.motion.hop_step < 3 {
			t := math.max(row.motion.hop_timer / CELEBRATE_HOP_DURATION, 0)
			row.transform.pos_y = row.transform.base_y - CELEBRATE_HOP_HEIGHT * math.abs(math.sin(t * math.PI))
		} else {
			row.transform.pos_y = row.transform.base_y
			if rand.int_max(100) < 50 {
				tick_draw_aura(p, i, dt)
			}
			end_apostle_perk(p, i)
		}
	case .Philip_Think:
		row.motion.state = .Idle
		if row.perk.perk_timer <= 0 {
			row.perk.perk_bubble.kind = .None
			end_apostle_perk(p, i)
		}
	case .Bartholomew_Visit:
		pcx0 := ctx.player_pos.x + ctx.player_size.x * 0.5
		pchunk := w.chunk_index_at_x(ctx.world, pcx0)
		dir := ctx.player_facing >= 0 ? 1 : -1
		prev := w.chunk_clamp_index(ctx.world, pchunk - dir)
		tx := w.chunk_center_x(ctx.world, prev) - row.transform.size_w * 0.5
		move_follower_toward_x(p, i, tx, speed * 0.9, dt)
		if dist_x(person_cx(p, i), w.chunk_center_x(ctx.world, prev)) < 16 {
			set_apostle_perk(p, i, .Bartholomew_Idle)
			row.perk.perk_timer = rand_float_range(5, 15)
			row.motion.state = .Idle
		}
		if row.perk.perk_timer <= 0 {
			end_apostle_perk(p, i)
		}
	case .Bartholomew_Idle:
		row.motion.state = .Idle
		if row.perk.perk_timer <= 0 {
			set_apostle_perk(p, i, .Peter_Return)
			row.perk.perk_timer = 25
		}
	case .Thomas_Fade_Out:
		row.traits.draw_alpha -= dt * 0.5
		if row.traits.draw_alpha <= 0 {
			row.traits.draw_alpha = 0
			set_apostle_perk(p, i, .Thomas_Hidden)
			row.perk.perk_timer = rand_float_range(5, 20)
		}
	case .Thomas_Hidden:
		row.traits.draw_alpha = 0
		if row.perk.perk_timer <= 0 {
			set_apostle_perk(p, i, .Thomas_Fade_In)
			row.perk.perk_timer = 2
		}
	case .Thomas_Fade_In:
		row.traits.draw_alpha += dt * 0.5
		if row.traits.draw_alpha >= 1 {
			row.traits.draw_alpha = 1
			end_apostle_perk(p, i)
		}
	case .Judas_Approach:
		tgt := row.perk.perk_target_i
		if tgt < 0 || !judas_valid_target(p, tgt) {
			end_apostle_perk(p, i)
			return
		}
		tx := person_cx(p, tgt) - row.transform.size_w * 0.5
		move_follower_toward_x(p, i, tx, speed * 0.8, dt)
		if dist_x(person_cx(p, i), person_cx(p, tgt)) <= ctx.interact_radius {
			set_apostle_perk(p, i, .Judas_Talk)
			row.perk.perk_timer = rand_float_range(2, 5)
			p.rows[tgt].behavior.subbehavior = .Frozen_Talk
			p.rows[tgt].motion.state = .Idle
			row.perk.perk_bubble = {
				kind = .Judas_Coin,
				timer = row.perk.perk_timer,
				coin_icon = u8(rand.int_max(currency.COIN_ICON_COUNT)),
			}
		}
	case .Judas_Talk:
		tgt := row.perk.perk_target_i
		if row.perk.perk_timer <= 0 && tgt >= 0 {
			refused := rand.int_max(100) < refusal_chance(p.rows[tgt].traits.age)
			if !refused && ctx.coins != nil {
				ctx.coins^ += 1
			}
			if refused {
				set_apostle_perk(p, i, .Judas_Angry)
				row.perk.perk_timer = rand_float_range(1, 2)
				set_perk_bubble_text(
					p,
					i,
					.Judas_Angry,
					JUDAS_ANGRY_LINES[rand.int_max(len(JUDAS_ANGRY_LINES))],
					row.perk.perk_timer,
				)
			} else {
				if tgt >= 0 {
					p.rows[tgt].behavior.subbehavior = .None
				}
				end_apostle_perk(p, i)
			}
		}
	case .Judas_Angry:
		if row.perk.perk_timer <= 0 {
			tgt := row.perk.perk_target_i
			if tgt >= 0 {
				p.rows[tgt].behavior.subbehavior = .None
			}
			end_apostle_perk(p, i)
		}
	case:
		end_apostle_perk(p, i)
	}
}

tick_passive_while_follow :: proc(p: ^People, i: int, ctx: Apostle_Perk_Ctx, dt: f32) {
	row := &p.rows[i]
	idx := int(row.identity.apostle_idx)
	row.perk.passive_timer -= dt
	if idx == 7 || idx == 10 {
		if row.perk.perk_aux > 0 {
			tick_repel_aura(p, i, dt)
			row.perk.perk_aux = 0
		} else if row.perk.passive_timer <= 0 {
			if rand.int_max(100) < 25 {
				row.perk.perk_aux = 1
				set_intent_bubble(p, i, apostle_intent_line(idx, .Follow))
			}
			row.perk.passive_timer = rand_float_range(2, 4)
		}
	}
	if idx == 8 || idx == 9 {
		if row.perk.passive_timer <= 0 {
			if rand.int_max(100) < 20 {
				set_perk_bubble_text(
					p,
					i,
					.Passive_Text,
					apostle_intent_line(idx, .Follow),
					rand_float_range(1, 2),
				)
			}
			row.perk.passive_timer = rand_float_range(4, 10)
		}
	}
}

update_escort_targets :: proc(p: ^People, player_cx: f32) {
	for i in 0 ..< p.crowd_count {
		if p.rows[i].behavior.subbehavior == .Escort_To_Player {
			p.rows[i].nav.target_x = player_cx - p.rows[i].transform.size_w * 0.5
		}
	}
}

tick_apostle_party :: proc(p: ^People, ctx: Apostle_Perk_Ctx, dt: f32) {
	if p.party.count == 0 {
		return
	}
	pcx := ctx.player_pos.x + ctx.player_size.x * 0.5
	update_escort_targets(p, pcx)
	for slot in 0 ..< p.party.count {
		i := apostle_follow_index_by_slot(p, slot)
		if i < 0 {
			continue
		}
		row := &p.rows[i]
		if row.motion.phase != .Following {
			continue
		}
		tick_perk_bubble(p, i, dt)
		if row.perk.minister_cooldown > 0 {
			row.perk.minister_cooldown -= dt
		}
		if row.perk.perk_cooldown > 0 {
			row.perk.perk_cooldown -= dt
		}
		if row.perk.apostle_perk == .Follow {
			tick_passive_while_follow(p, i, ctx, dt)
			unique_ready := row.perk.perk_cooldown <= 0
			minister_ready := row.perk.minister_cooldown <= 0
			if unique_ready && try_start_unique_perk(p, i, ctx) {
				continue
			}
			if minister_ready && try_start_minister(p, i, ctx) {
				continue
			}
		} else {
			tick_active_perk(p, i, ctx, dt)
		}
	}
}

apostle_uses_trail :: proc(perk: Apostle_Perk) -> bool {
	return perk == .Follow || perk == .Peter_Return
}

draw_speech_bubble :: proc(cx: f32, top_y: f32, w: f32, h: f32) {
	bx := cx - w * 0.5
	by := top_y - h
	rl.DrawRectangleRec({bx, by, w, h}, theme.BUBBLE_FILL)
	rl.DrawRectangleLinesEx({bx, by, w, h}, 1, theme.BUBBLE_BORDER)
}

draw_apostle_perk_bubbles :: proc(p: ^People, view: rl.Rectangle) {
	font: i32 = APOSTLE_LABEL_FONT
	pad: f32 = BUBBLE_PAD
	for i in p.crowd_count ..< len(p.rows) {
		row := p.rows[i]
		if row.identity.role != .Apostle || row.motion.phase != .Following {
			continue
		}
		if row.perk.perk_bubble.kind == .None {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		if row.traits.draw_alpha <= 0.05 {
			continue
		}
		cx := person_cx(p, i)
		bubble_h: f32
		bubble_w: f32
		switch row.perk.perk_bubble.kind {
		case .Intent_Text, .Judas_Angry, .Passive_Text:
			tw := f32(rl.MeasureText(row.perk.perk_bubble.text, font))
			bubble_w = tw + pad * 2
			bubble_h = f32(font) + pad * 2
			draw_speech_bubble(cx, row.transform.pos_y - 4, bubble_w, bubble_h)
			rl.DrawText(
				row.perk.perk_bubble.text,
				i32(cx - tw * 0.5),
				i32(row.transform.pos_y - 4 - bubble_h + pad),
				font,
				theme.TEXT_INK,
			)
		case .Judas_Coin:
			icon := food.FOOD_ICON_DRAW_SIZE
			bubble_w = icon + pad * 2
			bubble_h = icon + pad * 2
			draw_speech_bubble(cx, row.transform.pos_y - 4, bubble_w, bubble_h)
			cy := row.transform.pos_y - 4 - bubble_h * 0.5
			currency.draw_coin_icon(int(row.perk.perk_bubble.coin_icon), {cx, cy})
		case .Philip_Calc:
			icon := food.FOOD_ICON_DRAW_SIZE
			gap: f32 = 4
			eq: cstring = "= ???"
			eq_w := f32(rl.MeasureText(eq, font))
			mid: cstring = "x"
			mw := f32(rl.MeasureText(mid, font))
			bubble_w = icon + gap + mw + gap + icon + gap + eq_w + pad * 2
			bubble_h = icon + pad * 2
			draw_speech_bubble(cx, row.transform.pos_y - 4, bubble_w, bubble_h)
			left := cx - bubble_w * 0.5 + pad
			cy := row.transform.pos_y - 4 - bubble_h * 0.5
			if food.ready() {
				food.draw_icon(
					food.fish_tex,
					int(row.perk.perk_bubble.philip_fish) % food.FISH_ICON_COUNT,
					f32(food.FISH_CELL_SIZE),
					food.FISH_ATLAS_COLS,
					{left + icon * 0.5, cy},
				)
				food.draw_icon(
					food.bread_tex,
					int(row.perk.perk_bubble.philip_bread) % food.BREAD_ICON_COUNT,
					f32(food.BREAD_CELL_SIZE),
					food.BREAD_ATLAS_COLS,
					{left + icon + gap + mw + gap + icon * 0.5, cy},
				)
			}
			rl.DrawText(mid, i32(left + icon + gap), i32(cy - f32(font) * 0.5), font, theme.TEXT_INK)
			rl.DrawText(eq, i32(left + icon + gap + mw + gap + icon + gap), i32(cy - f32(font) * 0.5), font, theme.TEXT_INK)
		case .None:
			break
		}
	}
}

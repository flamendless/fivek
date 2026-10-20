package person

import "core:fmt"
import rl "vendor:raylib"
import "../player"

PARTY_SPEED_PER :: 0.04
PARTY_STAMINA_MAX_PER :: 0.4
PARTY_RANGE_PER :: 6.0
PARTY_RECOVERY_PER :: 0.08
PARTY_DEBUG_STAT_COUNT :: 7

Apostle_Bonus_Kind :: enum {
	Speed,
	Stamina,
	Range,
	Recovery,
	None,
}

APOSTLE_BONUS_KIND: [APOSTLE_COUNT]Apostle_Bonus_Kind = {
	.Speed,
	.Speed,
	.Speed,
	.Range,
	.Range,
	.Stamina,
	.Recovery,
	.Stamina,
	.Recovery,
	.Stamina,
	.Range,
	.None,
}

Party_Bonuses :: struct {
	speed_mult: f32,
	stamina_max: f32,
	interact_radius_add: f32,
	stamina_regen: f32,
	counts: [4]u8,
}

Party_Debug_Stat_Row :: struct {
	label:       cstring,
	base:        cstring,
	delta:       cstring,
	delta_value: f32,
}

bonus_kind_index :: proc(kind: Apostle_Bonus_Kind) -> int {
	switch kind {
	case .Speed:
		return 0
	case .Stamina:
		return 1
	case .Range:
		return 2
	case .Recovery:
		return 3
	case .None:
		return -1
	}
	return -1
}

apostle_bonus_kind :: proc(apostle_idx: int) -> Apostle_Bonus_Kind {
	if apostle_idx < 0 || apostle_idx >= APOSTLE_COUNT {
		return .None
	}
	return APOSTLE_BONUS_KIND[apostle_idx]
}

apostle_bonus_label :: proc(kind: Apostle_Bonus_Kind) -> cstring {
	switch kind {
	case .Speed:
		return "+Speed"
	case .Stamina:
		return "+Stamina"
	case .Range:
		return "+Range"
	case .Recovery:
		return "+Recovery"
	case .None:
		return ""
	}
	return ""
}

party_bonuses :: proc(p: ^People) -> Party_Bonuses {
	out: Party_Bonuses
	out.speed_mult = 1.0
	out.stamina_max = player.STAMINA_MAX
	out.stamina_regen = player.STAMINA_REGEN
	if p.party.count == 0 {
		return out
	}
	for slot in 0 ..< p.party.count {
		i := apostle_follow_index_by_slot(p, slot)
		if i < 0 {
			continue
		}
		row := p.rows[i]
		if row.motion.phase != .Following {
			continue
		}
		kind := apostle_bonus_kind(int(row.identity.apostle_idx))
		bi := bonus_kind_index(kind)
		if bi < 0 {
			continue
		}
		out.counts[bi] += 1
	}
	out.speed_mult += f32(out.counts[0]) * PARTY_SPEED_PER
	out.stamina_max += f32(out.counts[1]) * PARTY_STAMINA_MAX_PER
	out.interact_radius_add = f32(out.counts[2]) * PARTY_RANGE_PER
	out.stamina_regen += f32(out.counts[3]) * PARTY_RECOVERY_PER
	return out
}

party_player_modifiers :: proc(bonuses: Party_Bonuses) -> player.Player_Modifiers {
	return {
		speed_mult = bonuses.speed_mult,
		stamina_max = bonuses.stamina_max,
		stamina_regen = bonuses.stamina_regen,
	}
}

party_debug_stat_rows :: proc(
	bonuses: Party_Bonuses,
	walk_speed: f32,
	interact_radius: f32,
	rows: ^[PARTY_DEBUG_STAT_COUNT]Party_Debug_Stat_Row,
) {
	mult := bonuses.speed_mult
	spd_pct := int((mult - 1.0) * 100 + 0.5)
	stam_add := bonuses.stamina_max - player.STAMINA_MAX
	rec_add := bonuses.stamina_regen - player.STAMINA_REGEN
	rng_add := bonuses.interact_radius_add
	walk_add := walk_speed * (mult - 1.0)
	run_base := walk_speed * player.SPRINT_MULT
	run_add := run_base * (mult - 1.0)
	dbg_run_base := walk_speed * player.DEBUG_SPRINT_MULT
	dbg_run_add := dbg_run_base * (mult - 1.0)

	speed_base := fmt.ctprintf("%.0f", walk_speed)
	speed_delta: cstring
	if spd_pct > 0 {
		speed_delta = fmt.ctprintf(" +%d%%", spd_pct)
	} else if spd_pct < 0 {
		speed_delta = fmt.ctprintf(" %d%%", spd_pct)
	}

	stam_base := fmt.ctprintf("%.1f", player.STAMINA_MAX)
	stam_delta: cstring
	if stam_add > 0.05 {
		stam_delta = fmt.ctprintf(" +%.1f", stam_add)
	} else if stam_add < -0.05 {
		stam_delta = fmt.ctprintf(" %.1f", stam_add)
	}

	rec_base := fmt.ctprintf("%.2f", player.STAMINA_REGEN)
	rec_delta: cstring
	if rec_add > 0.001 {
		rec_delta = fmt.ctprintf(" +%.2f", rec_add)
	} else if rec_add < -0.001 {
		rec_delta = fmt.ctprintf(" %.2f", rec_add)
	}

	rng_base := fmt.ctprintf("%.0f", interact_radius)
	rng_delta: cstring
	rng_i := int(rng_add + 0.5)
	if rng_i > 0 {
		rng_delta = fmt.ctprintf(" +%d", rng_i)
	} else if rng_i < 0 {
		rng_delta = fmt.ctprintf(" %d", rng_i)
	}

	walk_base := fmt.ctprintf("%.0f", walk_speed)
	walk_delta: cstring
	if walk_add > 0.05 {
		walk_delta = fmt.ctprintf(" +%.1f px/s", walk_add)
	} else if walk_add < -0.05 {
		walk_delta = fmt.ctprintf(" %.1f px/s", walk_add)
	}

	run_base_s := fmt.ctprintf("%.1f", run_base)
	run_delta: cstring
	if run_add > 0.05 {
		run_delta = fmt.ctprintf(" +%.1f px/s", run_add)
	} else if run_add < -0.05 {
		run_delta = fmt.ctprintf(" %.1f px/s", run_add)
	}

	dbg_run_base_s := fmt.ctprintf("%.1f", dbg_run_base)
	dbg_run_delta: cstring
	if dbg_run_add > 0.05 {
		dbg_run_delta = fmt.ctprintf(" +%.1f px/s", dbg_run_add)
	} else if dbg_run_add < -0.05 {
		dbg_run_delta = fmt.ctprintf(" %.1f px/s", dbg_run_add)
	}

	rows[0] = {"Speed", speed_base, speed_delta, f32(spd_pct)}
	rows[1] = {"Stamina", stam_base, stam_delta, stam_add}
	rows[2] = {"Recovery", rec_base, rec_delta, rec_add}
	rows[3] = {"Range", rng_base, rng_delta, rng_add}
	rows[4] = {"Walk", walk_base, walk_delta, walk_add}
	rows[5] = {"Run", run_base_s, run_delta, run_add}
	rows[6] = {"Run (debug)", dbg_run_base_s, dbg_run_delta, dbg_run_add}
}

measure_party_debug_stat_row :: proc(row: Party_Debug_Stat_Row, font: i32) -> i32 {
	prefix := fmt.ctprintf("%s: %s", row.label, row.base)
	w := rl.MeasureText(prefix, font)
	if row.delta != "" {
		w += rl.MeasureText(row.delta, font)
	}
	return w
}

party_bonus_hud_line :: proc(bonuses: Party_Bonuses) -> cstring {
	if bonuses.counts[0] == 0 &&
	   bonuses.counts[1] == 0 &&
	   bonuses.counts[2] == 0 &&
	   bonuses.counts[3] == 0 {
		return ""
	}
	spd_pct := int((bonuses.speed_mult - 1.0) * 100 + 0.5)
	stam_add := bonuses.stamina_max - player.STAMINA_MAX
	rng_px := int(bonuses.interact_radius_add + 0.5)
	rec_add := bonuses.stamina_regen - player.STAMINA_REGEN
	return fmt.ctprintf(
		"Party +%d%% spd +%.1f stam +%d rng +%.2f rec",
		spd_pct,
		stam_add,
		rng_px,
		rec_add,
	)
}

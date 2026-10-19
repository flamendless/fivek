package person

import "core:fmt"
import "../player"

PARTY_SPEED_PER :: 0.04
PARTY_STAMINA_MAX_PER :: 0.4
PARTY_RANGE_PER :: 6.0
PARTY_RECOVERY_PER :: 0.08

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

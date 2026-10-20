package person

import rl "vendor:raylib"

REJECT_SPEECH_LINE_PETER: cstring = "I will only follow the Master"
REJECT_SPEECH_LINE_JUDAS: cstring = "Thy ledger falls short, friend."
REJECT_SPEECH_LINE_THOMAS: cstring = "I cannot follow what I cannot see."

REJECT_SPEECH_COUNT :: 17
REJECT_SPEECH_LINES: [REJECT_SPEECH_COUNT]cstring = {
	"Return when thy works speak louder.",
	"I follow not the unprepared.",
	"The harvest is not yet in thy hands.",
	"Thou hast far to walk ere we join.",
	"Not yet—not by bread alone.",
	"Prove thy ministry, then ask again.",
	"My yes waits on thy deeds.",
	"Go forth and serve, then return.",
	"We are not ready to walk together.",
	"First the many, then the twelve.",
	"Thou seekest too soon.",
	"Let thy flock be fed ere thou lead.",
	"The road is long; thou art not far enough.",
	"Ask again when heaven is pleased.",
	"Thy spirit is willing; thy tally is not.",
	"I will not sail on an empty net.",
	"Come back bearing more than hope.",
}

Apostle_Def :: struct {
	name: cstring,
	color: rl.Color,
}

APOSTLE_DEFS: [APOSTLE_COUNT]Apostle_Def = {
	{"Peter", {220, 60, 60, 255}},
	{"Andrew", {230, 120, 50, 255}},
	{"James", {230, 190, 40, 255}},
	{"John", {180, 210, 50, 255}},
	{"Philip", {80, 180, 70, 255}},
	{"Bartholomew", {50, 170, 150, 255}},
	{"Thomas", {60, 190, 220, 255}},
	{"Matthew", {70, 110, 220, 255}},
	{"Jude", {90, 80, 200, 255}},
	{"Thaddaeus", {150, 80, 200, 255}},
	{"Simon", {200, 70, 180, 255}},
	{"Judas", {140, 30, 40, 255}},
}

Req_Tier :: enum {
	Low,
	High,
	Judas,
}

Apostle_Rng :: struct {
	state: u64,
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

apostle_reject_speech_text :: proc(p: ^People, apostle_idx: int) -> cstring {
	switch apostle_idx {
	case PETER_APOSTLE_IDX:
		return REJECT_SPEECH_LINE_PETER
	case THOMAS_APOSTLE_IDX:
		return REJECT_SPEECH_LINE_THOMAS
	case JUDAS_APOSTLE_IDX:
		return REJECT_SPEECH_LINE_JUDAS
	}
	idx := p.apostle_reject_speech[apostle_idx]
	if idx < REJECT_SPEECH_COUNT {
		return REJECT_SPEECH_LINES[idx]
	}
	return ""
}

roll_apostle_reject_speech :: proc(seed: u64, slot: int) -> u8 {
	switch slot {
	case PETER_APOSTLE_IDX, THOMAS_APOSTLE_IDX, JUDAS_APOSTLE_IDX:
		return 0
	}
	mix := u64(slot + 73) * 0xBF58476D1CE4E5B9
	rng := apostle_rng_init(seed ~ mix)
	return u8(apostle_rng_u32(&rng) % u32(REJECT_SPEECH_COUNT))
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

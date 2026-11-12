package achievements

import "core:log"

ACHIEVEMENT_COUNT :: 9
ACHIEVEMENT_BYTES :: (ACHIEVEMENT_COUNT + 7) / 8
ACHIEVEMENTS_VERSION :: 1

Id :: enum {
	CharityNeverFaileth,
	SmallActBigChange,
	NotTheRejectedOne,
	MoreHandsFeet,
	FishersAssemble,
	WellDoneFaithful,
	JourneyFiveThousand,
	LoavesAndFishes,
	MothDothCorrupt,
}

Achievement_Def :: struct {
	title:       cstring,
	description: cstring,
}

ACHIEVEMENT_DEFS: [ACHIEVEMENT_COUNT]Achievement_Def = {
	{"Charity Never Faileth", "Give bread and fish to someone."},
	{"Small Act Leads to Big Change", "First person that goes to the left after celebration."},
	{"You're Not Really the Rejected One...", "First person that goes to the right after celebration."},
	{"More Hands and Feet, More Harvest", "First apostle recruited."},
	{"Fishers of Men... Assemble!", "Recruited 12 apostles."},
	{"Well Done, Good and Faithful", "Win your first run."},
	{"Five Thousand Steps", "Walk 5,000 distance across your career."},
	{"Loaves and Fishes, Multiplied", "Serve 500 people across your career."},
	{"Moth Doth Corrupt These", "Pick up your first coin."},
}

State :: struct {
	version:  u32,
	unlocked: [ACHIEVEMENT_BYTES]u8,
}

state_default :: proc() -> State {
	return {version = ACHIEVEMENTS_VERSION}
}

is_unlocked :: proc(s: State, id: Id) -> bool {
	i := int(id)
	if i < 0 || i >= ACHIEVEMENT_COUNT {
		return false
	}
	return s.unlocked[i / 8] & u8(1 << uint(i % 8)) != 0
}

@(private = "file")
set_unlocked :: proc(s: ^State, id: Id) {
	i := int(id)
	s.unlocked[i / 8] |= u8(1 << uint(i % 8))
}

try_unlock :: proc(state: ^State, pending: ^[dynamic]Id, id: Id) -> bool {
	if state == nil || is_unlocked(state^, id) {
		return false
	}
	set_unlocked(state, id)
	if pending != nil {
		append(pending, id)
	}
	log.infof("achievement unlocked: %s", ACHIEVEMENT_DEFS[id].title)
	return true
}

when false {
	@(private = "file")
	_self_check :: proc() {
		s := state_default()
		pending: [dynamic]Id
		assert(try_unlock(&s, &pending, .CharityNeverFaileth))
		assert(!try_unlock(&s, &pending, .CharityNeverFaileth))
		assert(len(pending) == 1)
	}
}

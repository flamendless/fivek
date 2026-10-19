#+build !js
package game

import "core:log"
import "core:mem"
import "core:os"

INTRO_PREFS_MAGIC :: [5]u8 {0x66, 0x6C, 0x61, 0x6D, 0x38}
INTRO_PREFS_MIN_LEN :: 6

Intro_Prefs :: struct {
	magic: [5]u8,
	seen: u8,
	tutorial_seen: u8,
}

intro_prefs_magic_ok :: proc(magic: [5]u8) -> bool {
	return magic == INTRO_PREFS_MAGIC
}

read_intro_prefs :: proc() -> (prefs: Intro_Prefs, ok: bool) {
	data, err := os.read_entire_file_from_path(INTRO_PREFS_FILENAME, context.temp_allocator)
	if err != nil || len(data) < INTRO_PREFS_MIN_LEN {
		return {}, false
	}
	n := min(len(data), size_of(Intro_Prefs))
	mem.copy(&prefs, &data[0], n)
	if len(data) < size_of(Intro_Prefs) {
		prefs.tutorial_seen = 0
	}
	ok = intro_prefs_magic_ok(prefs.magic)
	return prefs, ok
}

write_intro_prefs :: proc(prefs: ^Intro_Prefs) {
	log.infof("saving intro prefs %s", INTRO_PREFS_FILENAME)
	bytes := ([^]u8)(prefs)[:size_of(Intro_Prefs)]
	if err := os.write_entire_file(INTRO_PREFS_FILENAME, bytes); err != nil {
		log.warnf("failed to write intro prefs %s", INTRO_PREFS_FILENAME)
	}
}

load_intro_seen :: proc() -> bool {
	prefs, ok := read_intro_prefs()
	seen := ok && prefs.seen != 0
	log.infof("intro prefs loaded (seen=%v)", seen)
	return seen
}

save_intro_seen :: proc() {
	prefs, ok := read_intro_prefs()
	if !ok {
		prefs = Intro_Prefs{magic = INTRO_PREFS_MAGIC}
	}
	prefs.seen = 1
	write_intro_prefs(&prefs)
}

load_tutorial_seen :: proc() -> bool {
	prefs, ok := read_intro_prefs()
	seen := ok && prefs.tutorial_seen != 0
	log.infof("intro prefs loaded (tutorial_seen=%v)", seen)
	return seen
}

save_tutorial_seen :: proc() {
	prefs, ok := read_intro_prefs()
	if !ok {
		prefs = Intro_Prefs{magic = INTRO_PREFS_MAGIC}
	}
	prefs.tutorial_seen = 1
	write_intro_prefs(&prefs)
}

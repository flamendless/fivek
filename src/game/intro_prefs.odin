#+build !js
package game

import "core:mem"
import "core:os"

INTRO_PREFS_MAGIC :: [5]u8 {0x66, 0x6C, 0x61, 0x6D, 0x38}

Intro_Prefs :: struct {
	magic: [5]u8,
	seen: u8,
}

intro_prefs_magic_ok :: proc(magic: [5]u8) -> bool {
	return magic == INTRO_PREFS_MAGIC
}

load_intro_seen :: proc() -> bool {
	data, err := os.read_entire_file_from_path(INTRO_PREFS_FILENAME, context.temp_allocator)
	if err != nil || len(data) < size_of(Intro_Prefs) {
		return false
	}
	prefs: Intro_Prefs
	mem.copy(&prefs, &data[0], size_of(Intro_Prefs))
	return intro_prefs_magic_ok(prefs.magic) && prefs.seen != 0
}

save_intro_seen :: proc() {
	prefs := Intro_Prefs{magic = INTRO_PREFS_MAGIC, seen = 1}
	bytes := ([^]u8)(&prefs)[:size_of(Intro_Prefs)]
	_ = os.write_entire_file(INTRO_PREFS_FILENAME, bytes)
}

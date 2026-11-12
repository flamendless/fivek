package game

INTRO_PREFS_MAGIC :: [5]u8 {0x66, 0x6C, 0x61, 0x6D, 0x38}
INTRO_PREFS_MIN_LEN :: 6

Intro_Prefs :: struct {
	magic:         [5]u8,
	seen:          u8,
	tutorial_seen: u8,
}

intro_prefs_magic_ok :: proc(magic: [5]u8) -> bool {
	return magic == INTRO_PREFS_MAGIC
}

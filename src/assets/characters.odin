package assets

import rl "vendor:raylib"

CROWD_CHAR_PATH :: "assets/characters/char.png"
CROWD_CHAR_RIGHT_PATH :: "assets/characters/char_right.png"
CROWD_UPPER_PATH :: "assets/characters/upper.png"
CROWD_UPPER_RIGHT_PATH :: "assets/characters/upper_right.png"
CROWD_HAIR_PATH :: "assets/characters/hair.png"
CROWD_HAIR_RIGHT_PATH :: "assets/characters/hair_right.png"
CROWD_HEAD_PATH :: "assets/characters/head.png"
CROWD_HEAD_RIGHT_PATH :: "assets/characters/head_right.png"

Crowd_Sheet :: enum {
	Char,
	Char_Right,
	Upper,
	Upper_Right,
	Hair,
	Hair_Right,
	Head,
	Head_Right,
}

CROWD_SHEET_PATHS: [Crowd_Sheet]cstring = {
	.Char         = CROWD_CHAR_PATH,
	.Char_Right   = CROWD_CHAR_RIGHT_PATH,
	.Upper        = CROWD_UPPER_PATH,
	.Upper_Right  = CROWD_UPPER_RIGHT_PATH,
	.Hair         = CROWD_HAIR_PATH,
	.Hair_Right   = CROWD_HAIR_RIGHT_PATH,
	.Head         = CROWD_HEAD_PATH,
	.Head_Right   = CROWD_HEAD_RIGHT_PATH,
}

CROWD_IDLE_BASE_GRID :: Grid_Atlas{cell = 16, cols = 6, icon_count = 6}
CROWD_IDLE_OVERLAY_GRID :: Grid_Atlas{cell = 16, cols = 6, icon_count = 6}
CROWD_WALK_GRID :: Grid_Atlas{cell = 16, cols = 18, icon_count = 18}

crowd_sheet :: proc(s: Crowd_Sheet) -> rl.Texture2D {
	return peek_texture(CROWD_SHEET_PATHS[s])
}

crowd_ready :: proc() -> bool {
	for s in Crowd_Sheet {
		if crowd_sheet(s).id == 0 {
			return false
		}
	}
	return true
}

load_crowd_sheets :: proc() -> bool {
	ok := true
	for s in Crowd_Sheet {
		_, sheet_ok := acquire_texture(CROWD_SHEET_PATHS[s], OPT_POINT_CLAMP)
		ok = ok && sheet_ok
	}
	return ok
}

unload_crowd_sheets :: proc() {
	for s in Crowd_Sheet {
		release_texture(CROWD_SHEET_PATHS[s])
	}
}

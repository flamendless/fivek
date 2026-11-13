package assets

import rl "vendor:raylib"

Emote_Kind :: enum {
	Heart,
	Exclamation,
	Question,
	Zzz,
}

EMOTE_CELL :: 16

EMOTE_PATHS: [Emote_Kind]cstring = {
	.Heart       = "assets/ui/emotes/emotes/emote_heart.png",
	.Exclamation = "assets/ui/emotes/emotes/emote_exclamation.png",
	.Question    = "assets/ui/emotes/emotes/emote_question.png",
	.Zzz         = "assets/ui/emotes/emotes/emote_zzz.png",
}

emote :: proc(k: Emote_Kind) -> rl.Texture2D {
	return peek_texture(EMOTE_PATHS[k])
}

EMOTE_PATH_LIST: []cstring = {
	EMOTE_PATHS[.Heart],
	EMOTE_PATHS[.Exclamation],
	EMOTE_PATHS[.Question],
	EMOTE_PATHS[.Zzz],
}

load_emote_textures :: proc() -> bool {
	ok := true
	for path in EMOTE_PATH_LIST {
		_, tex_ok := acquire_texture(path, OPT_POINT_CLAMP)
		ok = ok && tex_ok
	}
	return ok
}

release_emote_textures :: proc() {
	for path in EMOTE_PATH_LIST {
		release_texture(path)
	}
}

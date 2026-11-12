#+build js
package game

import "core:c"
import "core:encoding/base64"
import "core:log"
import "core:mem"
import "core:strings"

foreign import "env"

WEB_INTRO_PREFS_STORAGE_KEY :: "fivek:intro_prefs"

@(default_calling_convention = "c")
foreign env {
	fivek_intro_prefs_storage_get_len :: proc() -> int ---
	fivek_intro_prefs_storage_get :: proc(buf: [^]u8, max_len: int) -> int ---
	fivek_intro_prefs_storage_set :: proc(data: cstring) ---
}

read_intro_prefs :: proc() -> (prefs: Intro_Prefs, ok: bool) {
	n := fivek_intro_prefs_storage_get_len()
	if n < INTRO_PREFS_MIN_LEN {
		return {}, false
	}

	text_buf := make([]u8, n + 1, context.temp_allocator)
	got := fivek_intro_prefs_storage_get(raw_data(text_buf), len(text_buf))
	if got <= 0 {
		return {}, false
	}
	b64 := string(text_buf[:got])
	raw, dec_err := base64.decode(b64, allocator = context.temp_allocator)
	if dec_err != nil || len(raw) < INTRO_PREFS_MIN_LEN {
		return {}, false
	}

	n_copy := min(len(raw), size_of(Intro_Prefs))
	mem.copy(&prefs, &raw[0], n_copy)
	if len(raw) < size_of(Intro_Prefs) {
		prefs.tutorial_seen = 0
	}
	ok = intro_prefs_magic_ok(prefs.magic)
	return prefs, ok
}

write_intro_prefs :: proc(prefs: ^Intro_Prefs) {
	log.infof("saving intro prefs %s", WEB_INTRO_PREFS_STORAGE_KEY)
	bytes := ([^]u8)(prefs)[:size_of(Intro_Prefs)]
	b64, enc_err := base64.encode(bytes)
	if enc_err != nil {
		log.warnf("failed to encode intro prefs %s", WEB_INTRO_PREFS_STORAGE_KEY)
		return
	}
	cstr, cstr_err := strings.clone_to_cstring(b64, context.temp_allocator)
	if cstr_err != nil {
		return
	}
	fivek_intro_prefs_storage_set(cstr)
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

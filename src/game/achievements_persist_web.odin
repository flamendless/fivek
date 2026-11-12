#+build js
package game

import "core:c"
import "core:encoding/base64"
import "core:log"
import "core:mem"
import "core:strings"
import "../achievements"

foreign import "env"

ACHIEVEMENTS_MAGIC :: [5]u8 {0x66, 0x6C, 0x61, 0x6D, 0x41}

WEB_ACHIEVEMENTS_STORAGE_KEY :: "fivek:achievements"

@(default_calling_convention = "c")
foreign env {
	fivek_achievements_storage_get_len :: proc() -> int ---
	fivek_achievements_storage_get :: proc(buf: [^]u8, max_len: int) -> int ---
	fivek_achievements_storage_set :: proc(data: cstring) ---
}

achievements_file_size :: proc() -> int {
	return 5 + size_of(achievements.State)
}

load_achievements :: proc() -> achievements.State {
	n := fivek_achievements_storage_get_len()
	need := achievements_file_size()
	if n < need {
		log.info("achievements: no web storage, starting fresh")
		return achievements.state_default()
	}

	text_buf := make([]u8, n + 1, context.temp_allocator)
	got := fivek_achievements_storage_get(raw_data(text_buf), len(text_buf))
	if got <= 0 {
		return achievements.state_default()
	}
	b64 := string(text_buf[:got])
	raw, dec_err := base64.decode(b64, allocator = context.temp_allocator)
	if dec_err != nil || len(raw) < need {
		return achievements.state_default()
	}

	magic: [5]u8
	mem.copy(&magic, &raw[0], 5)
	if magic != ACHIEVEMENTS_MAGIC {
		return achievements.state_default()
	}

	state: achievements.State
	mem.copy(&state, &raw[5], size_of(achievements.State))
	if state.version == 0 {
		state.version = achievements.ACHIEVEMENTS_VERSION
	}
	log.info("achievements loaded from web")
	return state
}

save_achievements :: proc(state: ^achievements.State) {
	state.version = achievements.ACHIEVEMENTS_VERSION
	file := make([]u8, achievements_file_size(), context.temp_allocator)
	magic := ACHIEVEMENTS_MAGIC
	mem.copy(&file[0], &magic, 5)
	mem.copy(&file[5], state, size_of(achievements.State))

	b64, enc_err := base64.encode(file)
	if enc_err != nil {
		log.warn("failed to encode achievements to base64")
		return
	}
	cstr, cstr_err := strings.clone_to_cstring(b64, context.temp_allocator)
	if cstr_err != nil {
		return
	}
	fivek_achievements_storage_set(cstr)
	log.info("saved achievements to web")
}

#+build js
package game

import "core:c"
import "core:encoding/base64"
import "core:log"
import "core:mem"
import "core:strings"
import "../person"

foreign import "env"

WEB_CAREER_STORAGE_KEY :: "fivek:career_stats"

@(default_calling_convention = "c")
foreign env {
	fivek_career_storage_get_len :: proc() -> int ---
	fivek_career_storage_get :: proc(buf: [^]u8, max_len: int) -> int ---
	fivek_career_storage_set :: proc(data: cstring) ---
}

career_file_size :: proc() -> int {
	return 5 + size_of(person.Career_Stats)
}

load_career_stats :: proc() -> person.Career_Stats {
	n := fivek_career_storage_get_len()
	need := career_file_size()
	if n < need {
		log.info("career stats: no web storage, starting fresh")
		return person.career_stats_default()
	}

	text_buf := make([]u8, n + 1, context.temp_allocator)
	got := fivek_career_storage_get(raw_data(text_buf), len(text_buf))
	if got <= 0 {
		return person.career_stats_default()
	}
	b64 := string(text_buf[:got])
	raw, dec_err := base64.decode(b64, allocator = context.temp_allocator)
	if dec_err != nil || len(raw) < need {
		return person.career_stats_default()
	}

	magic: [5]u8
	mem.copy(&magic, &raw[0], 5)
	if magic != CAREER_STATS_MAGIC {
		return person.career_stats_default()
	}

	stats: person.Career_Stats
	mem.copy(&stats, &raw[5], size_of(person.Career_Stats))
	if stats.version == 0 {
		stats.version = person.CAREER_STATS_VERSION
	}
	log.info("career stats loaded from web")
	return stats
}

save_career_stats :: proc(stats: ^person.Career_Stats) {
	stats.version = person.CAREER_STATS_VERSION
	file := make([]u8, career_file_size(), context.temp_allocator)
	magic := CAREER_STATS_MAGIC
	mem.copy(&file[0], &magic, 5)
	mem.copy(&file[5], stats, size_of(person.Career_Stats))

	b64, enc_err := base64.encode(file)
	if enc_err != nil {
		log.warn("failed to encode career stats to base64")
		return
	}
	cstr, cstr_err := strings.clone_to_cstring(b64, context.temp_allocator)
	if cstr_err != nil {
		return
	}
	fivek_career_storage_set(cstr)
	log.info("saved career stats to web")
}

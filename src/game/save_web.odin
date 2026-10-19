#+build js
package game

import "core:c"
import "core:encoding/base64"
import "core:log"
import "core:strings"
import "../person"

@(default_calling_convention = "c")
foreign "env" {
	fivek_web_storage_get_len :: proc() -> int ---
	fivek_web_storage_get :: proc(buf: [^]u8, max_len: int) -> int ---
	fivek_web_storage_set :: proc(data: cstring) ---
	fivek_open_url :: proc(url: cstring) ---
}

load_save :: proc(
	path: string,
	seed: u64,
	count: int,
	bits: []u8,
	apostle_bits: []u8,
	run_stats: ^person.Run_Stats,
	stats_pledged: ^person.Run_Stats,
	coins: ^u32,
) -> bool {
	_ = path
	label := WEB_SAVE_STORAGE_KEY
	log.infof("loading save %s", label)

	n := fivek_web_storage_get_len()
	if n <= 0 {
		log.warnf("no save in %s", label)
		return false
	}

	text_buf := make([]u8, n + 1)
	defer delete(text_buf)
	got := fivek_web_storage_get(raw_data(text_buf), len(text_buf))
	if got <= 0 {
		log.warnf("failed to read save %s", label)
		return false
	}
	b64 := string(text_buf[:got])

	data, dec_err := base64.decode(b64, allocator = context.allocator)
	if dec_err != nil {
		log.warnf("save %s invalid base64", label)
		return false
	}
	defer delete(data)

	if !decode_save(
		data,
		label,
		seed,
		count,
		bits,
		apostle_bits,
		run_stats,
		stats_pledged,
		coins,
	) {
		return false
	}
	log.infof("loaded save %s", label)
	return true
}

save_game :: proc(
	path: string,
	seed: u64,
	count: int,
	bits: []u8,
	apostle_bits: []u8,
	run_stats: person.Run_Stats,
	stats_pledged: person.Run_Stats,
	coins: u32,
) -> bool {
	_ = path
	label := WEB_SAVE_STORAGE_KEY
	log.infof("saving game %s", label)

	buf, ok := encode_save(seed, count, bits, apostle_bits, run_stats, stats_pledged, coins)
	if !ok {
		log.warnf("failed to encode save %s", label)
		return false
	}
	defer delete(buf)

	b64, enc_err := base64.encode(buf)
	if enc_err != nil {
		log.warnf("failed to encode save %s to base64", label)
		return false
	}
	cstr, cstr_err := strings.clone_to_cstring(b64, context.temp_allocator)
	if cstr_err != nil {
		return false
	}
	fivek_web_storage_set(cstr)
	log.infof("saved game %s", label)
	return true
}

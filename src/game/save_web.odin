#+build js
package game

import "core:c"
import "core:encoding/base64"
import "core:log"
import "core:strings"
import "../person"

foreign import "env"

@(default_calling_convention = "c")
foreign env {
	fivek_web_storage_get_len :: proc() -> int ---
	fivek_web_storage_get :: proc(buf: [^]u8, max_len: int) -> int ---
	fivek_web_storage_set :: proc(data: cstring) ---
	fivek_web_storage_remove :: proc() ---
	fivek_open_url :: proc(url: cstring) ---
}

save_exists :: proc(path: string) -> bool {
	_ = path
	return fivek_web_storage_get_len() > 0
}

delete_run_save_web :: proc(path: string) -> bool {
	_ = path
	fivek_web_storage_remove()
	log.info("removed web save")
	return true
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
	out: ^Run_Save_Out = nil,
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

	pt: f32
	rp: Run_Phase
	face: bool
	sub: u8
	px: f32
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
		&pt,
		&rp,
		&face,
		&sub,
		&px,
	) {
		return false
	}
	if out != nil {
		out^ = {
			ok                = true,
			play_time         = pt,
			run_phase         = rp,
			epilogue_face     = face,
			epilogue_sub      = sub,
			epilogue_player_x = px,
		}
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
	play_time: f32,
	run_phase: Run_Phase,
	epilogue_face: bool,
	epilogue_sub: u8,
	epilogue_player_x: f32,
) -> bool {
	_ = path
	label := WEB_SAVE_STORAGE_KEY
	log.infof("saving game %s", label)

	buf, ok := encode_save(
		seed,
		count,
		bits,
		apostle_bits,
		run_stats,
		stats_pledged,
		coins,
		play_time,
		run_phase,
		epilogue_face,
		epilogue_sub,
		epilogue_player_x,
	)
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

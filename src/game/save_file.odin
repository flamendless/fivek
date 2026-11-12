#+build !js
package game

import "core:log"
import "core:os"
import "../person"

Run_Save_Out :: struct {
	ok:                bool,
	play_time:         f32,
	run_phase:         Run_Phase,
	epilogue_face:     bool,
	epilogue_sub:      u8,
	epilogue_player_x: f32,
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
	log.infof("loading save %s", path)
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		log.warnf("failed to read save %s", path)
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
		path,
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
	log.infof("loaded save %s", path)
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
	log.infof("saving game %s", path)
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
		log.warnf("failed to encode save %s", path)
		return false
	}
	defer delete(buf)

	err := os.write_entire_file(path, buf)
	if err != nil {
		log.warnf("failed to write save %s", path)
		return false
	}
	log.infof("saved game %s", path)
	return true
}

save_exists :: proc(path: string) -> bool {
	return os.exists(path)
}

delete_run_save_file :: proc(path: string) -> bool {
	if !os.exists(path) {
		return true
	}
	err := os.remove(path)
	if err != nil {
		log.warnf("failed to remove save %s", path)
		return false
	}
	log.infof("removed save %s", path)
	return true
}

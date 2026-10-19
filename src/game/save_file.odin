#+build !js
package game

import "core:log"
import "core:os"
import "../person"

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
	log.infof("loading save %s", path)
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		log.warnf("failed to read save %s", path)
		return false
	}
	defer delete(data)

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
	) {
		return false
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
) -> bool {
	log.infof("saving game %s", path)
	buf, ok := encode_save(seed, count, bits, apostle_bits, run_stats, stats_pledged, coins)
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

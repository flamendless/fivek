#+build !js
package game

import "core:log"
import "core:mem"
import "core:os"
import "../person"

Career_Stats_File :: struct {
	magic: [5]u8,
	stats: person.Career_Stats,
}

career_file_magic_ok :: proc(magic: [5]u8) -> bool {
	return magic == CAREER_STATS_MAGIC
}

read_career_stats_file :: proc() -> (stats: person.Career_Stats, ok: bool) {
	data, err := os.read_entire_file_from_path(CAREER_STATS_FILENAME, context.temp_allocator)
	if err != nil || len(data) < size_of(Career_Stats_File) {
		return person.career_stats_default(), false
	}
	file: Career_Stats_File
	mem.copy(&file, &data[0], size_of(Career_Stats_File))
	if !career_file_magic_ok(file.magic) {
		return person.career_stats_default(), false
	}
	if file.stats.version == 0 {
		file.stats.version = person.CAREER_STATS_VERSION
	}
	return file.stats, true
}

write_career_stats_file :: proc(stats: ^person.Career_Stats) {
	log.infof("saving career stats %s", CAREER_STATS_FILENAME)
	stats.version = person.CAREER_STATS_VERSION
	file := Career_Stats_File{magic = CAREER_STATS_MAGIC, stats = stats^}
	bytes := ([^]u8)(&file)[:size_of(Career_Stats_File)]
	if err := os.write_entire_file(CAREER_STATS_FILENAME, bytes); err != nil {
		log.warnf("failed to write career stats %s", CAREER_STATS_FILENAME)
	}
}

load_career_stats :: proc() -> person.Career_Stats {
	stats, ok := read_career_stats_file()
	if !ok {
		log.info("career stats: no file, starting fresh")
		return person.career_stats_default()
	}
	log.info("career stats loaded")
	return stats
}

save_career_stats :: proc(stats: ^person.Career_Stats) {
	write_career_stats_file(stats)
}

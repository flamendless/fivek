#+build !js
package game

import "core:log"
import "core:mem"
import "core:os"
import "../achievements"

ACHIEVEMENTS_MAGIC :: [5]u8 {0x66, 0x6C, 0x61, 0x6D, 0x41}

Achievements_File :: struct {
	magic: [5]u8,
	state: achievements.State,
}

achievements_file_magic_ok :: proc(magic: [5]u8) -> bool {
	return magic == ACHIEVEMENTS_MAGIC
}

read_achievements_file :: proc() -> (state: achievements.State, ok: bool) {
	data, err := os.read_entire_file_from_path(ACHIEVEMENTS_FILENAME, context.temp_allocator)
	if err != nil || len(data) < size_of(Achievements_File) {
		return achievements.state_default(), false
	}
	file: Achievements_File
	mem.copy(&file, &data[0], size_of(Achievements_File))
	if !achievements_file_magic_ok(file.magic) {
		return achievements.state_default(), false
	}
	if file.state.version == 0 {
		file.state.version = achievements.ACHIEVEMENTS_VERSION
	}
	return file.state, true
}

write_achievements_file :: proc(state: ^achievements.State) {
	log.infof("saving achievements %s", ACHIEVEMENTS_FILENAME)
	state.version = achievements.ACHIEVEMENTS_VERSION
	file := Achievements_File{magic = ACHIEVEMENTS_MAGIC, state = state^}
	bytes := ([^]u8)(&file)[:size_of(Achievements_File)]
	if err := os.write_entire_file(ACHIEVEMENTS_FILENAME, bytes); err != nil {
		log.warnf("failed to write achievements %s", ACHIEVEMENTS_FILENAME)
	}
}

load_achievements :: proc() -> achievements.State {
	state, ok := read_achievements_file()
	if !ok {
		log.info("achievements: no file, starting fresh")
		return achievements.state_default()
	}
	log.info("achievements loaded")
	return state
}

save_achievements :: proc(state: ^achievements.State) {
	write_achievements_file(state)
}

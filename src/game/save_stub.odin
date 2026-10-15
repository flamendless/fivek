#+build js
package game

load_save :: proc(path: string, seed: u64, count: int, bits: []u8) -> bool {
	_ = path
	_ = seed
	_ = count
	_ = bits
	return false
}

save_game :: proc(path: string, seed: u64, count: int, bits: []u8) -> bool {
	_ = path
	_ = seed
	_ = count
	_ = bits
	return false
}

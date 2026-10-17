#+build js
package game

load_save :: proc(path: string, seed: u64, count: int, bits: []u8, apostle_bits: []u8) -> bool {
	_ = path
	_ = seed
	_ = count
	_ = bits
	_ = apostle_bits
	return false
}

save_game :: proc(path: string, seed: u64, count: int, bits: []u8, apostle_bits: []u8) -> bool {
	_ = path
	_ = seed
	_ = count
	_ = bits
	_ = apostle_bits
	return false
}

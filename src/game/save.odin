package game

served_bit_bytes :: proc(count: int) -> int {
	return (count + 7) / 8
}

package game

import "../person"

served_bit_bytes :: proc(count: int) -> int {
	return (count + 7) / 8
}

apostle_bit_bytes :: proc() -> int {
	return person.apostle_bit_bytes()
}

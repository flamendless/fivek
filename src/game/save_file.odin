#+build !js
package game

import "core:mem"
import "core:os"

Save_Header :: struct {
	seed: u64,
	count: u32,
}

load_save :: proc(path: string, seed: u64, count: int, bits: []u8, apostle_bits: []u8) -> bool {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		return false
	}
	defer delete(data)

	need := size_of(Save_Header) + len(bits)
	if len(data) < need {
		return false
	}

	header: Save_Header
	mem.copy(&header, &data[0], size_of(Save_Header))
	if header.seed != seed || int(header.count) != count {
		return false
	}

	off := size_of(Save_Header)
	mem.copy(&bits[0], &data[off], len(bits))
	off += len(bits)

	if len(apostle_bits) > 0 {
		for i in 0 ..< len(apostle_bits) {
			apostle_bits[i] = 0
		}
		extra := len(apostle_bits)
		if len(data) >= off + extra {
			mem.copy(&apostle_bits[0], &data[off], extra)
		}
	}
	return true
}

save_game :: proc(path: string, seed: u64, count: int, bits: []u8, apostle_bits: []u8) -> bool {
	buf: [dynamic]u8
	defer delete(buf)

	header := Save_Header{seed = seed, count = u32(count)}
	header_bytes := ([^]u8)(&header)[:size_of(Save_Header)]
	append(&buf, ..header_bytes)
	append(&buf, ..bits)
	if len(apostle_bits) > 0 {
		append(&buf, ..apostle_bits)
	}
	err := os.write_entire_file(path, buf[:])
	return err == nil
}

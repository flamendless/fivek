package game

import "core:log"
import "core:mem"
import "../person"

SAVE_VERSION :: 1
WEB_SAVE_STORAGE_KEY :: "fivek:save_fivek.bin"

Save_Header :: struct {
	version: u32,
	seed:    u64,
	count:   u32,
}

encode_save :: proc(
	seed: u64,
	count: int,
	bits: []u8,
	apostle_bits: []u8,
	run_stats: person.Run_Stats,
	stats_pledged: person.Run_Stats,
	coins: u32,
	allocator := context.allocator,
) -> ([]u8, bool) {
	buf: [dynamic]u8
	buf.allocator = allocator

	header := Save_Header{version = SAVE_VERSION, seed = seed, count = u32(count)}
	header_bytes := ([^]u8)(&header)[:size_of(Save_Header)]
	append(&buf, ..header_bytes)
	append(&buf, ..bits)
	if len(apostle_bits) > 0 {
		append(&buf, ..apostle_bits)
	}
	rs := run_stats
	sp := stats_pledged
	rs_bytes := ([^]u8)(&rs)[:size_of(person.Run_Stats)]
	append(&buf, ..rs_bytes)
	sp_bytes := ([^]u8)(&sp)[:size_of(person.Run_Stats)]
	append(&buf, ..sp_bytes)
	c := coins
	append(&buf, ..(([^]u8)(&c)[:size_of(u32)]))

	out := buf[:]
	if out == nil {
		return nil, false
	}
	return out, true
}

decode_save :: proc(
	data: []u8,
	label: string,
	seed: u64,
	count: int,
	bits: []u8,
	apostle_bits: []u8,
	run_stats: ^person.Run_Stats,
	stats_pledged: ^person.Run_Stats,
	coins: ^u32,
) -> bool {
	need := size_of(Save_Header) + len(bits)
	if len(data) < need {
		log.warnf("save %s too small (%d bytes, need %d)", label, len(data), need)
		return false
	}

	header: Save_Header
	mem.copy(&header, &data[0], size_of(Save_Header))
	if header.seed != seed || int(header.count) != count {
		log.warnf(
			"save %s mismatch (file seed=%d count=%d, expected seed=%d count=%d)",
			label,
			header.seed,
			header.count,
			seed,
			count,
		)
		return false
	}
	if header.version != SAVE_VERSION {
		log.warnf("save %s unsupported version %d", label, header.version)
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
			off += extra
		}
	}

	stat_sz := size_of(person.Run_Stats)
	if run_stats != nil && len(data) >= off + stat_sz {
		mem.copy(run_stats, &data[off], stat_sz)
		off += stat_sz
	}
	if stats_pledged != nil && len(data) >= off + stat_sz {
		mem.copy(stats_pledged, &data[off], stat_sz)
		off += stat_sz
	}
	if coins != nil && len(data) >= off + size_of(u32) {
		mem.copy(coins, &data[off], size_of(u32))
	}
	return true
}

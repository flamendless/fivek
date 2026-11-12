package person

CAREER_STATS_VERSION :: 1

Career_Stats :: struct {
	version:                  u32,
	lifetime:                 Run_Stats,
	apostle_recruits:         [APOSTLE_COUNT]u32,
	post_celebrate_lineup:    u32,
	post_celebrate_home:      u32,
	runs_started:             u32,
	runs_won:                 u32,
	total_play_time_s:        u32,
	total_coins:              u32,
}

career_stats_default :: proc() -> Career_Stats {
	return {version = CAREER_STATS_VERSION}
}

career_merge_run_stats :: proc(c: ^Career_Stats, run: Run_Stats) {
	for k in Stat_Kind {
		stat_add(&c.lifetime, k, stat_value(run, k))
	}
}

career_record_apostle_recruit :: proc(c: ^Career_Stats, apostle_idx: int) {
	if c == nil || apostle_idx < 0 || apostle_idx >= APOSTLE_COUNT {
		return
	}
	c.apostle_recruits[apostle_idx] += 1
}

career_record_post_celebrate_route :: proc(c: ^Career_Stats, lineup: bool) {
	if c == nil {
		return
	}
	if lineup {
		c.post_celebrate_lineup += 1
	} else {
		c.post_celebrate_home += 1
	}
}

career_apostle_recruits_total :: proc(c: Career_Stats) -> u32 {
	total: u32
	for a in 0 ..< APOSTLE_COUNT {
		total += c.apostle_recruits[a]
	}
	return total
}

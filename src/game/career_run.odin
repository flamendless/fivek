package game

import "core:log"
import "../person"

CAREER_STATS_MAGIC :: [5]u8 {0x66, 0x6C, 0x61, 0x6D, 0x39}

career_commit_run :: proc(g: ^Game, won: bool) {
	if g.career_committed {
		return
	}
	if g.mode != .Playing && !won {
		return
	}

	person.career_merge_run_stats(&g.career, g.run.run_stats)
	g.career.total_coins += g.run.coins
	g.career.total_play_time_s += u32(g.run.play_time)
	if won {
		g.career.runs_won += 1
	}
	g.career_committed = true
	save_career_stats(&g.career)
	log.infof("career run committed (won=%v)", won)
}

career_on_run_start :: proc(g: ^Game) {
	g.career_committed = false
	g.career.runs_started += 1
	save_career_stats(&g.career)
}

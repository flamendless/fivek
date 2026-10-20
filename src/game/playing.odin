package game

import "core:fmt"
import w "../world"

PLAYING_HUD_FONT_DESIGN :: 12
PLAYING_HUD_ICON_DESIGN :: 22

player_chunk :: proc(g: ^Game) -> int {
	if g.scene.level == nil || g.scene.player == nil {
		return 0
	}
	cx := g.scene.player.pos.x + g.scene.player.size.x * 0.5
	return w.chunk_index_at_x(g.scene.level, cx)
}

sync_persist_chunk :: proc(g: ^Game) {
	g.run.persist_chunk = player_chunk(g)
}

maybe_persist_on_chunk_change :: proc(g: ^Game) {
	chunk := player_chunk(g)
	if chunk == g.run.persist_chunk {
		return
	}
	g.run.persist_chunk = chunk
	persist_run(g)
}

persist_run :: proc(g: ^Game) {
	save_game(
		g.persist.save_path,
		g.seed.value,
		g.run.person_count,
		g.run.served_bits,
		g.run.apostle_bits,
		g.run.run_stats,
		g.run.stats_pledged,
		g.run.coins,
	)
}

format_play_time :: proc(seconds: f32) -> cstring {
	total := int(seconds)
	if total < 0 {
		total = 0
	}
	mins := total / 60
	secs := total % 60
	return fmt.ctprintf("%02d:%02d", mins, secs)
}

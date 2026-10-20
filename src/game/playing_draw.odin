package game

import rl "vendor:raylib"
import "../config"
import "../currency"
import "../person"
import "../player"
import "../theme"
import w "../world"

draw_playing :: proc(g: ^Game) {
	view := camera_view_rect(g)

	rl.BeginMode2D(g.cameras.camera)
		if g.scene.bg != nil {
			draw_parallax_bg(g.scene.bg, g.cameras.camera.target.x, view)
		}
		if g.scene.ground != nil {
			rl.DrawRectangleV(g.scene.ground.pos, g.scene.ground.size, rl.BROWN)
		}
		person.draw_people(g.scene.people, view)
		person.draw_food_bubbles(g.scene.people, view)
		currency.draw_drops(&g.run.dropped_coins, view)
		avail := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
		person.draw_apostle_overlays(g.scene.people, view, g.scene.player.pos, g.scene.player.size, avail)
		person.draw_apostle_perk_bubbles(g.scene.people, view)
		if g.input.interact_index >= 0 {
			person.draw_person_outline(g.scene.people, g.input.interact_index, rl.RED)
		}
		if g.input.apostle_interact_index >= 0 {
			person.draw_person_outline(g.scene.people, g.input.apostle_interact_index, theme.DEBUG_CYAN)
		}
		player.draw(g.scene.player)
		when config.IS_DEBUG {
			if playing_debug_visible(g) && g.scene.level != nil {
				w.debug_draw_chunks(g.scene.level, g.scene.ground, ui_font(g, 8), g.cameras.camera.zoom)
			}
			if playing_debug_visible(g) && g.scene.people.debug.apostle_inspector_open {
				person.draw_apostle_debug_world_labels(g.scene.people, view, ui_font(g, 8))
			}
		}
	rl.EndMode2D()

	draw_playing_overlay(g)
	draw_pause_overlay(g)
	when config.IS_DEBUG {
		draw_playing_debug_overlay(g)
		debug_draw_camera(g)
	}
}

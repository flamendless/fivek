package game

import "core:fmt"
import rl "vendor:raylib"
import "../config"
import "../input"
import "../person"
import "../player"
import w "../world"

update_playing :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	when config.IS_AUTOTEST {
		if g.autoplay {
			dt *= AUTOPLAY_SIM_SPEED
			autobot_tick(g)
		}
	}

	player.update(g.player, g.ground, g.world_width, dt)

	view := camera_view_rect(g)
	update_camera(g)
	person.update_people(g.people, view, g.frame, dt)

	fish_down := input.key_down(.F)
	bread_down := input.key_down(.B)
	g.interact_index = person.nearest_interact_index(
		g.people,
		g.player.pos,
		g.player.size,
		g.defs.interact_radius,
	)

	if fish_down && !g.fish_was_down {
		person.try_give_item(
			g.people,
			g.player.pos,
			g.player.size,
			g.defs.interact_radius,
			.Fish,
		)
	}
	if bread_down && !g.bread_was_down {
		person.try_give_item(
			g.people,
			g.player.pos,
			g.player.size,
			g.defs.interact_radius,
			.Bread,
		)
	}
	g.fish_was_down = fish_down
	g.bread_was_down = bread_down

	before := person.count_served(g.people)
	person.sync_served_bits(g.people, g.served_bits)
	after := person.count_served(g.people)
	if after > before {
		save_game(g.save_path, g.seed, g.person_count, g.served_bits)
	}
	if after >= g.person_count && g.person_count > 0 && person.sim_settled(g.people) {
		begin_victory_march(g)
	}
}

when config.IS_DEBUG {
	playing_debug_visible :: proc(g: ^Game) -> bool {
		when config.IS_AUTOTEST {
			return g.autoplay || g.defs.debug
		}
		return g.defs.debug
	}

	draw_playing_debug_overlay :: proc(g: ^Game) {
		if !playing_debug_visible(g) {
			return
		}
		speed: f32 = 1.0
		when config.IS_AUTOTEST {
			if g.autoplay {
				speed = AUTOPLAY_SIM_SPEED
			}
		}
		speed_label := fmt.ctprintf("Speed %.1fx", speed)
		bg_label: cstring
		if g.bg != nil {
			bg_label = fmt.ctprintf("bg %s", g.bg.set_name)
		} else {
			bg_label = "bg (none)"
		}
		font := ui_font(g, 8)
		pad := ui_px(g, 4)
		line_gap := ui_px(g, 1)
		w_speed := rl.MeasureText(speed_label, font)
		w_bg := rl.MeasureText(bg_label, font)
		w := max(w_speed, w_bg)
		x := i32(g.game_size.x) - w - pad
		y: i32 = pad
		panel_h := font * 2 + line_gap + 2
		rl.BeginMode2D(g.ui_camera)
			rl.DrawRectangle(x - ui_px(g, 2), y - 1, w + ui_px(g, 4), panel_h, {0, 0, 0, 160})
			rl.DrawText(speed_label, x, y, font, rl.YELLOW)
			rl.DrawText(bg_label, x, y + font + line_gap, font, rl.GRAY)
		rl.EndMode2D()
	}
}

draw_playing :: proc(g: ^Game) {
	view := camera_view_rect(g)

	rl.BeginMode2D(g.camera)
		if g.bg != nil {
			draw_parallax_bg(g.bg, g.camera.target.x, view)
		}
		if g.bg == nil {
			rl.DrawRectangleV(g.ground.pos, g.ground.size, rl.BROWN)
		}
		person.draw_people(g.people, view)
		if g.interact_index >= 0 {
			person.draw_person_outline(g.people, g.interact_index, rl.RED)
		}
		player.draw(g.player)
		when config.IS_DEBUG {
			if playing_debug_visible(g) && g.level != nil {
				w.debug_draw_chunks(g.level, g.ground, ui_font(g, 8))
			}
		}
	rl.EndMode2D()

	draw_playing_overlay(g)
	when config.IS_DEBUG {
		draw_playing_debug_overlay(g)
		debug_draw_camera(g)
	}
}

draw_playing_overlay :: proc(g: ^Game) {
	served := person.count_served(g.people)
	font := ui_font(g, 8)
	pad := ui_px(g, 4)
	inner := pad + ui_px(g, 4)
	panel_w := ui_px(g, 148)
	panel_h := ui_px(g, 92)
	rl.BeginMode2D(g.ui_camera)
		rl.DrawRectangle(pad, pad, panel_w, panel_h, {0, 0, 0, 180})
		y: i32 = pad + ui_px(g, 2)
		rl.DrawText(fmt.ctprintf("Served %d / %d", served, g.person_count), inner, y, font, rl.WHITE)
		y += font + ui_px(g, 2)
		rl.DrawText("A / D  Walk", inner, y, font, rl.LIGHTGRAY)
		y += font + ui_px(g, 1)
		rl.DrawText("Shift  Run", inner, y, font, rl.LIGHTGRAY)
		y += font + ui_px(g, 1)
		rl.DrawText("F  Give fish", inner, y, font, rl.LIGHTGRAY)
		y += font + ui_px(g, 1)
		rl.DrawText("B  Give bread", inner, y, font, rl.LIGHTGRAY)
		y += font + ui_px(g, 2)
		bar_x: i32 = inner
		bar_w := ui_px(g, 100)
		bar_h := ui_px(g, 5)
		rl.DrawRectangle(bar_x, y, bar_w, bar_h, {40, 40, 40, 200})
		ratio := g.player.stamina / player.STAMINA_MAX
		fill_w := i32(f32(bar_w) * ratio)
		if fill_w > 0 {
			fill_col := rl.GREEN
			if ratio < 0.33 {
				fill_col = rl.ORANGE
			}
			if g.player.exhausted {
				if player.exhaust_flash_on() {
					fill_col = rl.RED
				} else {
					fill_col = {40, 40, 40, 200}
				}
			}
			rl.DrawRectangle(bar_x, y, fill_w, bar_h, fill_col)
		} else if g.player.exhausted && player.exhaust_flash_on() {
			rl.DrawRectangle(bar_x, y, bar_w, bar_h, rl.RED)
		}
		y += bar_h + ui_px(g, 2)
		rl.DrawText(fmt.ctprintf("FPS %d", rl.GetFPS()), inner, y, font, rl.GRAY)
	rl.EndMode2D()
}

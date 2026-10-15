package game

import "core:fmt"
import rl "vendor:raylib"

update_title :: proc(g: ^Game) {
	for i in 0 ..< 10 {
		if rl.IsKeyPressed(rl.KeyboardKey.ZERO + rl.KeyboardKey(i)) {
			append_seed_digit(g, u8('0' + i))
		}
	}
	if rl.IsKeyPressed(.BACKSPACE) && g.seed_len > 0 {
		g.seed_len -= 1
	}
	if rl.IsKeyPressed(.ENTER) {
		start_run(g, false)
	}
	if rl.IsKeyPressed(.C) {
		start_run(g, true)
	}
}

append_seed_digit :: proc(g: ^Game, ch: u8) {
	if g.seed_len >= len(g.seed_text) - 1 {
		return
	}
	g.seed_text[g.seed_len] = ch
	g.seed_len += 1
}

draw_title :: proc(g: ^Game) {
	title_font := ui_font(g, 20)
	body_font := ui_font(g, 16)
	ver_font := ui_font(g, 12)
	x := ui_px(g, 20)
	rl.BeginMode2D(g.ui_camera)
		rl.DrawText(fmt.ctprintf("%s", g.defs.title), x, ui_px(g, 40), title_font, rl.WHITE)
		rl.DrawText("Seed:", x, ui_px(g, 80), body_font, rl.GRAY)
		rl.DrawText(
			fmt.ctprintf("%.*s", g.seed_len, &g.seed_text[0]),
			ui_px(g, 80),
			ui_px(g, 80),
			body_font,
			rl.WHITE,
		)
		rl.DrawText("Enter - New game", x, ui_px(g, 120), body_font, rl.LIGHTGRAY)
		rl.DrawText("C - Continue (save)", x, ui_px(g, 140), body_font, rl.LIGHTGRAY)
		rl.DrawText("0-9 type seed", x, ui_px(g, 160), body_font, rl.LIGHTGRAY)

		ver := fmt.ctprintf("build: v%s", g.defs.version)
		ver_w := rl.MeasureText(ver, ver_font)
		ver_pad := ui_px(g, 8)
		ver_x := i32(g.game_size.x) - ver_w - ver_pad
		ver_y := i32(g.game_size.y) - ver_font - ver_pad
		rl.DrawText(ver, ver_x, ver_y, ver_font, rl.GRAY)
	rl.EndMode2D()
}

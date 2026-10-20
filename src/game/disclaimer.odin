package game

import rl "vendor:raylib"
import "../theme"

DISCLAIMER_CONTINUE_DELAY: f32 = 4.0
DISCLAIMER_SKIP_DELAY: f32 = 1.0

DISCLAIMER_LINES: [4]cstring = {
	"Inspired by a biblical story, faithfully adapted with care.",
	"Gameplay may add imagined scenes and details to bring",
	"the account to life. The core story remains honored.",
	"We mean no offense or misinformation toward Scripture.",
}

Game_Disclaimer :: struct {
	elapsed: f32,
}

enter_disclaimer :: proc(g: ^Game) {
	g.mode = .Disclaimer
	g.disclaimer.elapsed = 0
}

disclaimer_prompt_delay :: proc(g: ^Game) -> f32 {
	if g.prefs.intro_seen {
		return DISCLAIMER_SKIP_DELAY
	}
	return DISCLAIMER_CONTINUE_DELAY
}

disclaimer_finish :: proc(g: ^Game) {
	if !g.prefs.intro_seen {
		g.prefs.intro_seen = true
		save_intro_seen()
	}
	g.mode = .Title
}

update_disclaimer :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	g.disclaimer.elapsed += dt

	if g.disclaimer.elapsed >= disclaimer_prompt_delay(g) && intro_skip_pressed() {
		disclaimer_finish(g)
	}
}

draw_disclaimer_line :: proc(g: ^Game, text: cstring, y: f32, font_size: f32, spacing: f32) {
	font := rl.GetFontDefault()
	w := rl.MeasureTextEx(font, text, font_size, spacing).x
	x := (g.view.game_size.x - w) * 0.5
	rl.DrawTextEx(font, text, {x, y}, font_size, spacing, theme.TEXT_INK)
}

draw_disclaimer_continue_hint :: proc(g: ^Game) {
	draw_bottom_center_hint(g, "Space / Enter / E - Continue")
}

draw_disclaimer :: proc(g: ^Game) {
	body := f32(ui_font(g, 18))
	char_spacing := f32(ui_px(g, 2))
	line_gap := f32(ui_px(g, 12))
	block_h := f32(len(DISCLAIMER_LINES)) * body + f32(len(DISCLAIMER_LINES) - 1) * line_gap
	y := (g.view.game_size.y - block_h) * 0.5

	rl.BeginMode2D(g.cameras.ui_camera)
	draw_title_pattern_bg(g)
	for line in DISCLAIMER_LINES {
		draw_disclaimer_line(g, line, y, body, char_spacing)
		y += body + line_gap
	}
	if g.disclaimer.elapsed >= disclaimer_prompt_delay(g) {
		if g.prefs.intro_seen {
			draw_skip_hint(g)
		} else {
			draw_disclaimer_continue_hint(g)
		}
	}
	rl.EndMode2D()
}

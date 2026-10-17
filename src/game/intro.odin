package game

import "core:math"
import rl "vendor:raylib"

SPLASH_LOGO_PATH :: "assets/flamendless_logo.png"

SPLASH_DURATION: f32 = 3.0
SPLASH_FADE_IN: f32 = 1.0
SPLASH_HOLD: f32 = 1.0
SPLASH_FADE_OUT: f32 = 1.0
DISCLAIMER_CONTINUE_DELAY: f32 = 4.0
DISCLAIMER_SKIP_DELAY: f32 = 1.0

SPLASH_LOGO_MAX_FRAC: f32 = 0.75
SPLASH_BYLINE: cstring = "a game by: flamendless"

load_intro_assets :: proc(g: ^Game) {
	if g.splash_logo.id != 0 {
		return
	}
	g.splash_logo = rl.LoadTexture(SPLASH_LOGO_PATH)
}

unload_intro_assets :: proc(g: ^Game) {
	if g.splash_logo.id != 0 {
		rl.UnloadTexture(g.splash_logo)
		g.splash_logo = {}
	}
}

intro_skip_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.E)
}

splash_alpha :: proc(elapsed: f32) -> f32 {
	if elapsed < SPLASH_FADE_IN {
		return elapsed / SPLASH_FADE_IN
	}
	hold_end := SPLASH_FADE_IN + SPLASH_HOLD
	if elapsed < hold_end {
		return 1.0
	}
	fade_t := elapsed - hold_end
	if fade_t >= SPLASH_FADE_OUT {
		return 0.0
	}
	return 1.0 - fade_t / SPLASH_FADE_OUT
}

draw_bottom_center_hint :: proc(g: ^Game, msg: cstring) {
	font := ui_font(g, 14)
	w := rl.MeasureText(msg, font)
	x := (i32(g.game_size.x) - w) / 2
	y: i32 = i32(g.game_size.y) - font - ui_px(g, 12)
	rl.DrawText(msg, x, y, font, rl.RED)
}

draw_skip_hint :: proc(g: ^Game) {
	draw_bottom_center_hint(g, "Space / Enter / E - Skip")
}

draw_disclaimer_continue_hint :: proc(g: ^Game) {
	draw_bottom_center_hint(g, "Space / Enter / E - Continue")
}

disclaimer_prompt_delay :: proc(g: ^Game) -> f32 {
	if g.intro_seen {
		return DISCLAIMER_SKIP_DELAY
	}
	return DISCLAIMER_CONTINUE_DELAY
}

enter_title_from_intro :: proc(g: ^Game) {
	if !g.intro_seen {
		g.intro_seen = true
		save_intro_seen()
	}
	g.mode = .Title
}

update_splash :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	g.splash_elapsed += dt

	if g.intro_seen && intro_skip_pressed() {
		g.mode = .Disclaimer
		g.disclaimer_elapsed = 0
		return
	}
	if g.splash_elapsed >= SPLASH_DURATION {
		g.mode = .Disclaimer
		g.disclaimer_elapsed = 0
	}
}

draw_splash :: proc(g: ^Game) {
	alpha := splash_alpha(g.splash_elapsed)
	rl.BeginMode2D(g.ui_camera)

	a := u8(math.clamp(alpha, 0, 1) * 255 + 0.5)
	text_color := rl.Color{255, 255, 255, a}

	byline_font := ui_font(g, 16)
	byline_w := rl.MeasureText(SPLASH_BYLINE, byline_font)
	byline_x := (i32(g.game_size.x) - byline_w) / 2
	byline_y := ui_px(g, 28)
	rl.DrawText(SPLASH_BYLINE, byline_x, byline_y, byline_font, text_color)

	if g.splash_logo.id != 0 && alpha > 0 {
		tw := f32(g.splash_logo.width)
		th := f32(g.splash_logo.height)
		max_w := g.game_size.x * SPLASH_LOGO_MAX_FRAC
		max_h := g.game_size.y * SPLASH_LOGO_MAX_FRAC
		scale := math.min(max_w / tw, max_h / th)
		dw := tw * scale
		dh := th * scale
		dest := rl.Rectangle{
			(g.game_size.x - dw) * 0.5,
			(g.game_size.y - dh) * 0.5,
			dw,
			dh,
		}
		src := rl.Rectangle{0, 0, tw, th}
		tint := rl.Color{255, 255, 255, a}
		rl.DrawTexturePro(g.splash_logo, src, dest, {}, 0, tint)
	}

	if g.intro_seen {
		draw_skip_hint(g)
	}

	rl.EndMode2D()
}

update_disclaimer :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	g.disclaimer_elapsed += dt

	if g.disclaimer_elapsed >= disclaimer_prompt_delay(g) && intro_skip_pressed() {
		enter_title_from_intro(g)
	}
}

draw_disclaimer_line :: proc(g: ^Game, text: cstring, y: f32, font_size: f32, spacing: f32) {
	font := rl.GetFontDefault()
	w := rl.MeasureTextEx(font, text, font_size, spacing).x
	x := (g.game_size.x - w) * 0.5
	rl.DrawTextEx(font, text, {x, y}, font_size, spacing, rl.WHITE)
}

draw_disclaimer :: proc(g: ^Game) {
	body := f32(ui_font(g, 18))
	char_spacing := f32(ui_px(g, 2))
	line_gap := f32(ui_px(g, 12))
	lines := []cstring{
		"Inspired by a biblical story, faithfully adapted with care.",
		"Gameplay may add imagined scenes and details to bring",
		"the account to life. The core story remains honored.",
		"We mean no offense or misinformation toward Scripture.",
	}
	block_h := f32(len(lines)) * body + f32(len(lines) - 1) * line_gap
	y := (g.game_size.y - block_h) * 0.5

	rl.BeginMode2D(g.ui_camera)
	for line in lines {
		draw_disclaimer_line(g, line, y, body, char_spacing)
		y += body + line_gap
	}
	if g.disclaimer_elapsed >= disclaimer_prompt_delay(g) {
		if g.intro_seen {
			draw_skip_hint(g)
		} else {
			draw_disclaimer_continue_hint(g)
		}
	}
	rl.EndMode2D()
}

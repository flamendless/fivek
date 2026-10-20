package game

import "core:log"
import "core:math"
import rl "vendor:raylib"
import "../theme"

SPLASH_LOGO_PATH :: "assets/flamendless_logo.png"

SPLASH_DURATION: f32 = 3.0
SPLASH_FADE_IN: f32 = 1.0
SPLASH_HOLD: f32 = 1.0
SPLASH_FADE_OUT: f32 = 1.0

SPLASH_LOGO_MAX_FRAC: f32 = 0.75
SPLASH_BYLINE: cstring = "a game by: flamendless"

Game_Splash :: struct {
	logo:    rl.Texture2D,
	elapsed: f32,
}

load_splash_assets :: proc(g: ^Game) {
	if g.splash.logo.id != 0 {
		return
	}
	log.infof("loading splash logo %s", SPLASH_LOGO_PATH)
	g.splash.logo = rl.LoadTexture(SPLASH_LOGO_PATH)
	if g.splash.logo.id == 0 {
		log.warnf("failed to load splash logo %s", SPLASH_LOGO_PATH)
	} else {
		rl.SetTextureFilter(g.splash.logo, .POINT)
	}
}

unload_splash_assets :: proc(g: ^Game) {
	if g.splash.logo.id != 0 {
		log.infof("unloading splash logo %s", SPLASH_LOGO_PATH)
		rl.UnloadTexture(g.splash.logo)
		g.splash.logo = {}
	}
}

intro_skip_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.E)
}

draw_bottom_center_hint :: proc(g: ^Game, msg: cstring) {
	font := ui_font(g, 14)
	w := rl.MeasureText(msg, font)
	x := (i32(g.view.game_size.x) - w) / 2
	y: i32 = i32(g.view.game_size.y) - font - ui_px(g, 12)
	rl.DrawText(msg, x, y, font, rl.RED)
}

draw_skip_hint :: proc(g: ^Game) {
	draw_bottom_center_hint(g, "Space / Enter / E - Skip")
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

update_splash :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	g.splash.elapsed += dt

	if g.prefs.intro_seen && intro_skip_pressed() {
		enter_disclaimer(g)
		return
	}
	if g.splash.elapsed >= SPLASH_DURATION {
		enter_disclaimer(g)
	}
}

draw_splash :: proc(g: ^Game) {
	alpha := splash_alpha(g.splash.elapsed)
	rl.BeginMode2D(g.cameras.ui_camera)

	a := u8(math.clamp(alpha, 0, 1) * 255 + 0.5)
	text_color := theme.white_alpha(a)

	byline_font := ui_font(g, 16)
	byline_w := rl.MeasureText(SPLASH_BYLINE, byline_font)
	byline_x := (i32(g.view.game_size.x) - byline_w) / 2
	byline_y := ui_px(g, 28)
	rl.DrawText(SPLASH_BYLINE, byline_x, byline_y, byline_font, text_color)

	if g.splash.logo.id != 0 && alpha > 0 {
		tw := f32(g.splash.logo.width)
		th := f32(g.splash.logo.height)
		max_w := g.view.game_size.x * SPLASH_LOGO_MAX_FRAC
		max_h := g.view.game_size.y * SPLASH_LOGO_MAX_FRAC
		scale := math.min(max_w / tw, max_h / th)
		dw := tw * scale
		dh := th * scale
		dest := rl.Rectangle{
			(g.view.game_size.x - dw) * 0.5,
			(g.view.game_size.y - dh) * 0.5,
			dw,
			dh,
		}
		src := rl.Rectangle{0, 0, tw, th}
		tint := theme.white_alpha(a)
		rl.DrawTexturePro(g.splash.logo, src, dest, {}, 0, tint)
	}

	if g.prefs.intro_seen {
		draw_skip_hint(g)
	}

	rl.EndMode2D()
}

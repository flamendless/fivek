package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import rl "vendor:raylib"
import "../assets"
import "../pattern_bg"
import "../theme"

TITLE_HEADLINE_SHOLOM :: "Bread, Fish, Repeat"
TITLE_HEADLINE_SUFFIX :: "5000x"
TITLE_HEADLINE_SUFFIX_FONT_DESIGN :: 28
TITLE_VERSION_FONT_DESIGN :: 12

TITLE_PATTERN_CELLS_ACROSS :: 2
TITLE_PATTERN_ZOOM_MIN :: 1.5
TITLE_PATTERN_ZOOM_MAX :: 3.0
TITLE_PATTERN_SPEED_MIN :: 14.0
TITLE_PATTERN_SPEED_MAX :: 22.0

Title_Menu :: enum {
	Primary,
	New_Game,
	Tutorial,
	Stats,
	Achievements,
	Settings,
	Credits,
	Exit,
}

title_menu_slot_count :: proc(g: ^Game) -> int {
	if title_has_save(g) {
		return 8
	}
	return 7
}

title_menu_slot_item :: proc(g: ^Game, slot: int) -> Title_Menu {
	if title_has_save(g) {
		items := [8]Title_Menu{
			.Primary,
			.New_Game,
			.Tutorial,
			.Stats,
			.Achievements,
			.Settings,
			.Credits,
			.Exit,
		}
		return items[slot]
	}
	items := [7]Title_Menu{
		.Primary,
		.Tutorial,
		.Stats,
		.Achievements,
		.Settings,
		.Credits,
		.Exit,
	}
	return items[slot]
}

title_run_new_game :: proc(g: ^Game) {
	delete_run_save(g.persist.save_path)
	start_run(g, false)
}

Game_Title :: struct {
	settings_open:  bool,
	hovered_menu:      int,
	hovered_social:    int,
	hovered_settings:  int,
	pattern:        ^pattern_bg.Screen_Pattern,
	fx:             Game_Title_Fx,
}

title_pattern_config :: proc() -> pattern_bg.Config {
	variant := pattern_bg.random_variant()
	return {
		bg_color   = theme.random_pattern_bg_color(),
		variant    = variant,
		subvariant = pattern_bg.random_subvariant(variant),
		direction  = pattern_bg.random_direction(),
		speed      = TITLE_PATTERN_SPEED_MIN + rand.float32() * (TITLE_PATTERN_SPEED_MAX - TITLE_PATTERN_SPEED_MIN),
		zoom       = TITLE_PATTERN_ZOOM_MIN + rand.float32() * (TITLE_PATTERN_ZOOM_MAX - TITLE_PATTERN_ZOOM_MIN),
	}
}

load_title_assets :: proc(g: ^Game) {
	refresh_title_pattern(g)
}

refresh_title_pattern :: proc(g: ^Game) {
	if g.title.pattern == nil {
		p, ok := pattern_bg.create(title_pattern_config())
		if !ok {
			log.warn("failed to create title pattern background")
		} else {
			g.title.pattern = p
		}
		return
	}
	if !pattern_bg.set_config(g.title.pattern, title_pattern_config()) {
		log.warn("title: failed to refresh pattern background")
	}
}

pattern_screen_mode :: proc(mode: Game_Mode) -> bool {
	return mode == .Title || mode == .Stats || mode == .Achievements || mode == .Tutorial || mode == .Credits
}

unload_title_assets :: proc(g: ^Game) {
	title_fx_on_leave(g)
	delete(g.title.fx.fish)
	pattern_bg.destroy(g.title.pattern)
	g.title.pattern = nil
}

reload_title_random :: proc(g: ^Game) {
	refresh_title_pattern(g)
	title_fx_reset(g)
}

title_ui_font :: proc(g: ^Game) -> rl.Font {
	font := assets.boot_title_font()
	if font.texture.id != 0 {
		return font
	}
	return rl.GetFontDefault()
}

title_font_size :: proc(g: ^Game, design: f32) -> f32 {
	return f32(ui_px(g, design))
}

title_char_spacing :: proc(g: ^Game, design: f32) -> f32 {
	return f32(ui_px(g, design))
}

title_measure :: proc(g: ^Game, text: cstring, size, spacing: f32) -> rl.Vector2 {
	return rl.MeasureTextEx(title_ui_font(g), text, size, spacing)
}

title_text_outline_px :: proc(g: ^Game) -> f32 {
	return f32(max(ui_px(g, 1), 1))
}

@(private = "file")
title_draw_text_outlined :: proc(
	font: rl.Font,
	text: cstring,
	pos: rl.Vector2,
	size, spacing, outline_px: f32,
	fill, outline: rl.Color,
) {
	for dx in -1 ..= 1 {
		for dy in -1 ..= 1 {
			if dx == 0 && dy == 0 do continue
			rl.DrawTextEx(
				font,
				text,
				{pos.x + f32(dx) * outline_px, pos.y + f32(dy) * outline_px},
				size,
				spacing,
				outline,
			)
		}
	}
	rl.DrawTextEx(font, text, pos, size, spacing, fill)
}

title_draw_centered :: proc(g: ^Game, text: cstring, y: f32, size, spacing: f32, color: rl.Color) {
	m := title_measure(g, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	rl.DrawTextEx(title_ui_font(g), text, {x, y}, size, spacing, color)
}

title_draw_centered_outlined :: proc(
	g: ^Game,
	text: cstring,
	y: f32,
	size, spacing: f32,
	fill, outline: rl.Color,
) {
	m := title_measure(g, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	title_draw_text_outlined(title_ui_font(g), text, {x, y}, size, spacing, title_text_outline_px(g), fill, outline)
}

title_measure_default :: proc(g: ^Game, text: cstring, design: i32) -> rl.Vector2 {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	return rl.MeasureTextEx(font, text, size, spacing)
}

title_draw_centered_default :: proc(g: ^Game, text: cstring, y: f32, design: i32, color: rl.Color) {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	m := rl.MeasureTextEx(font, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	rl.DrawTextEx(font, text, {x, y}, size, spacing, color)
}

title_draw_centered_default_outlined :: proc(
	g: ^Game,
	text: cstring,
	y: f32,
	design: i32,
	fill, outline: rl.Color,
) {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	m := rl.MeasureTextEx(font, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	title_draw_text_outlined(font, text, {x, y}, size, spacing, title_text_outline_px(g), fill, outline)
}

title_advance_headline_y :: proc(g: ^Game, start_y: f32) -> f32 {
	headline_size := title_font_size(g, 28)
	headline_spacing := title_char_spacing(g, 1)
	headline_gap := f32(ui_px(g, 4))
	y := start_y
	m := title_measure(g, TITLE_HEADLINE_SHOLOM, headline_size, headline_spacing)
	y += m.y + headline_gap
	m = title_measure_default(g, TITLE_HEADLINE_SUFFIX, TITLE_HEADLINE_SUFFIX_FONT_DESIGN)
	y += m.y + headline_gap
	return y
}

title_text_bounds :: proc(g: ^Game, text: cstring, y: f32, size, spacing: f32) -> rl.Rectangle {
	m := title_measure(g, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	pad := f32(ui_px(g, 6))
	return {x - pad, y - pad, m.x + pad * 2, m.y + pad * 2}
}

title_has_save :: proc(g: ^Game) -> bool {
	return save_exists(g.persist.save_path)
}

title_primary_label :: proc(g: ^Game) -> cstring {
	if title_has_save(g) {
		return "Continue"
	}
	return "Start"
}

title_run_primary :: proc(g: ^Game) {
	if title_has_save(g) {
		start_run(g, true)
		return
	}
	if g.prefs.tutorial_seen {
		start_run(g, false)
	} else {
		enter_tutorial(g, true)
	}
}

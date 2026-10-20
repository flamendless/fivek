package game

import "core:fmt"
import rl "vendor:raylib"
import "../pattern_bg"
import "../social"

draw_title_pattern_bg :: proc(g: ^Game) {
	if g.title.pattern != nil {
		bounds := rl.Rectangle{0, 0, g.view.game_size.x, g.view.game_size.y}
		pattern_bg.draw_grid(g.title.pattern, bounds, TITLE_PATTERN_CELLS_ACROSS)
	}
}

draw_title :: proc(g: ^Game) {
	headline_size := title_font_size(g, 28)
	headline_spacing := title_char_spacing(g, 1)
	menu_size := title_font_size(g, 20)
	menu_spacing := title_char_spacing(g, 1)
	menu_step := f32(ui_px(g, 28))

	rl.BeginMode2D(g.cameras.ui_camera)

	draw_title_pattern_bg(g)

	title_fx_draw_fish(g)

	top := f32(ui_px(g, 32))
	headline_gap := f32(ui_px(g, 4))
	y := top
	title_draw_centered_outlined(g, TITLE_HEADLINE_SHOLOM, y, headline_size, headline_spacing, rl.WHITE, rl.BLACK)
	m := title_measure(g, TITLE_HEADLINE_SHOLOM, headline_size, headline_spacing)
	y += m.y + headline_gap
	title_draw_centered_default_outlined(
		g,
		TITLE_HEADLINE_SUFFIX,
		y,
		TITLE_HEADLINE_SUFFIX_FONT_DESIGN,
		rl.WHITE,
		rl.BLACK,
	)
	m = title_measure_default(g, TITLE_HEADLINE_SUFFIX, TITLE_HEADLINE_SUFFIX_FONT_DESIGN)
	y += m.y + headline_gap

	_, menu_y := title_menu_layout(g, menu_size, menu_spacing, menu_step)
	items := [5]Title_Menu{.Primary, .Tutorial, .Settings, .Credits, .Exit}
	for item in items {
		label := title_menu_label(item, g)
		color := rl.BLACK
		if g.title.hovered_menu == int(item) {
			color = rl.WHITE
		}
		title_draw_centered(g, label, menu_y, menu_size, menu_spacing, color)
		menu_y += menu_step
	}

	social.draw_row(g.title.social_atlas, g.title.hovered_social, true, g.view.game_size, g.view.ui_scale)

	ver := fmt.ctprintf("build: v%s", g.defs.version)
	ver_m := title_measure_default(g, ver, TITLE_VERSION_FONT_DESIGN)
	ver_pad := f32(ui_px(g, 8))
	ver_x := g.view.game_size.x - ver_m.x - ver_pad
	ver_y := g.view.game_size.y - ver_m.y - ver_pad
	ver_font := rl.GetFontDefault()
	ver_size := f32(ui_font(g, TITLE_VERSION_FONT_DESIGN))
	ver_spacing := title_char_spacing(g, 1)
	rl.DrawTextEx(ver_font, ver, {ver_x, ver_y}, ver_size, ver_spacing, rl.RED)

	if g.title.settings_open {
		draw_title_settings_overlay(g)
	}

	title_fx_draw_bread(g)

	rl.EndMode2D()
}

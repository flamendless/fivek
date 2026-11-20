package game

import rl "vendor:raylib"
import "../assets"
import ui_assets "../ui"
import "../theme"

SETTINGS_FULLSCREEN_LABEL :: "Fullscreen"
SETTINGS_CREDITS_LABEL :: "Credits"

title_settings_layout :: proc(g: ^Game) -> (fullscreen_y, credits_y: f32, menu_size, menu_spacing: f32) {
	settings_size := title_font_size(g, 24)
	settings_spacing := title_char_spacing(g, 1)
	menu_size = title_font_size(g, 20)
	menu_spacing = title_char_spacing(g, 1)
	row_gap := f32(ui_px(g, 12))
	font := ui_font(g, 14)
	check_row := max(ui_checkbox_size(g), f32(font))
	block_h := title_measure(g, "Settings", settings_size, settings_spacing).y +
		row_gap +
		check_row +
		row_gap +
		title_measure(g, SETTINGS_CREDITS_LABEL, menu_size, menu_spacing).y
	sy := (g.view.game_size.y - block_h) * 0.5
	fullscreen_y = sy + title_measure(g, "Settings", settings_size, settings_spacing).y + row_gap
	credits_y = fullscreen_y + check_row + row_gap
	return fullscreen_y, credits_y, menu_size, menu_spacing
}

title_settings_credits_bounds :: proc(g: ^Game) -> rl.Rectangle {
	_, credits_y, menu_size, menu_spacing := title_settings_layout(g)
	return title_menu_button_bounds(g, SETTINGS_CREDITS_LABEL, credits_y, menu_size, menu_spacing)
}

update_title_settings :: proc(g: ^Game, mouse: rl.Vector2, clicked: bool) -> bool {
	g.title.hovered_settings = -1
	fullscreen_y, _, _, _ := title_settings_layout(g)
	font := ui_font(g, 14)
	row, box := ui_checkbox_row_bounds(g, SETTINGS_FULLSCREEN_LABEL, fullscreen_y, font)
	if rl.CheckCollisionPointRec(mouse, box) || rl.CheckCollisionPointRec(mouse, row) {
		g.title.hovered_settings = 0
		if clicked && ui_checkbox_row_hit(mouse, row, box) {
			display_set_fullscreen(g, !g.display.fullscreen)
			return true
		}
	}
	bounds := title_settings_credits_bounds(g)
	if rl.CheckCollisionPointRec(mouse, bounds) {
		g.title.hovered_settings = 1
		if clicked {
			enter_credits(g, false)
			return true
		}
	}
	return false
}

draw_title_settings_overlay :: proc(g: ^Game) {
	rl.DrawRectangle(0, 0, i32(g.view.game_size.x), i32(g.view.game_size.y), theme.OVERLAY_SCRIM_180)
	settings_size := title_font_size(g, 24)
	settings_spacing := title_char_spacing(g, 1)
	fullscreen_y, credits_y, menu_size, menu_spacing := title_settings_layout(g)
	row_gap := f32(ui_px(g, 12))
	h_m := title_measure(g, "Settings", settings_size, settings_spacing)
	sy := fullscreen_y - h_m.y - row_gap
	title_draw_centered(g, "Settings", sy, settings_size, settings_spacing, rl.WHITE)
	font := ui_font(g, 14)
	draw_checkbox_row(
		g,
		SETTINGS_FULLSCREEN_LABEL,
		fullscreen_y,
		font,
		g.display.fullscreen,
		g.title.hovered_settings == 0,
	)
	btn_bounds := title_settings_credits_bounds(g)
	btn: assets.Cozy_Button = .Normal
	if g.title.hovered_settings == 1 {
		btn = rl.IsMouseButtonDown(.LEFT) ? .Pressed : .Hover
	}
	ui_assets.draw_wood_button(btn, btn_bounds)
	title_draw_centered(g, SETTINGS_CREDITS_LABEL, credits_y, menu_size, menu_spacing, theme.TEXT_INK)
	draw_nav_button(g, "Back")
}
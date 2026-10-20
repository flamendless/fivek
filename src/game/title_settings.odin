package game

import rl "vendor:raylib"
import "../theme"

SETTINGS_CREDITS_LABEL :: "Credits"

title_settings_layout :: proc(g: ^Game) -> (credits_y: f32, menu_size, menu_spacing: f32) {
	settings_size := title_font_size(g, 24)
	settings_spacing := title_char_spacing(g, 1)
	menu_size = title_font_size(g, 20)
	menu_spacing = title_char_spacing(g, 1)
	block_gap := f32(ui_px(g, 12))
	h_m := title_measure(g, "Settings", settings_size, settings_spacing)
	block_h := h_m.y + block_gap + title_measure(g, SETTINGS_CREDITS_LABEL, menu_size, menu_spacing).y
	sy := (g.view.game_size.y - block_h) * 0.5
	credits_y = sy + h_m.y + block_gap
	return credits_y, menu_size, menu_spacing
}

title_settings_credits_bounds :: proc(g: ^Game) -> rl.Rectangle {
	credits_y, menu_size, menu_spacing := title_settings_layout(g)
	return title_text_bounds(g, SETTINGS_CREDITS_LABEL, credits_y, menu_size, menu_spacing)
}

update_title_settings :: proc(g: ^Game, mouse: rl.Vector2, clicked: bool) -> bool {
	g.title.hovered_settings = -1
	bounds := title_settings_credits_bounds(g)
	if rl.CheckCollisionPointRec(mouse, bounds) {
		g.title.hovered_settings = 0
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
	credits_y, menu_size, menu_spacing := title_settings_layout(g)
	block_gap := f32(ui_px(g, 12))
	h_m := title_measure(g, "Settings", settings_size, settings_spacing)
	sy := credits_y - h_m.y - block_gap
	title_draw_centered(g, "Settings", sy, settings_size, settings_spacing, rl.WHITE)
	color := rl.LIGHTGRAY
	if g.title.hovered_settings == 0 {
		color = rl.WHITE
	}
	title_draw_centered(g, SETTINGS_CREDITS_LABEL, credits_y, menu_size, menu_spacing, color)
	draw_nav_button(g, "Back")
}

package game

import rl "vendor:raylib"
import ui_assets "../ui"

UI_ICON_TEXT_GAP: f32 : 4

draw_icon_text_row :: proc(
	x, y: i32,
	font: i32,
	icon_size: f32,
	tex: rl.Texture2D,
	text: cstring,
	color: rl.Color,
) {
	icon_half := icon_size * 0.5
	cy := f32(y) + f32(font) * 0.5
	ui_assets.draw_texture_icon(tex, {f32(x) + icon_half, cy})
	text_x := i32(f32(x) + icon_size + UI_ICON_TEXT_GAP)
	rl.DrawText(text, text_x, y, font, color)
}

draw_icon_fn_text_row :: proc(
	x, y: i32,
	font: i32,
	icon_size: f32,
	icon: UI_Row_Icon,
	text: cstring,
	color: rl.Color,
) {
	layout_w := row_icon_layout_width(icon, icon_size)
	icon_half := layout_w * 0.5
	cy := f32(y) + f32(font) * 0.5
	draw_row_icon(icon, {f32(x) + icon_half, cy}, icon_size)
	text_x := i32(f32(x) + layout_w + UI_ICON_TEXT_GAP)
	rl.DrawText(text, text_x, y, font, color)
}

draw_centered_icon_text_row :: proc(
	g: ^Game,
	y: i32,
	font: i32,
	icon: UI_Row_Icon,
	text: cstring,
	color: rl.Color,
	icon_size: f32,
) {
	layout_w := row_icon_layout_width(icon, icon_size)
	text_w := rl.MeasureText(text, font)
	row_w := layout_w + UI_ICON_TEXT_GAP + f32(text_w)
	x := i32((g.view.game_size.x - row_w) * 0.5)
	icon_half := layout_w * 0.5
	cy := f32(y) + f32(font) * 0.5
	draw_row_icon(icon, {f32(x) + icon_half, cy}, icon_size)
	text_x := i32(f32(x) + layout_w + UI_ICON_TEXT_GAP)
	rl.DrawText(text, text_x, y, font, color)
}

ui_px :: proc(g: ^Game, design: f32) -> i32 {
	return i32(design * g.view.ui_scale + 0.5)
}

ui_font :: proc(g: ^Game, design: i32) -> i32 {
	size := i32(f32(design) * g.view.ui_scale + 0.5)
	return max(size, 8)
}

ui_mouse_game_pos :: proc(g: ^Game) -> rl.Vector2 {
	m := rl.GetMousePosition()
	return {m.x / g.view.scale, m.y / g.view.scale}
}

package game

import "core:fmt"
import rl "vendor:raylib"
import ui_assets "../ui"
import "../theme"

UI_ICON_TEXT_GAP: f32 : 4
NAV_BUTTON_MARGIN_DESIGN :: 16
NAV_BUTTON_PAD_X_DESIGN :: 8
NAV_BUTTON_PAD_Y_DESIGN :: 4
NAV_BUTTON_FONT_DESIGN :: 12

Game_UI :: struct {
	nav_hovered: bool,
}

nav_back_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.BACKSPACE)
}

nav_button_bounds :: proc(g: ^Game, label: cstring) -> rl.Rectangle {
	font := ui_font(g, NAV_BUTTON_FONT_DESIGN)
	pad_x := f32(ui_px(g, NAV_BUTTON_PAD_X_DESIGN))
	pad_y := f32(ui_px(g, NAV_BUTTON_PAD_Y_DESIGN))
	tw := f32(rl.MeasureText(label, font))
	th := f32(font)
	w := tw + pad_x * 2
	h := th + pad_y * 2
	x := f32(ui_px(g, NAV_BUTTON_MARGIN_DESIGN))
	y := f32(ui_px(g, NAV_BUTTON_MARGIN_DESIGN))
	return {x, y, w, h}
}

nav_button_clicked :: proc(g: ^Game, label: cstring, mouse: rl.Vector2, clicked: bool) -> bool {
	return clicked && rl.CheckCollisionPointRec(mouse, nav_button_bounds(g, label))
}

update_nav_button_hover :: proc(g: ^Game, label: cstring, mouse: rl.Vector2) {
	g.ui.nav_hovered = rl.CheckCollisionPointRec(mouse, nav_button_bounds(g, label))
}

draw_nav_button :: proc(g: ^Game, label: cstring) {
	bounds := nav_button_bounds(g, label)
	font := ui_font(g, NAV_BUTTON_FONT_DESIGN)
	line_w := f32(max(ui_px(g, 1), 1))
	fill := theme.BUBBLE_FILL
	text_col := rl.BLACK
	border := rl.BLACK
	if g.ui.nav_hovered {
		fill = rl.WHITE
		text_col = rl.BLACK
		border = rl.RED
	}
	rl.DrawRectangleRec(bounds, fill)
	rl.DrawRectangleLinesEx(bounds, line_w, border)
	tw := rl.MeasureText(label, font)
	tx := i32(bounds.x + (bounds.width - f32(tw)) * 0.5)
	ty := i32(bounds.y + (bounds.height - f32(font)) * 0.5)
	rl.DrawText(label, tx, ty, font, text_col)
}
GAMEPLAY_CONTROL_ROW_COUNT :: 5

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

draw_centered_gameplay_controls :: proc(
	g: ^Game,
	y: i32,
	font: i32,
	icon_size: f32,
	line_step: i32,
) -> i32 {
	row_y := y
	draw_centered_icon_text_row(g, row_y, font, .Sandals, "A / D  Walk", rl.LIGHTGRAY, icon_size)
	row_y += line_step
	draw_centered_icon_text_row(g, row_y, font, .Sandals, "Shift  Run", rl.LIGHTGRAY, icon_size)
	row_y += line_step
	draw_centered_icon_text_row(g, row_y, font, .Fish, "F  Give fish", rl.LIGHTGRAY, icon_size)
	row_y += line_step
	draw_centered_icon_text_row(g, row_y, font, .Bread, "B  Give bread", rl.LIGHTGRAY, icon_size)
	row_y += line_step
	draw_centered_icon_text_row(g, row_y, font, .People, "E  Recruit apostle", rl.LIGHTGRAY, icon_size)
	return row_y + line_step
}

draw_labeled_value_delta :: proc(
	x, y, font: i32,
	label: cstring,
	base: cstring,
	delta: cstring,
	delta_color: rl.Color,
) {
	prefix := fmt.ctprintf("%s: %s", label, base)
	rl.DrawText(prefix, x, y, font, rl.WHITE)
	if delta != "" {
		w := rl.MeasureText(prefix, font)
		rl.DrawText(delta, x + w, y, font, delta_color)
	}
}

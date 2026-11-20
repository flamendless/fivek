package game

import "core:math"
import rl "vendor:raylib"
import "../assets"
import ui_assets "../ui"
import "../theme"

CHECKBOX_ROW_GAP_DESIGN :: 6
CHECKBOX_HIT_PAD_DESIGN :: 4

ui_checkbox_size :: proc(g: ^Game) -> f32 {
	return f32(ui_px(g, 10))
}

ui_draw_checkbox :: proc(g: ^Game, dest: rl.Rectangle, checked: bool, tint: rl.Color = rl.WHITE) {
	tex: rl.Texture2D
	if checked {
		tex = assets.cozy_checkbox_on()
	} else {
		tex = assets.cozy_checkbox_off()
	}
	if tex.id != 0 {
		rl.DrawTexturePro(tex, {0, 0, f32(tex.width), f32(tex.height)}, dest, {}, 0, tint)
	}
}

ui_checkbox_row_bounds :: proc(
	g: ^Game,
	label: cstring,
	y: f32,
	font: i32,
) -> (row: rl.Rectangle, box: rl.Rectangle) {
	box_s := ui_checkbox_size(g)
	gap := f32(ui_px(g, CHECKBOX_ROW_GAP_DESIGN))
	label_w := f32(rl.MeasureText(label, font))
	row_w := box_s + gap + label_w
	row_h := max(box_s, f32(font))
	x := (g.view.game_size.x - row_w) * 0.5
	row = {x, y, row_w, row_h}
	box = {x, y + (row_h - box_s) * 0.5, box_s, box_s}
	return row, box
}

ui_checkbox_row_hit :: proc(mouse: rl.Vector2, row, box: rl.Rectangle) -> bool {
	pad := f32(4)
	expand_row := rl.Rectangle{row.x - pad, row.y - pad, row.width + pad * 2, row.height + pad * 2}
	return rl.CheckCollisionPointRec(mouse, expand_row) || rl.CheckCollisionPointRec(mouse, box)
}

draw_checkbox_row :: proc(g: ^Game, label: cstring, y: f32, font: i32, checked, hovered: bool) {
	_, box := ui_checkbox_row_bounds(g, label, y, font)
	box_s := ui_checkbox_size(g)
	gap := f32(ui_px(g, CHECKBOX_ROW_GAP_DESIGN))
	label_w := f32(rl.MeasureText(label, font))
	row_h := max(box_s, f32(font))
	x := (g.view.game_size.x - (box_s + gap + label_w)) * 0.5
	tint := rl.WHITE
	if hovered {
		tint = {240, 240, 255, 255}
	}
	ui_draw_checkbox(g, box, checked, tint)
	tx := i32(x + box_s + gap)
	ty := i32(y + (row_h - f32(font)) * 0.5)
	rl.DrawText(label, tx, ty, font, theme.TEXT_INK)
}

ui_slider_ratio_from_x :: proc(track: rl.Rectangle, mouse_x: f32) -> f32 {
	if track.width <= 0 {
		return 0
	}
	t := (mouse_x - track.x) / track.width
	return math.clamp(t, 0, 1)
}

ui_slider_track_bounds :: proc(g: ^Game, label: cstring, y: f32, font: i32, track_w: f32) -> (label_y: f32, track: rl.Rectangle) {
	gap := f32(ui_px(g, 4))
	label_y = y
	track_y := y + f32(font) + gap
	cx := g.view.game_size.x * 0.5
	track = {cx - track_w * 0.5, track_y, track_w, f32(ui_px(g, 12))}
	return label_y, track
}

draw_range_slider :: proc(track: rl.Rectangle, ratio: f32, fill_tint: rl.Color) {
	ui_assets.draw_stamina_bar(track, ratio, fill_tint)
	knob_r := max(track.height * 0.55, 3)
	kx := track.x + track.width * math.clamp(ratio, 0, 1)
	ky := track.y + track.height * 0.5
	rl.DrawCircleV({kx, ky}, knob_r, rl.WHITE)
	rl.DrawCircleLinesV({kx, ky}, knob_r, theme.TEXT_INK)
}

draw_labeled_slider :: proc(
	g: ^Game,
	label: cstring,
	value_text: cstring,
	y: f32,
	font: i32,
	track_w: f32,
	ratio: f32,
	hovered: bool,
) {
	label_y, track := ui_slider_track_bounds(g, label, y, font, track_w)
	col := theme.TEXT_INK
	if hovered {
		col = {40, 40, 40, 255}
	}
	tw := rl.MeasureText(label, font)
	lx := i32((g.view.game_size.x - f32(tw)) * 0.5)
	rl.DrawText(label, lx, i32(label_y), font, col)
	vw := rl.MeasureText(value_text, font)
	rl.DrawText(value_text, lx + tw + ui_px(g, 6), i32(label_y), font, col)
	ui_assets.draw_stamina_bar(track, ratio, theme.REQ_MET)
}
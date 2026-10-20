package social

import rl "vendor:raylib"
import "../theme"

ATLAS_PATH :: "assets/social/atlas.png"
CELL_SIZE: f32 : 32
ATLAS_COLS :: 11
LINK_COUNT :: 4

Link :: struct {
	name:        cstring,
	atlas_index: int,
	url:         cstring,
}

LINKS: [LINK_COUNT]Link = {
	{"Facebook", 1, "https://www.facebook.com/flamendlessstudio"},
	{"X", 2, "https://x.com/flam8studio"},
	{"YouTube", 8, "https://www.youtube.com/@flamendless"},
	{"itch.io", 25, "https://flamendless.itch.io"},
}

ui_px :: proc(ui_scale: f32, design: f32) -> i32 {
	return i32(design * ui_scale)
}

row_metrics :: proc(ui_scale: f32) -> (size: f32, gap: f32) {
	size = f32(ui_px(ui_scale, 24))
	gap = f32(ui_px(ui_scale, 4))
	return size, gap
}

row_width :: proc(size: f32, gap: f32) -> f32 {
	return f32(LINK_COUNT) * size + f32(LINK_COUNT - 1) * gap
}

atlas_src :: proc(atlas_index: int) -> rl.Rectangle {
	i := atlas_index - 1
	col := i % ATLAS_COLS
	row := i / ATLAS_COLS
	return {
		f32(col) * CELL_SIZE,
		f32(row) * CELL_SIZE,
		CELL_SIZE,
		CELL_SIZE,
	}
}

layout :: proc(game_size: rl.Vector2, ui_scale: f32) -> (x: f32, y: f32, size: f32, gap: f32) {
	pad := f32(ui_px(ui_scale, 8))
	size, gap = row_metrics(ui_scale)
	x = pad
	y = game_size.y - pad - size
	return x, y, size, gap
}

layout_centered_at :: proc(
	game_size: rl.Vector2,
	ui_scale: f32,
	row_y: f32,
) -> (
	x: f32,
	y: f32,
	size: f32,
	gap: f32,
) {
	size, gap = row_metrics(ui_scale)
	x = (game_size.x - row_width(size, gap)) * 0.5
	y = row_y
	return x, y, size, gap
}

icon_rect_at :: proc(index: int, row_x: f32, row_y: f32, size: f32, gap: f32) -> rl.Rectangle {
	x := row_x + f32(index) * (size + gap)
	return {x, row_y, size, size}
}

icon_rect :: proc(index: int, game_size: rl.Vector2, ui_scale: f32) -> rl.Rectangle {
	x, y, size, gap := layout(game_size, ui_scale)
	return icon_rect_at(index, x, y, size, gap)
}

hit_index_at :: proc(
	mouse: rl.Vector2,
	row_x: f32,
	row_y: f32,
	size: f32,
	gap: f32,
) -> int {
	for i in 0 ..< LINK_COUNT {
		if rl.CheckCollisionPointRec(mouse, icon_rect_at(i, row_x, row_y, size, gap)) {
			return i
		}
	}
	return -1
}

hit_index :: proc(mouse: rl.Vector2, game_size: rl.Vector2, ui_scale: f32) -> int {
	x, y, size, gap := layout(game_size, ui_scale)
	return hit_index_at(mouse, x, y, size, gap)
}

update_at :: proc(
	mouse: rl.Vector2,
	clicked: bool,
	row_x: f32,
	row_y: f32,
	size: f32,
	gap: f32,
) -> (
	hovered: int,
	opened: bool,
) {
	hovered = hit_index_at(mouse, row_x, row_y, size, gap)
	if clicked && hovered >= 0 {
		open_link(LINKS[hovered].url)
		return hovered, true
	}
	return hovered, false
}

update :: proc(
	mouse: rl.Vector2,
	clicked: bool,
	game_size: rl.Vector2,
	ui_scale: f32,
) -> (
	hovered: int,
	opened: bool,
) {
	x, y, size, gap := layout(game_size, ui_scale)
	return update_at(mouse, clicked, x, y, size, gap)
}

draw_tooltip_above :: proc(text: cstring, anchor: rl.Rectangle, ui_scale: f32) {
	font := ui_px(ui_scale, 10)
	spacing := f32(ui_px(ui_scale, 1))
	size := f32(font)
	w := rl.MeasureTextEx(rl.GetFontDefault(), text, size, spacing).x
	pad_x := f32(ui_px(ui_scale, 3))
	pad_y := f32(ui_px(ui_scale, 2))
	tw := w + pad_x * 2
	th := size + pad_y * 2
	cx := anchor.x + anchor.width * 0.5
	tx := cx - tw * 0.5
	ty := anchor.y - th - f32(ui_px(ui_scale, 2))
	rl.DrawRectangle(i32(tx), i32(ty), i32(tw), i32(th), theme.OVERLAY_SCRIM_180)
	rl.DrawTextEx(rl.GetFontDefault(), text, {tx + pad_x, ty + pad_y}, size, spacing, rl.WHITE)
}

draw_row_at :: proc(
	atlas: rl.Texture2D,
	hovered: int,
	show_tooltips: bool,
	row_x: f32,
	row_y: f32,
	size: f32,
	gap: f32,
	ui_scale: f32,
) {
	if atlas.id == 0 {
		return
	}
	for i in 0 ..< LINK_COUNT {
		link := LINKS[i]
		dest := icon_rect_at(i, row_x, row_y, size, gap)
		src := atlas_src(link.atlas_index)
		tint := rl.WHITE
		if hovered == i {
			tint = theme.SOCIAL_ICON_HOVER
		}
		rl.DrawTexturePro(atlas, src, dest, {}, 0, tint)
		if hovered == i {
			outline_pad := f32(ui_px(ui_scale, 1))
			outline := rl.Rectangle {
				dest.x - outline_pad,
				dest.y - outline_pad,
				dest.width + outline_pad * 2,
				dest.height + outline_pad * 2,
			}
			line_w := f32(max(ui_px(ui_scale, 1), 1))
			rl.DrawRectangleLinesEx(outline, line_w, rl.RED)
			if show_tooltips {
				draw_tooltip_above(link.name, dest, ui_scale)
			}
		}
	}
}

draw_row :: proc(
	atlas: rl.Texture2D,
	hovered: int,
	show_tooltips: bool,
	game_size: rl.Vector2,
	ui_scale: f32,
) {
	x, y, size, gap := layout(game_size, ui_scale)
	draw_row_at(atlas, hovered, show_tooltips, x, y, size, gap, ui_scale)
}

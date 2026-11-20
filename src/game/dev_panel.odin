package game

import "core:fmt"
import "core:math"
import "core:strconv"
import rl "vendor:raylib"
import "../assets"
import "../input"
import ui_assets "../ui"
import "../theme"

DEV_PANEL_FONT_DESIGN :: 12
DEV_PANEL_TITLE_DESIGN :: 14
DEV_PANEL_ROW_GAP_DESIGN :: 10
DEV_PANEL_SECTION_GAP_DESIGN :: 8
DEV_PANEL_TRACK_W_DESIGN :: 180
DEV_PANEL_POP_FIELD_W_DESIGN :: 56

Dev_Panel_Layout :: struct {
	panel:          rl.Rectangle,
	content:        rl.Rectangle,
	fullscreen_row: rl.Rectangle,
	fullscreen_box: rl.Rectangle,
	speed_label_y:  f32,
	speed_track:    rl.Rectangle,
	pop_label_y:    f32,
	pop_field:      rl.Rectangle,
}

dev_panel_layout :: proc(g: ^Game) -> Dev_Panel_Layout {
	font := ui_font(g, DEV_PANEL_FONT_DESIGN)
	title_font := ui_font(g, DEV_PANEL_TITLE_DESIGN)
	row_gap := f32(ui_px(g, DEV_PANEL_ROW_GAP_DESIGN))
	section_gap := f32(ui_px(g, DEV_PANEL_SECTION_GAP_DESIGN))
	track_w := f32(ui_px(g, DEV_PANEL_TRACK_W_DESIGN))
	track_h := f32(ui_px(g, 12))
	box_s := ui_checkbox_size(g)
	cb_gap := f32(ui_px(g, CHECKBOX_ROW_GAP_DESIGN))
	fs_label: cstring = "Fullscreen"
	fs_label_w := f32(rl.MeasureText(fs_label, font))
	fs_row_w := box_s + cb_gap + fs_label_w
	fs_row_h := max(box_s, f32(font))

	pop_label: cstring = "People to serve"
	pop_label_w := f32(rl.MeasureText(pop_label, font))
	pop_field_w := f32(ui_px(g, DEV_PANEL_POP_FIELD_W_DESIGN))
	pop_gap := f32(ui_px(g, 8))
	pop_row_w := pop_label_w + pop_gap + pop_field_w
	pop_field_h := f32(font) + f32(ui_px(g, 8))

	speed_label_h := f32(font)
	inner_w := max(track_w, fs_row_w, pop_row_w, f32(rl.MeasureText("Dev", title_font)))
	inner_h :=
		f32(title_font) +
		section_gap +
		fs_row_h +
		row_gap +
		speed_label_h +
		f32(ui_px(g, 4)) +
		track_h +
		row_gap +
		pop_field_h

	panel_w := ui_assets.wood_panel_width_for_inner(inner_w, 0)
	panel_h := ui_assets.wood_panel_height_for_inner(inner_h, 0)
	panel_x := (g.view.game_size.x - panel_w) * 0.5
	panel_y := (g.view.game_size.y - panel_h) * 0.5
	panel := rl.Rectangle{panel_x, panel_y, panel_w, panel_h}
	content := ui_assets.wood_panel_content(panel, 0)

	y := content.y
	fs_x := content.x + (content.width - fs_row_w) * 0.5
	fs_row := rl.Rectangle{fs_x, y + f32(title_font) + section_gap, fs_row_w, fs_row_h}
	fs_box := rl.Rectangle{
		fs_x,
		fs_row.y + (fs_row_h - box_s) * 0.5,
		box_s,
		box_s,
	}
	y = fs_row.y + fs_row_h + row_gap
	speed_label_y := y
	track_y := y + speed_label_h + f32(ui_px(g, 4))
	track := rl.Rectangle{content.x + (content.width - track_w) * 0.5, track_y, track_w, track_h}
	y = track_y + track_h + row_gap
	pop_row_w_total := pop_row_w
	pop_x := content.x + (content.width - pop_row_w_total) * 0.5
	pop_label_y := y
	pop_field := rl.Rectangle{pop_x + pop_label_w + pop_gap, y, pop_field_w, pop_field_h}

	return Dev_Panel_Layout{
		panel = panel,
		content = content,
		fullscreen_row = fs_row,
		fullscreen_box = fs_box,
		speed_label_y = speed_label_y,
		speed_track = track,
		pop_label_y = pop_label_y,
		pop_field = pop_field,
	}
}

toggle_dev_panel :: proc(g: ^Game) {
	if input.key_pressed(.GRAVE) {
		g.display.dev_open = !g.display.dev_open
		if g.display.dev_open {
			g.display.dev_speed = math.clamp(g.display.dev_speed, DEV_SPEED_MIN, DEV_SPEED_MAX)
			dev_pop_sync_text(&g.display)
			dev_apply_population_target(g)
		} else {
			g.display.dev_pop_focus = false
			g.display.dev_speed_drag = false
		}
	}
}

// ponytail: log slider — linear maps 1x to a sliver at the left on a 1–50 range.
dev_speed_from_ratio :: proc(r: f32) -> f32 {
	t := math.clamp(r, 0, 1)
	return math.max(DEV_SPEED_MIN, math.pow(DEV_SPEED_MAX, t))
}

dev_speed_ratio :: proc(speed: f32) -> f32 {
	s := math.clamp(speed, DEV_SPEED_MIN, DEV_SPEED_MAX)
	if s <= DEV_SPEED_MIN {
		return 0
	}
	return math.log_f32(s, DEV_SPEED_MAX)
}

@(private = "file")
dev_pop_apply_from_text :: proc(g: ^Game) {
	if g.display.dev_pop_text_len <= 0 {
		return
	}
	if v, ok := strconv.parse_int(string(g.display.dev_pop_text[:g.display.dev_pop_text_len])); ok {
		g.display.dev_pop_target = dev_clamp_population(v)
		dev_apply_population_target(g)
	}
}

@(private = "file")
dev_pop_clear_entry :: proc(g: ^Game) {
	g.display.dev_pop_text_len = 0
	g.display.dev_pop_text[0] = 0
}

@(private = "file")
dev_pop_push_digit :: proc(g: ^Game, d: u8) {
	if g.display.dev_pop_text_len >= DEV_PANEL_POP_BUF - 1 {
		return
	}
	g.display.dev_pop_text[g.display.dev_pop_text_len] = d
	g.display.dev_pop_text_len += 1
	g.display.dev_pop_text[g.display.dev_pop_text_len] = 0
	dev_pop_apply_from_text(g)
}

@(private = "file")
dev_pop_pop_digit :: proc(g: ^Game) {
	if g.display.dev_pop_text_len <= 0 {
		return
	}
	g.display.dev_pop_text_len -= 1
	g.display.dev_pop_text[g.display.dev_pop_text_len] = 0
	dev_pop_apply_from_text(g)
}

@(private = "file")
dev_pop_handle_digit_keys :: proc(g: ^Game) {
	digit_keys := [10]rl.KeyboardKey{
		.ZERO,
		.ONE,
		.TWO,
		.THREE,
		.FOUR,
		.FIVE,
		.SIX,
		.SEVEN,
		.EIGHT,
		.NINE,
	}
	for d in 0 ..= 9 {
		if input.key_pressed(digit_keys[d]) {
			dev_pop_push_digit(g, u8('0' + d))
		}
	}
	if input.key_pressed(.BACKSPACE) {
		dev_pop_pop_digit(g)
	}
	if input.key_pressed(.ENTER) {
		g.display.dev_pop_focus = false
		if g.display.dev_pop_text_len <= 0 {
			dev_pop_sync_text(&g.display)
		}
	}
}

update_dev_panel :: proc(g: ^Game) {
	if !g.display.dev_open {
		return
	}
	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	down := rl.IsMouseButtonDown(.LEFT)
	layout := dev_panel_layout(g)

	g.display.dev_hovered_fullscreen =
		rl.CheckCollisionPointRec(mouse, layout.fullscreen_row) ||
		rl.CheckCollisionPointRec(mouse, layout.fullscreen_box)
	if clicked && g.display.dev_hovered_fullscreen {
		display_set_fullscreen(g, !g.display.fullscreen)
	}

	g.display.dev_hovered_speed = rl.CheckCollisionPointRec(mouse, layout.speed_track)
	if clicked && g.display.dev_hovered_speed {
		g.display.dev_speed_drag = true
		r := ui_slider_ratio_from_x(layout.speed_track, mouse.x)
		g.display.dev_speed = dev_speed_from_ratio(r)
	}
	if g.display.dev_speed_drag {
		if down {
			r := ui_slider_ratio_from_x(layout.speed_track, mouse.x)
			g.display.dev_speed = dev_speed_from_ratio(r)
		} else {
			g.display.dev_speed_drag = false
		}
	}

	g.display.dev_hovered_pop = rl.CheckCollisionPointRec(mouse, layout.pop_field)
	if clicked && g.display.dev_hovered_pop {
		g.display.dev_pop_focus = true
		dev_pop_clear_entry(g)
	} else if clicked {
		g.display.dev_pop_focus = false
	}

	if g.display.dev_pop_focus {
		dev_pop_handle_digit_keys(g)
	}
}

draw_dev_panel :: proc(g: ^Game) {
	if !g.display.dev_open {
		return
	}
	rl.DrawRectangle(0, 0, i32(g.view.game_size.x), i32(g.view.game_size.y), theme.OVERLAY_SCRIM_180)

	layout := dev_panel_layout(g)
	font := ui_font(g, DEV_PANEL_FONT_DESIGN)
	title_font := ui_font(g, DEV_PANEL_TITLE_DESIGN)

	ui_assets.draw_wood_panel(layout.panel)

	title: cstring = "Dev"
	tw := rl.MeasureText(title, title_font)
	tx := i32(layout.content.x + (layout.content.width - f32(tw)) * 0.5)
	rl.DrawText(title, tx, i32(layout.content.y), title_font, theme.TEXT_INK)

	box_s := ui_checkbox_size(g)
	cb_gap := f32(ui_px(g, CHECKBOX_ROW_GAP_DESIGN))
	fs_label: cstring = "Fullscreen"
	fs_label_w := f32(rl.MeasureText(fs_label, font))
	tint := rl.WHITE
	if g.display.dev_hovered_fullscreen {
		tint = {240, 240, 255, 255}
	}
	ui_draw_checkbox(g, layout.fullscreen_box, g.display.fullscreen, tint)
	fl_ty := i32(
		layout.fullscreen_row.y +
		(layout.fullscreen_row.height - f32(font)) * 0.5,
	)
	rl.DrawText(
		fs_label,
		i32(layout.fullscreen_box.x + box_s + cb_gap),
		fl_ty,
		font,
		theme.TEXT_INK,
	)
	_ = fs_label_w

	speed_label := fmt.ctprintf("Run speed  %.0fx", g.display.dev_speed)
	slw := rl.MeasureText(speed_label, font)
	slx := i32(layout.content.x + (layout.content.width - f32(slw)) * 0.5)
	rl.DrawText(speed_label, slx, i32(layout.speed_label_y), font, theme.TEXT_INK)
	ratio := dev_speed_ratio(g.display.dev_speed)
	bar_col := theme.REQ_MET
	if g.display.dev_hovered_speed {
		bar_col = theme.PARTY_BONUS_GREEN
	}
	draw_range_slider(layout.speed_track, ratio, bar_col)

	pop_label: cstring = "People to serve"
	pop_lw := rl.MeasureText(pop_label, font)
	pop_gap := f32(ui_px(g, 8))
	pop_lx := i32(layout.pop_field.x - pop_gap - f32(pop_lw))
	pop_ty := i32(layout.pop_label_y + (layout.pop_field.height - f32(font)) * 0.5)
	rl.DrawText(pop_label, pop_lx, pop_ty, font, theme.TEXT_INK)

	btn: assets.Cozy_Button = .Normal
	if g.display.dev_hovered_pop {
		btn = rl.IsMouseButtonDown(.LEFT) ? .Pressed : .Hover
	}
	if g.display.dev_pop_focus {
		btn = .Pressed
	}
	ui_assets.draw_wood_button(btn, layout.pop_field)
	pop_content := ui_assets.wood_panel_content(layout.pop_field, 0)
	g.display.dev_pop_text[g.display.dev_pop_text_len] = 0
	val := cstring(&g.display.dev_pop_text[0])
	vw := rl.MeasureText(val, font)
	vx := i32(pop_content.x + (pop_content.width - f32(vw)) * 0.5)
	vy := i32(pop_content.y + (pop_content.height - f32(font)) * 0.5)
	rl.DrawText(val, vx, vy, font, theme.TEXT_INK)

	hint: cstring = "~ to close"
	hw := rl.MeasureText(hint, font)
	hx := i32(layout.panel.x + (layout.panel.width - f32(hw)) * 0.5)
	hy := i32(layout.panel.y + layout.panel.height + f32(ui_px(g, 6)))
	rl.DrawText(hint, hx, hy, font, rl.LIGHTGRAY)
}
package game

import "core:fmt"
import rl "vendor:raylib"
import ui_assets "../ui"
import "../person"
import "../theme"

STATS_HEADER_DESIGN :: 22
STATS_SECTION_FONT_DESIGN :: 11
STATS_ROW_FONT_DESIGN :: 11
STATS_ROW_ICON_DESIGN :: 16
STATS_APOSTLE_FONT_DESIGN :: 9
STATS_CONTENT_COLS :: 3
STATS_APOSTLE_COLS :: 2
STATS_COLUMN_INNER_DESIGN :: 88

stats_kind_label :: proc(kind: person.Stat_Kind) -> cstring {
	if kind == .Distance_Walked {
		return "Distance"
	}
	return person.stat_kind_short(kind)
}

enter_stats :: proc(g: ^Game) {
	load_title_assets(g)
	g.title.settings_open = false
	g.title.hovered_social = -1
	g.mode = .Stats
}

stats_exit_to_title :: proc(g: ^Game) {
	g.mode = .Title
}

stats_row_step :: proc(g: ^Game) -> i32 {
	font := ui_font(g, STATS_ROW_FONT_DESIGN)
	icon := ui_px(g, STATS_ROW_ICON_DESIGN)
	return max(font, icon) + ui_px(g, 1)
}

stats_section_step :: proc(g: ^Game) -> i32 {
	return ui_font(g, STATS_SECTION_FONT_DESIGN) + ui_px(g, 2)
}

@(private = "file")
stats_column_row_pad :: proc(g: ^Game) -> i32 {
	return ui_px(g, 1)
}

@(private = "file")
stats_column_inner_height :: proc(g: ^Game, data_rows: i32) -> f32 {
	return f32(stats_section_step(g) + stats_row_step(g) * data_rows)
}

@(private = "file")
stats_apostle_row_step :: proc(g: ^Game) -> i32 {
	return ui_font(g, STATS_APOSTLE_FONT_DESIGN) + ui_px(g, 2)
}

@(private = "file")
stats_apostle_inner_height :: proc(g: ^Game, data_rows: i32) -> f32 {
	return f32(stats_section_step(g) + stats_apostle_row_step(g) * data_rows)
}

stats_value_column_x :: proc(col_x: i32, col_w: i32, pad: i32, value: cstring, font: i32) -> i32 {
	vw := rl.MeasureText(value, font)
	return col_x + col_w - pad - vw
}

stats_draw_section_title :: proc(g: ^Game, col_x, y, col_w: i32, title: cstring) {
	font := ui_font(g, STATS_SECTION_FONT_DESIGN)
	tw := rl.MeasureText(title, font)
	tx := col_x + (col_w - tw) / 2
	rl.DrawText(title, tx, y, font, theme.TEXT_INK)
}

stats_draw_stat_kind_row :: proc(g: ^Game, col_x, y, col_w: i32, font: i32, kind: person.Stat_Kind, value: u32) {
	pad := stats_column_row_pad(g)
	layout_w := f32(person.stat_symbol_width(kind, font))
	row_h := f32(font)
	left := f32(col_x + pad)
	person.draw_stat_symbol(kind, left, f32(y), row_h, font, theme.TEXT_INK)
	text_x := col_x + pad + i32(layout_w) + i32(UI_ICON_TEXT_GAP)
	rl.DrawText(stats_kind_label(kind), text_x, y, font, theme.TEXT_INK)
	val := fmt.ctprintf("%d", value)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, theme.TEXT_INK)
}

stats_draw_icon_row :: proc(
	g: ^Game,
	col_x, y, col_w: i32,
	font: i32,
	icon_size: f32,
	icon: UI_Row_Icon,
	label: cstring,
	value: u32,
) {
	pad := stats_column_row_pad(g)
	layout_w := row_icon_layout_width(icon, icon_size)
	val := fmt.ctprintf("%d", value)
	icon_cx := f32(col_x+pad) + layout_w*0.5
	cy := f32(y) + f32(font)*0.5
	draw_row_icon(icon, {icon_cx, cy}, icon_size)
	text_x := col_x + pad + i32(layout_w) + i32(UI_ICON_TEXT_GAP)
	short := fmt.ctprintf("%s", label)
	rl.DrawText(short, text_x, y, font, theme.TEXT_INK)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, theme.TEXT_INK)
}

stats_draw_time_row :: proc(
	g: ^Game,
	col_x, y, col_w: i32,
	font: i32,
	icon_size: f32,
	seconds: u32,
) {
	pad := stats_column_row_pad(g)
	val := fmt.ctprintf("%d:%02d", seconds / 60, seconds % 60)
	layout_w := row_icon_layout_width(.Hourglass, icon_size)
	icon_cx := f32(col_x+pad) + layout_w*0.5
	cy := f32(y) + f32(font)*0.5
	draw_row_icon(.Hourglass, {icon_cx, cy}, icon_size)
	rl.DrawText("Time", col_x+pad+i32(layout_w)+i32(UI_ICON_TEXT_GAP), y, font, theme.TEXT_INK)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, theme.TEXT_INK)
}

stats_draw_serving_column :: proc(g: ^Game, c: ^person.Career_Stats, col_x, col_w, y0: i32) {
	font := ui_font(g, STATS_ROW_FONT_DESIGN)
	icon := f32(ui_px(g, STATS_ROW_ICON_DESIGN))
	step := stats_row_step(g)
	y := y0
	stats_draw_section_title(g, col_x, y, col_w, "Serving")
	y += stats_section_step(g)
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Total_Served, c.lifetime.total_served)
	y += step
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Fish_Given, c.lifetime.fish_given)
	y += step
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Bread_Given, c.lifetime.bread_given)
	y += step
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Fed_Kids, c.lifetime.fed_kids)
	y += step
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Fed_Young, c.lifetime.fed_young)
	y += step
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Fed_Adults, c.lifetime.fed_adults)
}

stats_draw_journey_column :: proc(g: ^Game, c: ^person.Career_Stats, col_x, col_w, y0: i32) {
	font := ui_font(g, STATS_ROW_FONT_DESIGN)
	icon := f32(ui_px(g, STATS_ROW_ICON_DESIGN))
	step := stats_row_step(g)
	y := y0
	stats_draw_section_title(g, col_x, y, col_w, "Journey")
	y += stats_section_step(g)
	stats_draw_stat_kind_row(g, col_x, y, col_w, font, .Distance_Walked, c.lifetime.distance_walked)
	y += step
	stats_draw_icon_row(g, col_x, y, col_w, font, icon, .Coin, "Coins", c.total_coins)
	y += step
	stats_draw_time_row(g, col_x, y, col_w, font, icon, c.total_play_time_s)
}

stats_draw_runs_column :: proc(g: ^Game, c: ^person.Career_Stats, col_x, col_w, y0: i32) {
	font := ui_font(g, STATS_ROW_FONT_DESIGN)
	icon := f32(ui_px(g, STATS_ROW_ICON_DESIGN))
	step := stats_row_step(g)
	y := y0
	stats_draw_section_title(g, col_x, y, col_w, "Runs")
	y += stats_section_step(g)
	stats_draw_icon_row(g, col_x, y, col_w, font, icon, .People, "Started", c.runs_started)
	y += step
	stats_draw_icon_row(g, col_x, y, col_w, font, icon, .General_Play, "Won", c.runs_won)
	y += step
	stats_draw_icon_row(g, col_x, y, col_w, font, icon, .People, "Lineup", c.post_celebrate_lineup)
	y += step
	stats_draw_icon_row(g, col_x, y, col_w, font, icon, .Sandals, "Homeward", c.post_celebrate_home)
}

stats_draw_apostle_grid :: proc(g: ^Game, c: ^person.Career_Stats, content: rl.Rectangle) {
	font := ui_font(g, STATS_APOSTLE_FONT_DESIGN)
	step := stats_apostle_row_step(g)
	gap := f32(ui_px(g, 6))
	pad := stats_column_row_pad(g)
	cell_w := (content.width - gap) / f32(STATS_APOSTLE_COLS)
	ox := content.x

	title: cstring = "Apostles recruited"
	tw := rl.MeasureText(title, font)
	title_x := i32(content.x + (content.width - f32(tw)) * 0.5)
	rl.DrawText(title, title_x, i32(content.y), font, theme.TEXT_INK)

	y := i32(content.y) + stats_section_step(g)
	for a in 0 ..< person.APOSTLE_COUNT {
		col := a % STATS_APOSTLE_COLS
		row := a / STATS_APOSTLE_COLS
		col_x := i32(ox + f32(col) * (cell_w + gap))
		row_y := y + i32(row) * step
		def := person.APOSTLE_DEFS[a]
		val := fmt.ctprintf("%d", c.apostle_recruits[a])
		rl.DrawText(def.name, col_x+pad, row_y, font, theme.TEXT_INK)
		vx := col_x + i32(cell_w) - pad - rl.MeasureText(val, font)
		rl.DrawText(val, vx, row_y, font, theme.TEXT_INK)
	}
}

update_stats :: proc(g: ^Game) {
	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	update_nav_button_hover(g, "Back", mouse)
	if nav_back_pressed() || nav_button_clicked(g, "Back", mouse, clicked) {
		stats_exit_to_title(g)
		return
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.ESCAPE) {
		stats_exit_to_title(g)
		return
	}
}

draw_stats :: proc(g: ^Game) {
	c := &g.career
	rl.BeginMode2D(g.cameras.ui_camera)
	draw_title_pattern_bg(g)

	header_y := f32(ui_px(g, 20))
	title_draw_centered_default_outlined(g, "Career stats", header_y, STATS_HEADER_DESIGN, rl.WHITE, rl.BLACK)

	margin := ui_px(g, 8)
	col_gap := ui_px(g, 8)
	header_h := title_measure_default(g, "Career stats", STATS_HEADER_DESIGN).y
	grid_top := header_y + header_h + f32(ui_px(g, 8))

	total_inner := i32(g.view.game_size.x) - margin*2
	col_w := (total_inner - col_gap*(STATS_CONTENT_COLS-1)) / STATS_CONTENT_COLS
	col_inner_w := f32(ui_px(g, STATS_COLUMN_INNER_DESIGN))
	col_panel_w := ui_assets.wood_panel_width_for_inner(col_inner_w, 0)
	column_rows: [3]i32 = {6, 3, 4}
	max_block_h: f32 = 0
	for rows in column_rows {
		inner_h := stats_column_inner_height(g, rows)
		h := ui_assets.wood_panel_height_for_inner(inner_h, 0)
		max_block_h = max(max_block_h, h)
	}
	for i in 0 ..< STATS_CONTENT_COLS {
		slot_x := margin + i32(i) * (col_w + col_gap)
		px := f32(slot_x) + (f32(col_w) - col_panel_w) * 0.5
		panel := rl.Rectangle{px, grid_top, col_panel_w, max_block_h}
		ui_assets.draw_wood_panel(panel)
		content := ui_assets.wood_panel_content(panel, 0)
		col_x := i32(content.x)
		col_inner_w := i32(content.width)
		y0 := i32(content.y)
		switch i {
		case 0:
			stats_draw_serving_column(g, c, col_x, col_inner_w, y0)
		case 1:
			stats_draw_journey_column(g, c, col_x, col_inner_w, y0)
		case 2:
			stats_draw_runs_column(g, c, col_x, col_inner_w, y0)
		}
	}

	apostle_top := grid_top + max_block_h + f32(ui_px(g, 8))
	apostle_rows := (person.APOSTLE_COUNT + STATS_APOSTLE_COLS - 1) / STATS_APOSTLE_COLS
	ap_inner_h := stats_apostle_inner_height(g, i32(apostle_rows))
	apostle_block_h := ui_assets.wood_panel_height_for_inner(ap_inner_h, 0)
	ap_font := ui_font(g, STATS_APOSTLE_FONT_DESIGN)
	ap_gap := f32(ui_px(g, 6))
	ap_pad := f32(stats_column_row_pad(g))
	ap_cell_inner := f32(0)
	for def in person.APOSTLE_DEFS {
		val_w := f32(rl.MeasureText("999", ap_font))
		w := f32(rl.MeasureText(def.name, ap_font)) + ap_pad*2 + val_w + ap_pad
		ap_cell_inner = max(ap_cell_inner, w)
	}
	ap_inner_grid_w := ap_cell_inner*f32(STATS_APOSTLE_COLS) + ap_gap
	ap_panel_w := ui_assets.wood_panel_width_for_inner(ap_inner_grid_w, 0)
	ap_px := f32(margin) + (f32(total_inner) - ap_panel_w) * 0.5
	if apostle_block_h > f32(ui_px(g, 16)) {
		ap_panel := rl.Rectangle{ap_px, apostle_top, ap_panel_w, apostle_block_h}
		ui_assets.draw_wood_panel(ap_panel)
		ap_content := ui_assets.wood_panel_content(ap_panel, 0)
		stats_draw_apostle_grid(g, c, ap_content)
	}

	draw_nav_button(g, "Back")
	rl.EndMode2D()
}

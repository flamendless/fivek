package game

import "core:fmt"
import rl "vendor:raylib"
import "../person"
import "../theme"
import ui_assets "../ui"

STATS_HEADER_DESIGN :: 22
STATS_SECTION_FONT_DESIGN :: 11
STATS_ROW_FONT_DESIGN :: 11
STATS_ROW_ICON_DESIGN :: 16
STATS_APOSTLE_FONT_DESIGN :: 9
STATS_CONTENT_COLS :: 3
STATS_APOSTLE_COLS :: 2

STATS_AGE_ICON_KID :: 0.62
STATS_AGE_ICON_YOUNG :: 0.82
STATS_AGE_ICON_ADULT :: 1.0

stats_kind_label :: proc(kind: person.Stat_Kind) -> cstring {
	if kind == .Distance_Walked {
		return "Distance"
	}
	return person.stat_kind_short(kind)
}

enter_stats :: proc(g: ^Game) {
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
	return max(font, icon) + ui_px(g, 4)
}

stats_section_step :: proc(g: ^Game) -> i32 {
	return ui_font(g, STATS_SECTION_FONT_DESIGN) + ui_px(g, 6)
}

stats_value_column_x :: proc(col_x: i32, col_w: i32, pad: i32, value: cstring, font: i32) -> i32 {
	vw := rl.MeasureText(value, font)
	return col_x + col_w - pad - vw
}

stats_draw_section_title :: proc(g: ^Game, col_x, y, col_w: i32, title: cstring) {
	font := ui_font(g, STATS_SECTION_FONT_DESIGN)
	tw := rl.MeasureText(title, font)
	tx := col_x + (col_w - tw) / 2
	rl.DrawText(title, tx, y, font, rl.WHITE)
}

stats_draw_stat_kind_row :: proc(g: ^Game, col_x, y, col_w: i32, font: i32, kind: person.Stat_Kind, value: u32) {
	pad := ui_px(g, 4)
	layout_w := f32(person.stat_symbol_width(kind, font))
	row_h := f32(font)
	left := f32(col_x + pad)
	person.draw_stat_symbol(kind, left, f32(y), row_h, font, rl.WHITE)
	text_x := col_x + pad + i32(layout_w) + i32(UI_ICON_TEXT_GAP)
	rl.DrawText(stats_kind_label(kind), text_x, y, font, rl.LIGHTGRAY)
	val := fmt.ctprintf("%d", value)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, rl.WHITE)
}

stats_draw_fed_age_row :: proc(
	g: ^Game,
	col_x, y, col_w: i32,
	font: i32,
	icon_slot: f32,
	head_scale: f32,
	label: cstring,
	value: u32,
) {
	pad := ui_px(g, 4)
	draw_size := icon_slot * head_scale
	icon_cx := f32(col_x+pad) + icon_slot*0.5
	cy := f32(y) + f32(font)*0.5
	ui_assets.draw_texture_icon(ui_assets.texture(.People), {icon_cx, cy}, draw_size)
	text_x := col_x + pad + i32(icon_slot) + i32(UI_ICON_TEXT_GAP)
	rl.DrawText(label, text_x, y, font, rl.LIGHTGRAY)
	val := fmt.ctprintf("%d", value)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, rl.WHITE)
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
	pad := ui_px(g, 4)
	layout_w := row_icon_layout_width(icon, icon_size)
	val := fmt.ctprintf("%d", value)
	icon_cx := f32(col_x+pad) + layout_w*0.5
	cy := f32(y) + f32(font)*0.5
	draw_row_icon(icon, {icon_cx, cy}, icon_size)
	text_x := col_x + pad + i32(layout_w) + i32(UI_ICON_TEXT_GAP)
	short := fmt.ctprintf("%s", label)
	rl.DrawText(short, text_x, y, font, rl.LIGHTGRAY)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, rl.WHITE)
}

stats_draw_time_row :: proc(
	g: ^Game,
	col_x, y, col_w: i32,
	font: i32,
	icon_size: f32,
	seconds: u32,
) {
	pad := ui_px(g, 4)
	val := fmt.ctprintf("%d:%02d", seconds / 60, seconds % 60)
	layout_w := row_icon_layout_width(.Hourglass, icon_size)
	icon_cx := f32(col_x+pad) + layout_w*0.5
	cy := f32(y) + f32(font)*0.5
	draw_row_icon(.Hourglass, {icon_cx, cy}, icon_size)
	rl.DrawText("Time", col_x+pad+i32(layout_w)+i32(UI_ICON_TEXT_GAP), y, font, rl.LIGHTGRAY)
	vx := stats_value_column_x(col_x, col_w, pad, val, font)
	rl.DrawText(val, vx, y, font, rl.WHITE)
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
	stats_draw_fed_age_row(g, col_x, y, col_w, font, icon, STATS_AGE_ICON_KID, "Kids", c.lifetime.fed_kids)
	y += step
	stats_draw_fed_age_row(g, col_x, y, col_w, font, icon, STATS_AGE_ICON_YOUNG, "Young", c.lifetime.fed_young)
	y += step
	stats_draw_fed_age_row(g, col_x, y, col_w, font, icon, STATS_AGE_ICON_ADULT, "Adults", c.lifetime.fed_adults)
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

stats_apostle_cell_w :: proc(g: ^Game) -> f32 {
	return g.view.game_size.x * 0.36
}

stats_draw_apostle_grid :: proc(g: ^Game, c: ^person.Career_Stats, top_y: f32) {
	font := ui_font(g, STATS_APOSTLE_FONT_DESIGN)
	step := stats_row_step(g)
	gap := f32(ui_px(g, 8))
	cell_w := stats_apostle_cell_w(g)
	grid_w := f32(STATS_APOSTLE_COLS)*cell_w + gap
	ox := (g.view.game_size.x - grid_w) * 0.5

	title: cstring = "Apostles recruited"
	tw := rl.MeasureText(title, font)
	rl.DrawText(title, i32((g.view.game_size.x-f32(tw))*0.5), i32(top_y), font, rl.WHITE)

	y := i32(top_y) + stats_section_step(g)
	pad := ui_px(g, 4)
	for a in 0 ..< person.APOSTLE_COUNT {
		col := a % STATS_APOSTLE_COLS
		row := a / STATS_APOSTLE_COLS
		col_x := i32(ox + f32(col) * (cell_w + gap))
		row_y := y + i32(row)*step
		def := person.APOSTLE_DEFS[a]
		val := fmt.ctprintf("%d", c.apostle_recruits[a])
		rl.DrawText(def.name, col_x+pad, row_y, font, rl.LIGHTGRAY)
		vx := col_x + i32(cell_w) - pad - rl.MeasureText(val, font)
		rl.DrawText(val, vx, row_y, font, rl.WHITE)
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

	margin := ui_px(g, 10)
	col_gap := ui_px(g, 6)
	header_h := title_measure_default(g, "Career stats", STATS_HEADER_DESIGN).y
	grid_top := header_y + header_h + f32(ui_px(g, 10))
	panel_bottom := g.view.game_size.y - f32(ui_px(g, 6))

	total_inner := i32(g.view.game_size.x) - margin*2
	col_w := (total_inner - col_gap*(STATS_CONTENT_COLS-1)) / STATS_CONTENT_COLS
	col0 := margin
	col1 := col0 + col_w + col_gap
	col2 := col1 + col_w + col_gap

	// grouped column panels (credits-style bands)
	block_h := f32(stats_section_step(g) + stats_row_step(g)*6 + ui_px(g, 6))
	for i in 0 ..< STATS_CONTENT_COLS {
		px := margin + i32(i) * (col_w + col_gap)
		rl.DrawRectangle(px, i32(grid_top), col_w, i32(block_h), theme.OVERLAY_SCRIM_180)
	}

	y0 := i32(grid_top) + ui_px(g, 4)
	stats_draw_serving_column(g, c, col0, col_w, y0)
	stats_draw_journey_column(g, c, col1, col_w, y0)
	stats_draw_runs_column(g, c, col2, col_w, y0)

	apostle_top := grid_top + block_h + f32(ui_px(g, 10))
	apostle_block_h := panel_bottom - apostle_top
	if apostle_block_h > f32(ui_px(g, 24)) {
		rl.DrawRectangle(
			margin,
			i32(apostle_top),
			total_inner,
			i32(apostle_block_h),
			theme.OVERLAY_SCRIM_180,
		)
		stats_draw_apostle_grid(g, c, apostle_top + f32(ui_px(g, 4)))
	}

	draw_nav_button(g, "Back")
	rl.EndMode2D()
}

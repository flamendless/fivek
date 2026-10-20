package game

import rl "vendor:raylib"

Game_Tutorial :: struct {
	into_play: bool,
}

TUTORIAL_GOAL_LINES: [3]cstring = {
	"Give fish and bread to the crowd.",
	"Recruit apostles with E to help.",
	"Serve everyone to finish the run.",
}

enter_tutorial :: proc(g: ^Game, into_play: bool) {
	g.tutorial.into_play = into_play
	g.mode = .Tutorial
}

update_tutorial :: proc(g: ^Game) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.Q) {
		g.tutorial.into_play = false
		g.mode = .Title
		return
	}
	if g.tutorial.into_play && intro_skip_pressed() {
		g.prefs.tutorial_seen = true
		save_tutorial_seen()
		g.tutorial.into_play = false
		start_run(g, false)
	}
}

draw_tutorial_centered_text :: proc(g: ^Game, text: cstring, y: f32, font_size: i32, color: rl.Color) {
	w := rl.MeasureText(text, font_size)
	x := (i32(g.view.game_size.x) - w) / 2
	rl.DrawText(text, x, i32(y), font_size, color)
}

draw_tutorial :: proc(g: ^Game) {
	heading_font := ui_font(g, 18)
	body_font := ui_font(g, 14)
	ctrl_font := ui_font(g, 14)
	icon_size := f32(ui_px(g, 20))
	line_gap := f32(ui_px(g, 10))
	section_gap := f32(ui_px(g, 20))
	ctrl_line_step := ctrl_font + ui_px(g, 6)

	goal_block_h := f32(heading_font) + line_gap + f32(len(TUTORIAL_GOAL_LINES)) * (f32(body_font) + line_gap)
	ctrl_rows := 5
	ctrl_block_h := f32(heading_font) + line_gap + f32(ctrl_rows) * f32(ctrl_line_step)
	total_h := goal_block_h + section_gap + ctrl_block_h
	y := (g.view.game_size.y - total_h) * 0.5

	rl.BeginMode2D(g.cameras.ui_camera)
	draw_tutorial_centered_text(g, "Goal", y, heading_font, rl.WHITE)
	y += f32(heading_font) + line_gap
	for line in TUTORIAL_GOAL_LINES {
		draw_tutorial_centered_text(g, line, y, body_font, rl.LIGHTGRAY)
		y += f32(body_font) + line_gap
	}
	y += section_gap - line_gap

	draw_tutorial_centered_text(g, "Controls", y, heading_font, rl.WHITE)
	y += f32(heading_font) + line_gap

	draw_centered_icon_text_row(g, i32(y), ctrl_font, .Sandals, "A / D  Walk", rl.LIGHTGRAY, icon_size)
	y += f32(ctrl_line_step)
	draw_centered_icon_text_row(g, i32(y), ctrl_font, .Sandals, "Shift  Run", rl.LIGHTGRAY, icon_size)
	y += f32(ctrl_line_step)
	draw_centered_icon_text_row(g, i32(y), ctrl_font, .Fish, "F  Give fish", rl.LIGHTGRAY, icon_size)
	y += f32(ctrl_line_step)
	draw_centered_icon_text_row(g, i32(y), ctrl_font, .Bread, "B  Give bread", rl.LIGHTGRAY, icon_size)
	y += f32(ctrl_line_step)
	draw_centered_icon_text_row(g, i32(y), ctrl_font, .People, "E  Recruit apostle", rl.LIGHTGRAY, icon_size)

	if g.tutorial.into_play {
		draw_bottom_center_hint_offset(g, "Space / Enter / E - Start", ui_px(g, 12))
		draw_bottom_center_hint_offset(g, "Esc / Q - Title", ui_px(g, 28))
	} else {
		draw_bottom_center_hint_offset(g, "Esc / Q - Title", ui_px(g, 12))
	}
	rl.EndMode2D()
}

draw_bottom_center_hint_offset :: proc(g: ^Game, msg: cstring, bottom_pad: i32) {
	font := ui_font(g, 14)
	w := rl.MeasureText(msg, font)
	x := (i32(g.view.game_size.x) - w) / 2
	y: i32 = i32(g.view.game_size.y) - font - bottom_pad
	rl.DrawText(msg, x, y, font, rl.RED)
}

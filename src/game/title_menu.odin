package game

import rl "vendor:raylib"
import "../social"

update_title :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	title_fx_update(g, dt, g.title.settings_open)

	if g.title.settings_open {
		mouse := ui_mouse_game_pos(g)
		clicked := rl.IsMouseButtonPressed(.LEFT)
		update_nav_button_hover(g, "Back", mouse)
		if nav_back_pressed() || nav_button_clicked(g, "Back", mouse, clicked) {
			g.title.settings_open = false
			return
		}
		if update_title_settings(g, mouse, clicked) {
			return
		}
		return
	}

	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	g.title.hovered_menu = -1
	hovered, opened := social.update(mouse, clicked, g.view.game_size, g.view.ui_scale)
	g.title.hovered_social = hovered
	if opened {
		return
	}

	menu_size := title_font_size(g, 20)
	menu_spacing := title_char_spacing(g, 1)
	menu_step := f32(ui_px(g, 28))
	_, menu_y := title_menu_layout(g, menu_size, menu_spacing, menu_step)

	items := [5]Title_Menu{.Primary, .Tutorial, .Settings, .Credits, .Exit}
	for item in items {
		label := title_menu_label(item, g)
		bounds := title_text_bounds(g, label, menu_y, menu_size, menu_spacing)
		if rl.CheckCollisionPointRec(mouse, bounds) {
			g.title.hovered_menu = int(item)
			if clicked {
				title_menu_action(g, item)
				return
			}
		}
		menu_y += menu_step
	}

	if rl.IsKeyPressed(.ENTER) {
		title_run_primary(g)
	}
}

title_menu_action :: proc(g: ^Game, item: Title_Menu) {
	switch item {
	case .Primary:
		title_run_primary(g)
	case .Tutorial:
		enter_tutorial(g, false)
	case .Settings:
		g.title.settings_open = true
	case .Credits:
		enter_credits(g, false)
	case .Exit:
		request_app_shutdown()
	}
}

title_menu_label :: proc(item: Title_Menu, g: ^Game) -> cstring {
	switch item {
	case .Primary:
		return title_primary_label(g)
	case .Tutorial:
		return "Tutorial"
	case .Settings:
		return "Settings"
	case .Credits:
		return "Credits"
	case .Exit:
		return "Exit"
	}
	return ""
}

title_menu_layout :: proc(
	g: ^Game,
	menu_size, menu_spacing, menu_step: f32,
) -> (
	headline_bottom: f32,
	menu_y: f32,
) {
	top := f32(ui_px(g, 32))
	y := title_advance_headline_y(g, top)
	headline_bottom = y
	menu_y = y + f32(ui_px(g, 20))
	return headline_bottom, menu_y
}


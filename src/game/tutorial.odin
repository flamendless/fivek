package game

import rl "vendor:raylib"
import "../currency"
import "../food"
import "../input"
import "../person"
import "../player"
import "../theme"

TUTORIAL_GOAL_LINES: [2]cstring = {
	"Give fish and bread to the crowd. Recruit apostles with E to help.",
	"Serve everyone to finish the run.",
}

TUTORIAL_PANEL_PAD_X_DESIGN :: 20
TUTORIAL_PANEL_PAD_Y_DESIGN :: 14
TUTORIAL_PANEL_MIN_WIDTH_DESIGN :: 420
TUTORIAL_CONTENT_TOP_DESIGN :: 20
TUTORIAL_SCRIM_FULL :: rl.Color{0, 0, 0, 72}
TUTORIAL_SCRIM_PANEL :: rl.Color{0, 0, 0, 108}

tutorial_view_rect :: proc(g: ^Game) -> rl.Rectangle {
	return {0, 0, g.view.game_size.x, g.view.game_size.y}
}

tutorial_measure_icon_row :: proc(font: i32, icon: UI_Row_Icon, text: cstring, icon_size: f32) -> f32 {
	layout_w := row_icon_layout_width(icon, icon_size)
	return layout_w + UI_ICON_TEXT_GAP + f32(rl.MeasureText(text, font))
}

tutorial_content_layout :: proc(
	g: ^Game,
) -> (
	content_y: f32,
	content_h: f32,
	content_w: f32,
	heading_font: i32,
	body_font: i32,
	ctrl_font: i32,
	icon_size: f32,
	ctrl_line_step: i32,
) {
	heading_font = ui_font(g, 18)
	body_font = ui_font(g, 14)
	ctrl_font = ui_font(g, 14)
	icon_size = f32(ui_px(g, 20))
	line_gap := f32(ui_px(g, 10))
	section_gap := f32(ui_px(g, 20))
	ctrl_line_step = ctrl_font + ui_px(g, 6)

	content_w = f32(rl.MeasureText("Goal", heading_font))
	for line in TUTORIAL_GOAL_LINES {
		content_w = max(content_w, f32(rl.MeasureText(line, body_font)))
	}
	content_w = max(content_w, f32(rl.MeasureText("Controls", heading_font)))
	content_w = max(
		content_w,
		tutorial_measure_icon_row(ctrl_font, .Sandals, "A / D  Walk", icon_size),
	)
	content_w = max(
		content_w,
		tutorial_measure_icon_row(ctrl_font, .Sandals, "Shift  Run", icon_size),
	)
	content_w = max(
		content_w,
		tutorial_measure_icon_row(ctrl_font, .Fish, "F  Give fish", icon_size),
	)
	content_w = max(
		content_w,
		tutorial_measure_icon_row(ctrl_font, .Bread, "B  Give bread", icon_size),
	)
	content_w = max(
		content_w,
		tutorial_measure_icon_row(ctrl_font, .People, "E  Recruit apostle", icon_size),
	)
	content_w = max(content_w, f32(ui_px(g, TUTORIAL_PANEL_MIN_WIDTH_DESIGN)))

	goal_block_h := f32(heading_font) + line_gap + f32(len(TUTORIAL_GOAL_LINES)) * (f32(body_font) + line_gap)
	ctrl_block_h := f32(heading_font) + line_gap + f32(GAMEPLAY_CONTROL_ROW_COUNT) * f32(ctrl_line_step)
	content_h = goal_block_h + section_gap + ctrl_block_h
	content_y = f32(ui_px(g, TUTORIAL_CONTENT_TOP_DESIGN))
	return
}

Game_Tutorial :: struct {
	into_play:     bool,
	crowd:         ^person.Crowd_Scene,
	player:        ^player.Player,
	stats:         person.Run_Stats,
	stats_pledged: person.Run_Stats,
	dropped_coins: [dynamic]currency.Dropped_Coin,
	coins:         u32,
}

tutorial_free_scene :: proc(g: ^Game) {
	person.free_crowd_scene(g.tutorial.crowd)
	g.tutorial.crowd = nil
	if g.tutorial.player != nil {
		free(g.tutorial.player)
		g.tutorial.player = nil
	}
	delete(g.tutorial.dropped_coins)
	g.tutorial.dropped_coins = {}
	g.tutorial.stats = {}
	g.tutorial.stats_pledged = {}
	g.tutorial.coins = 0
}

enter_tutorial :: proc(g: ^Game, into_play: bool) {
	tutorial_free_scene(g)
	g.tutorial.into_play = into_play
	g.tutorial.crowd = person.init_crowd_scene(
		{
			seed = g.seed.value,
			game_width = g.view.game_size.x,
			game_height = g.view.game_size.y,
			crowd_count = person.TUTORIAL_CROWD_COUNT,
			apostle_count = person.TUTORIAL_APOSTLE_COUNT,
		},
	)
	people := g.tutorial.crowd.people
	people.run_stats = &g.tutorial.stats
	people.coin_drops = &g.tutorial.dropped_coins
	g.tutorial.player = player.init({PLAYER_START_X, 0}, g.defs.player_speed)
	g.view.world_width = g.view.game_size.x
	g.mode = .Tutorial
}

update_tutorial :: proc(g: ^Game) {
	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	update_nav_button_hover(g, "Back", mouse)
	if nav_back_pressed() || nav_button_clicked(g, "Back", mouse, clicked) {
		g.tutorial.into_play = false
		tutorial_free_scene(g)
		g.mode = .Title
		return
	}
	if g.tutorial.into_play && intro_skip_pressed() {
		g.prefs.tutorial_seen = true
		save_tutorial_seen()
		g.tutorial.into_play = false
		tutorial_free_scene(g)
		start_run(g, false)
		return
	}

	if g.tutorial.crowd == nil || g.tutorial.player == nil {
		return
	}

	dt := rl.GetFrameTime()
	people := g.tutorial.crowd.people
	pl := g.tutorial.player
	ground := g.tutorial.crowd.ground

	person.tick_apostle_reject_speech(people, pl.pos, pl.size)

	mods := player.player_modifiers_default()
	player.update(pl, ground, g.view.world_width, mods, dt)
	view := tutorial_view_rect(g)

	person.update_people(people, view, g.frame, dt)
	person.update_crowd_scene_lineup_apostles(g.tutorial.crowd, dt)

	bonuses := person.party_bonuses(people)
	interact_radius := g.defs.interact_radius + bonuses.interact_radius_add
	perk_ctx := person.Apostle_Perk_Ctx {
		world = nil,
		player_pos = pl.pos,
		player_size = pl.size,
		player_facing = pl.facing,
		interact_radius = interact_radius,
		run_stats = &g.tutorial.stats,
		coins = &g.tutorial.coins,
	}
	person.update_apostle_follow(people, perk_ctx, dt)
	currency.tick_drops(&g.tutorial.dropped_coins, dt)

	fish_down := input.key_down(.F)
	bread_down := input.key_down(.B)
	e_down := input.key_down(.E)
	g.input.interact_index = person.nearest_interact_index(
		people,
		pl.pos,
		pl.size,
		interact_radius,
	)
	g.input.apostle_interact_index = person.nearest_apostle_interact_index(
		people,
		pl.pos,
		pl.size,
		interact_radius,
	)

	if fish_down && !g.input.fish_was_down {
		person.try_give_item(people, pl.pos, pl.size, interact_radius, .Fish, &g.tutorial.stats)
	}
	if bread_down && !g.input.bread_was_down {
		person.try_give_item(people, pl.pos, pl.size, interact_radius, .Bread, &g.tutorial.stats)
	}
	g.input.fish_was_down = fish_down
	g.input.bread_was_down = bread_down
	if e_down && !g.input.e_was_down {
		player_rect := rl.Rectangle{pl.pos.x, pl.pos.y, pl.size.x, pl.size.y}
		currency.try_pickup(&g.tutorial.dropped_coins, player_rect, &g.tutorial.coins)
		available := person.run_stats_available(g.tutorial.stats, g.tutorial.stats_pledged)
		person.try_interact_apostle(
			people,
			pl.pos,
			pl.size,
			interact_radius,
			available,
			&g.tutorial.stats_pledged,
		)
	}
	g.input.e_was_down = e_down
}

draw_tutorial_centered_text :: proc(g: ^Game, text: cstring, y: f32, font_size: i32, color: rl.Color) {
	w := rl.MeasureText(text, font_size)
	x := (i32(g.view.game_size.x) - w) / 2
	rl.DrawText(text, x, i32(y), font_size, color)
}

draw_tutorial :: proc(g: ^Game) {
	content_y, content_h, content_w, heading_font, body_font, ctrl_font, icon_size, ctrl_line_step :=
		tutorial_content_layout(g)
	line_gap := f32(ui_px(g, 10))
	section_gap := f32(ui_px(g, 20))
	panel_pad_x := f32(ui_px(g, TUTORIAL_PANEL_PAD_X_DESIGN))
	panel_pad_y := f32(ui_px(g, TUTORIAL_PANEL_PAD_Y_DESIGN))
	panel_w := content_w + panel_pad_x * 2
	panel_h := content_h + panel_pad_y * 2
	panel_x := (g.view.game_size.x - panel_w) * 0.5
	panel_y := content_y - panel_pad_y

	rl.BeginMode2D(g.cameras.ui_camera)
	draw_title_pattern_bg(g)

	if g.tutorial.crowd != nil && g.tutorial.player != nil {
		view := tutorial_view_rect(g)
		people := g.tutorial.crowd.people
		pl := g.tutorial.player
		ground := g.tutorial.crowd.ground

		if ground != nil {
			rl.DrawRectangleV(ground.pos, ground.size, rl.BROWN)
		}
		person.draw_people(people, view)
		person.draw_food_bubbles(people, view)
		currency.draw_drops(&g.tutorial.dropped_coins, view)
		avail := person.run_stats_available(g.tutorial.stats, g.tutorial.stats_pledged)
		person.draw_apostle_overlays(people, view, pl.pos, pl.size, avail)
		if g.input.interact_index >= 0 {
			person.draw_person_outline(people, g.input.interact_index, rl.RED)
		}
		if g.input.apostle_interact_index >= 0 {
			person.draw_person_outline(people, g.input.apostle_interact_index, theme.DEBUG_CYAN)
		}
		player.draw(pl)
	}

	rl.DrawRectangle(
		0,
		0,
		i32(g.view.game_size.x),
		i32(g.view.game_size.y),
		TUTORIAL_SCRIM_FULL,
	)
	rl.DrawRectangle(
		i32(panel_x),
		i32(panel_y),
		i32(panel_w),
		i32(panel_h),
		TUTORIAL_SCRIM_PANEL,
	)

	y := content_y
	draw_tutorial_centered_text(g, "Goal", y, heading_font, rl.WHITE)
	y += f32(heading_font) + line_gap
	for line in TUTORIAL_GOAL_LINES {
		draw_tutorial_centered_text(g, line, y, body_font, rl.LIGHTGRAY)
		y += f32(body_font) + line_gap
	}
	y += section_gap - line_gap

	draw_tutorial_centered_text(g, "Controls", y, heading_font, rl.WHITE)
	y += f32(heading_font) + line_gap

	draw_centered_gameplay_controls(g, i32(y), ctrl_font, icon_size, ctrl_line_step)

	if g.tutorial.into_play {
		draw_bottom_center_hint_offset(g, "Space / Enter / E - Start", ui_px(g, 12))
	}
	draw_nav_button(g, "Back")
	rl.EndMode2D()
}

draw_bottom_center_hint_offset :: proc(g: ^Game, msg: cstring, bottom_pad: i32) {
	font := ui_font(g, 14)
	w := rl.MeasureText(msg, font)
	x := (i32(g.view.game_size.x) - w) / 2
	y: i32 = i32(g.view.game_size.y) - font - bottom_pad
	rl.DrawText(msg, x, y, font, rl.RED)
}

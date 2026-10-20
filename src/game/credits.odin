package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../food"
import "../person"
import "../social"
import "../theme"

CREDIT_ASSET_COUNT :: 11

CREDITS_ATTR_FONT_DESIGN :: 18
CREDITS_ASSET_BASE_DESIGN :: 28
CREDITS_ASSET_SCALE_MIN :: 1.1
CREDITS_ASSET_SCALE_MAX :: 1.4
CREDITS_ASSETS_COLS :: 6
CREDITS_GRID_TOP_PAD_DESIGN :: 28
CREDITS_ASSETS_LABEL_DESIGN :: 16
CREDITS_ASSETS_LABEL_GAP_DESIGN :: 10
CREDITS_ASSETS_LABEL_CLEAR_DESIGN :: 10

Credit_Asset :: struct {
	name: cstring,
	url:  cstring,
}

CREDIT_ASSETS: []Credit_Asset = {
	{"Font", "https://www.fontspace.com/sholom-font-f39980"},
	{"16x16 Character Template", "https://5yvalia.itch.io/16x16-character-template-8-direction"},
	{"Nature Landscape", "https://free-game-assets.itch.io/nature-landscapes-free-pixel-art"},
	{"Fish Icons", "https://pixel-late.itch.io/16x16-freshwater-and-saltwater-fish-icons"},
	{"Bread", "https://yuu63.itch.io/free-bread-32x32-pixel-art-bread-assets"},
	{"Gems / Coins", "https://laredgames.itch.io/gems-coins-free"},
	{"Leather Sandals", "https://freegamesprites.com/en/assets/sandals-leather"},
	{"General UI", "https://gowldev.itch.io/ui-buttons-scrolling-bars-pixel-art"},
	{"Time and Money", "https://samucar-ale.itch.io/time-and-money-by-heart"},
	{"Social Media Buttons", "https://cazwolf.itch.io/caz-social-media"},
	{"Rough Textures", "https://dijonpickle.itch.io/seamless-rough-textures"},
}

Credit_Asset_Runtime :: struct {
	use_bread:    bool,
	icon:         int,
	size:         f32,
	anchor:       rl.Vector2,
	wiggle_phase: f32,
	wiggle_freq:  f32,
	wiggle_rot:   f32,
	wiggle_pos:   f32,
}

Game_Credits :: struct {
	from_victory:      bool,
	hovered_asset:     int,
	hovered_apostle:   int,
	assets:            [CREDIT_ASSET_COUNT]Credit_Asset_Runtime,
	crowd:             ^person.Crowd_Scene,
}

credits_asset_base_size :: proc(g: ^Game) -> f32 {
	return f32(ui_px(g, CREDITS_ASSET_BASE_DESIGN))
}

credits_random_asset_size :: proc(g: ^Game) -> f32 {
	scale := CREDITS_ASSET_SCALE_MIN + rand.float32() * (CREDITS_ASSET_SCALE_MAX - CREDITS_ASSET_SCALE_MIN)
	return credits_asset_base_size(g) * scale
}

credits_attribution_layout :: proc(g: ^Game) -> (victory_y: f32, line1_y: f32, line2_y: f32, social_row_y: f32) {
	attr_font := ui_font(g, CREDITS_ATTR_FONT_DESIGN)
	line_gap := f32(ui_px(g, 8))
	section_gap := f32(ui_px(g, 12))
	social_gap := f32(ui_px(g, 10))

	y := f32(ui_px(g, 16))
	if g.credits.from_victory {
		victory_y = y
		y += f32(ui_font(g, 14)) + section_gap
	} else {
		victory_y = -1
	}
	line1_y = y
	line2_y = y + f32(attr_font) + line_gap
	social_row_y = line2_y + f32(attr_font) + social_gap
	return victory_y, line1_y, line2_y, social_row_y
}

credits_social_row_y :: proc(g: ^Game) -> f32 {
	_, _, _, social_row_y := credits_attribution_layout(g)
	return social_row_y
}

credits_social_layout :: proc(g: ^Game) -> (x: f32, y: f32, size: f32, gap: f32) {
	return social.layout_centered_at(g.view.game_size, g.view.ui_scale, credits_social_row_y(g))
}

credits_grid_cell_size :: proc(g: ^Game) -> f32 {
	return credits_asset_base_size(g) * CREDITS_ASSET_SCALE_MAX
}

credits_assets_label_y :: proc(g: ^Game) -> f32 {
	_, social_y, social_size, _ := credits_social_layout(g)
	return social_y + social_size + f32(ui_px(g, CREDITS_GRID_TOP_PAD_DESIGN))
}

credits_asset_grid_top :: proc(g: ^Game) -> f32 {
	label_y := credits_assets_label_y(g)
	label_font := ui_font(g, CREDITS_ASSETS_LABEL_DESIGN)
	return (
		label_y +
		f32(label_font) +
		f32(ui_px(g, CREDITS_ASSETS_LABEL_GAP_DESIGN)) +
		f32(ui_px(g, CREDITS_ASSETS_LABEL_CLEAR_DESIGN))
	)
}

credits_assets_in_row :: proc(row: int) -> int {
	if row == 0 {
		return min(CREDIT_ASSET_COUNT, CREDITS_ASSETS_COLS)
	}
	return CREDIT_ASSET_COUNT - CREDITS_ASSETS_COLS
}

credits_asset_anchor :: proc(g: ^Game, index: int) -> rl.Vector2 {
	cell := credits_grid_cell_size(g)
	gap := f32(ui_px(g, 4))
	grid_top := credits_asset_grid_top(g)
	row := index / CREDITS_ASSETS_COLS
	col := index % CREDITS_ASSETS_COLS
	items_in_row := credits_assets_in_row(row)
	row_w := f32(items_in_row) * cell + f32(items_in_row - 1) * gap
	ox := (g.view.game_size.x - row_w) * 0.5
	cx := ox + f32(col) * (cell + gap) + cell * 0.5
	cy := grid_top + f32(row) * (cell + gap) + cell * 0.5
	return {cx, cy}
}

credits_asset_dest :: proc(r: ^Credit_Asset_Runtime) -> rl.Rectangle {
	return food.icon_dest_rect(r.anchor, r.size)
}

credits_init_wiggle :: proc(g: ^Game, r: ^Credit_Asset_Runtime) {
	r.wiggle_phase = rand.float32() * math.TAU
	r.wiggle_freq = 4.0 + rand.float32() * 5.0
	r.wiggle_rot = 6.0 + rand.float32() * 10.0
	r.wiggle_pos = f32(ui_px(g, 1)) + rand.float32() * f32(ui_px(g, 2))
}

credits_init_asset :: proc(g: ^Game, index: int, r: ^Credit_Asset_Runtime) {
	r.use_bread = rand.int_max(2) == 0
	r.icon =
		r.use_bread ? rand.int_max(food.BREAD_ICON_COUNT) : rand.int_max(food.FISH_ICON_COUNT)
	r.size = credits_random_asset_size(g)
	r.anchor = credits_asset_anchor(g, index)
	credits_init_wiggle(g, r)
}

credits_relayout_assets :: proc(g: ^Game) {
	for i in 0 ..< CREDIT_ASSET_COUNT {
		g.credits.assets[i].anchor = credits_asset_anchor(g, i)
	}
}

credits_free_crowd :: proc(g: ^Game) {
	person.free_crowd_scene(g.credits.crowd)
	g.credits.crowd = nil
}

enter_credits :: proc(g: ^Game, from_victory: bool) {
	credits_free_crowd(g)
	g.credits.from_victory = from_victory
	g.credits.hovered_asset = -1
	g.credits.hovered_apostle = -1
	g.title.hovered_social = -1
	g.title.settings_open = false
	for i in 0 ..< CREDIT_ASSET_COUNT {
		credits_init_asset(g, i, &g.credits.assets[i])
	}
	g.credits.crowd = person.init_crowd_scene(
		{
			seed = g.seed.value,
			game_width = g.view.game_size.x,
			game_height = g.view.game_size.y,
			crowd_count = person.CROWD_SCENE_DEFAULT_COUNT,
		},
	)
	g.mode = .Credits
}

credits_exit_to_title :: proc(g: ^Game) {
	credits_free_crowd(g)
	g.mode = .Title
}

credits_asset_rotation :: proc(r: ^Credit_Asset_Runtime) -> f32 {
	return math.sin(r.wiggle_phase * 1.37) * r.wiggle_rot
}

credits_asset_hit_index :: proc(g: ^Game, mouse: rl.Vector2) -> int {
	for i := CREDIT_ASSET_COUNT - 1; i >= 0; i -= 1 {
		r := &g.credits.assets[i]
		if rl.CheckCollisionPointRec(mouse, credits_asset_dest(r)) {
			return i
		}
	}
	return -1
}

credits_update_assets :: proc(g: ^Game, dt: f32) {
	for i in 0 ..< CREDIT_ASSET_COUNT {
		g.credits.assets[i].wiggle_phase += g.credits.assets[i].wiggle_freq * dt
	}
}

update_credits :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	credits_relayout_assets(g)
	credits_update_assets(g, dt)
	if g.credits.crowd != nil {
		view := rl.Rectangle{0, 0, g.view.game_size.x, g.view.game_size.y}
		person.update_crowd_scene(g.credits.crowd, view, g.frame, dt)
	}

	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	update_nav_button_hover(g, "Back", mouse)
	if nav_back_pressed() || nav_button_clicked(g, "Back", mouse, clicked) {
		credits_exit_to_title(g)
		return
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		credits_exit_to_title(g)
		return
	}
	g.credits.hovered_apostle = -1
	if g.credits.crowd != nil {
		g.credits.hovered_apostle = person.crowd_scene_apostle_hit(g.credits.crowd, mouse)
	}
	g.credits.hovered_asset = credits_asset_hit_index(g, mouse)
	sx, sy, ssize, sgap := credits_social_layout(g)
	hovered, opened := social.update_at(mouse, clicked, sx, sy, ssize, sgap)
	g.title.hovered_social = hovered
	if opened {
		return
	}
	if clicked && g.credits.hovered_asset >= 0 {
		social.open_link(CREDIT_ASSETS[g.credits.hovered_asset].url)
	}
}

credits_draw_centered :: proc(g: ^Game, text: cstring, y: f32, font_size: i32, color: rl.Color) {
	w := rl.MeasureText(text, font_size)
	x := (i32(g.view.game_size.x) - w) / 2
	rl.DrawText(text, x, i32(y), font_size, color)
}

credits_draw_centered_prefix_highlight :: proc(
	g: ^Game,
	prefix: cstring,
	highlight: cstring,
	y: f32,
	font_size: i32,
	prefix_color, highlight_color: rl.Color,
) {
	w_prefix := rl.MeasureText(prefix, font_size)
	w_highlight := rl.MeasureText(highlight, font_size)
	total := w_prefix + w_highlight
	x := (i32(g.view.game_size.x) - total) / 2
	rl.DrawText(prefix, x, i32(y), font_size, prefix_color)
	rl.DrawText(highlight, x + w_prefix, i32(y), font_size, highlight_color)
}

draw_credits :: proc(g: ^Game) {
	attr_font := ui_font(g, CREDITS_ATTR_FONT_DESIGN)
	victory_y, line1_y, line2_y, _ := credits_attribution_layout(g)

	rl.BeginMode2D(g.cameras.ui_camera)
	draw_title_pattern_bg(g)
	if g.credits.crowd != nil {
		view := rl.Rectangle{0, 0, g.view.game_size.x, g.view.game_size.y}
		person.draw_crowd_scene(g.credits.crowd, view, g.credits.hovered_apostle)
	}

	if g.credits.from_victory && victory_y >= 0 {
		victory_font := ui_font(g, 14)
		credits_draw_centered(g, "All fed. Thank you.", victory_y, victory_font, rl.WHITE)
	}

	credits_draw_centered_prefix_highlight(
		g,
		"game by ",
		"@flamendless",
		line1_y,
		attr_font,
		rl.BLACK,
		rl.RED,
	)
	credits_draw_centered_prefix_highlight(
		g,
		"character arts by ",
		"@wits",
		line2_y,
		attr_font,
		rl.BLACK,
		rl.RED,
	)

	sx, sy, ssize, sgap := credits_social_layout(g)
	social.draw_row_at(
		g.title.social_atlas,
		g.title.hovered_social,
		true,
		sx,
		sy,
		ssize,
		sgap,
		g.view.ui_scale,
	)

	if food.ready() {
		line_w := f32(max(ui_px(g, 1), 1))
		for i in 0 ..< CREDIT_ASSET_COUNT {
			r := &g.credits.assets[i]
			dest := credits_asset_dest(r)
			rot := credits_asset_rotation(r)
			tint := rl.WHITE
			if g.credits.hovered_asset == i {
				tint = theme.SOCIAL_ICON_HOVER
			}
			tex := r.use_bread ? food.bread_tex : food.fish_tex
			cell := r.use_bread ? f32(food.BREAD_CELL_SIZE) : f32(food.FISH_CELL_SIZE)
			cols := r.use_bread ? food.BREAD_ATLAS_COLS : food.FISH_ATLAS_COLS
			food.draw_icon_tinted_in_dest(tex, r.icon, cell, cols, dest, tint, rot)
			if g.credits.hovered_asset == i {
				rl.DrawRectangleLinesEx(dest, line_w, rl.RED)
				social.draw_tooltip_above(CREDIT_ASSETS[i].name, dest, g.view.ui_scale)
			}
		}
	}

	assets_label_font := ui_font(g, CREDITS_ASSETS_LABEL_DESIGN)
	credits_draw_centered(
		g,
		"used free assets",
		credits_assets_label_y(g),
		assets_label_font,
		rl.BLACK,
	)

	draw_nav_button(g, "Back")
	if g.credits.from_victory {
		draw_bottom_center_hint_offset(g, "Enter / Space - Title", ui_px(g, 12))
	}
	rl.EndMode2D()
}

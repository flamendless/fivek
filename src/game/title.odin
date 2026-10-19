package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:os"
import rl "vendor:raylib"
import "../pattern_bg"
import "../theme"

TITLE_FONT_PATH :: "assets/fonts/sholom/Sholom-Yz3J4.ttf"
SOCIAL_ATLAS_PATH :: "assets/social/atlas.png"
SOCIAL_CELL_SIZE: f32 : 32
SOCIAL_ATLAS_COLS :: 11

TITLE_HEADLINE_SHOLOM :: "Bread, Fish, Repeat"
TITLE_HEADLINE_SUFFIX :: "5000x"
TITLE_HEADLINE_SUFFIX_FONT_DESIGN :: 28
TITLE_VERSION_FONT_DESIGN :: 12

TITLE_PATTERN_CELLS_ACROSS :: 2
TITLE_PATTERN_ZOOM_MIN :: 1.5
TITLE_PATTERN_ZOOM_MAX :: 3.0
TITLE_PATTERN_SPEED_MIN :: 14.0
TITLE_PATTERN_SPEED_MAX :: 22.0

Title_Menu :: enum {
	Primary,
	Tutorial,
	Settings,
	Exit,
}

Social_Link :: struct {
	atlas_index: int,
	url:        cstring,
}

SOCIAL_LINKS: [4]Social_Link = {
	{1, "https://www.facebook.com/flamendlessstudio"},
	{2, "https://x.com/flam8studio"},
	{8, "https://www.youtube.com/@flamendless"},
	{25, "https://flamendless.itch.io"},
}

@(private = "file")
title_sholom: rl.Font

@(private = "file")
title_social_atlas: rl.Texture2D

@(private = "file")
title_settings_open: bool

@(private = "file")
title_hovered_menu: int = -1

@(private = "file")
title_hovered_social: int = -1

@(private = "file")
title_pattern: ^pattern_bg.Screen_Pattern

@(private = "file")
title_pattern_config :: proc() -> pattern_bg.Config {
	variant := pattern_bg.random_variant()
	return {
		bg_color   = theme.random_pattern_bg_color(),
		variant    = variant,
		subvariant = pattern_bg.random_subvariant(variant),
		direction  = pattern_bg.random_direction(),
		speed      = TITLE_PATTERN_SPEED_MIN + rand.float32() * (TITLE_PATTERN_SPEED_MAX - TITLE_PATTERN_SPEED_MIN),
		zoom       = TITLE_PATTERN_ZOOM_MIN + rand.float32() * (TITLE_PATTERN_ZOOM_MAX - TITLE_PATTERN_ZOOM_MIN),
	}
}

load_title_assets :: proc() {
	if title_sholom.texture.id == 0 {
		log.infof("loading title font %s", TITLE_FONT_PATH)
		title_sholom = rl.LoadFont(TITLE_FONT_PATH)
		if title_sholom.texture.id == 0 {
			log.warnf("failed to load title font %s", TITLE_FONT_PATH)
		} else {
			rl.SetTextureFilter(title_sholom.texture, .POINT)
		}
	}
	if title_social_atlas.id == 0 {
		log.infof("loading social atlas %s", SOCIAL_ATLAS_PATH)
		title_social_atlas = rl.LoadTexture(SOCIAL_ATLAS_PATH)
		if title_social_atlas.id != 0 {
			rl.SetTextureFilter(title_social_atlas, .POINT)
		} else {
			log.warnf("failed to load social atlas %s", SOCIAL_ATLAS_PATH)
		}
	}
	if title_pattern == nil {
		p, ok := pattern_bg.create(title_pattern_config())
		if !ok {
			log.warn("failed to create title pattern background")
		} else {
			title_pattern = p
		}
	}
}

unload_title_assets :: proc() {
	if title_sholom.texture.id != 0 {
		log.infof("unloading title font %s", TITLE_FONT_PATH)
		rl.UnloadFont(title_sholom)
		title_sholom = {}
	}
	if title_social_atlas.id != 0 {
		log.infof("unloading social atlas %s", SOCIAL_ATLAS_PATH)
		rl.UnloadTexture(title_social_atlas)
		title_social_atlas = {}
	}
	pattern_bg.destroy(title_pattern)
	title_pattern = nil
}

reload_title_random :: proc() {
	if title_pattern != nil {
		if !pattern_bg.set_config(title_pattern, title_pattern_config()) {
			log.warn("title: failed to reload pattern background")
		}
	}
	title_fx_reset()
}

title_ui_font :: proc() -> rl.Font {
	if title_sholom.texture.id != 0 {
		return title_sholom
	}
	return rl.GetFontDefault()
}

title_font_size :: proc(g: ^Game, design: f32) -> f32 {
	return f32(ui_px(g, design))
}

title_char_spacing :: proc(g: ^Game, design: f32) -> f32 {
	return f32(ui_px(g, design))
}

title_measure :: proc(g: ^Game, text: cstring, size, spacing: f32) -> rl.Vector2 {
	return rl.MeasureTextEx(title_ui_font(), text, size, spacing)
}

title_text_outline_px :: proc(g: ^Game) -> f32 {
	return f32(max(ui_px(g, 1), 1))
}

@(private = "file")
title_draw_text_outlined :: proc(
	font: rl.Font,
	text: cstring,
	pos: rl.Vector2,
	size, spacing, outline_px: f32,
	fill, outline: rl.Color,
) {
	for dx in -1 ..= 1 {
		for dy in -1 ..= 1 {
			if dx == 0 && dy == 0 do continue
			rl.DrawTextEx(
				font,
				text,
				{pos.x + f32(dx) * outline_px, pos.y + f32(dy) * outline_px},
				size,
				spacing,
				outline,
			)
		}
	}
	rl.DrawTextEx(font, text, pos, size, spacing, fill)
}

title_draw_centered :: proc(g: ^Game, text: cstring, y: f32, size, spacing: f32, color: rl.Color) {
	m := title_measure(g, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	rl.DrawTextEx(title_ui_font(), text, {x, y}, size, spacing, color)
}

title_draw_centered_outlined :: proc(
	g: ^Game,
	text: cstring,
	y: f32,
	size, spacing: f32,
	fill, outline: rl.Color,
) {
	m := title_measure(g, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	title_draw_text_outlined(title_ui_font(), text, {x, y}, size, spacing, title_text_outline_px(g), fill, outline)
}

title_measure_default :: proc(g: ^Game, text: cstring, design: i32) -> rl.Vector2 {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	return rl.MeasureTextEx(font, text, size, spacing)
}

title_draw_centered_default :: proc(g: ^Game, text: cstring, y: f32, design: i32, color: rl.Color) {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	m := rl.MeasureTextEx(font, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	rl.DrawTextEx(font, text, {x, y}, size, spacing, color)
}

title_draw_centered_default_outlined :: proc(
	g: ^Game,
	text: cstring,
	y: f32,
	design: i32,
	fill, outline: rl.Color,
) {
	font := rl.GetFontDefault()
	size := f32(ui_font(g, design))
	spacing := title_char_spacing(g, 1)
	m := rl.MeasureTextEx(font, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	title_draw_text_outlined(font, text, {x, y}, size, spacing, title_text_outline_px(g), fill, outline)
}

title_advance_headline_y :: proc(g: ^Game, start_y: f32) -> f32 {
	headline_size := title_font_size(g, 28)
	headline_spacing := title_char_spacing(g, 1)
	headline_gap := f32(ui_px(g, 4))
	y := start_y
	m := title_measure(g, TITLE_HEADLINE_SHOLOM, headline_size, headline_spacing)
	y += m.y + headline_gap
	m = title_measure_default(g, TITLE_HEADLINE_SUFFIX, TITLE_HEADLINE_SUFFIX_FONT_DESIGN)
	y += m.y + headline_gap
	return y
}

title_text_bounds :: proc(g: ^Game, text: cstring, y: f32, size, spacing: f32) -> rl.Rectangle {
	m := title_measure(g, text, size, spacing)
	x := (g.view.game_size.x - m.x) * 0.5
	pad := f32(ui_px(g, 6))
	return {x - pad, y - pad, m.x + pad * 2, m.y + pad * 2}
}

title_has_save :: proc(g: ^Game) -> bool {
	when ODIN_OS == .JS {
		return fivek_web_storage_get_len() > 0
	} else {
		return os.exists(g.persist.save_path)
	}
}

title_primary_label :: proc(g: ^Game) -> cstring {
	if title_has_save(g) {
		return "Continue"
	}
	return "Start"
}

title_run_primary :: proc(g: ^Game) {
	if title_has_save(g) {
		start_run(g, true)
		return
	}
	if g.intro.tutorial_seen {
		start_run(g, false)
	} else {
		enter_tutorial(g, true)
	}
}

title_menu_action :: proc(g: ^Game, item: Title_Menu) {
	switch item {
	case .Primary:
		title_run_primary(g)
	case .Tutorial:
		enter_tutorial(g, false)
	case .Settings:
		title_settings_open = true
	case .Exit:
		request_app_shutdown()
	}
}

title_social_src :: proc(index: int) -> rl.Rectangle {
	i := index - 1
	col := i % SOCIAL_ATLAS_COLS
	row := i / SOCIAL_ATLAS_COLS
	return {
		f32(col) * SOCIAL_CELL_SIZE,
		f32(row) * SOCIAL_CELL_SIZE,
		SOCIAL_CELL_SIZE,
		SOCIAL_CELL_SIZE,
	}
}

update_title :: proc(g: ^Game) {
	dt := rl.GetFrameTime()
	title_fx_update(g, dt, title_settings_open)

	if title_settings_open {
		if rl.IsKeyPressed(.ESCAPE) {
			title_settings_open = false
		}
		return
	}

	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	title_hovered_menu = -1
	title_hovered_social = -1
	for i in 0 ..< len(SOCIAL_LINKS) {
		if _, ok := title_social_hit(g, SOCIAL_LINKS[i], mouse); ok {
			title_hovered_social = i
			break
		}
	}

	if clicked {
		for link in SOCIAL_LINKS {
			if _, ok := title_social_hit(g, link, mouse); ok {
				when ODIN_OS == .JS {
					fivek_open_url(link.url)
				} else {
					rl.OpenURL(link.url)
				}
				return
			}
		}
	}

	menu_size := title_font_size(g, 20)
	menu_spacing := title_char_spacing(g, 1)
	menu_step := f32(ui_px(g, 28))
	_, menu_y := title_menu_layout(g, menu_size, menu_spacing, menu_step)

	items := [4]Title_Menu{.Primary, .Tutorial, .Settings, .Exit}
	for item in items {
		label := title_menu_label(item, g)
		bounds := title_text_bounds(g, label, menu_y, menu_size, menu_spacing)
		if rl.CheckCollisionPointRec(mouse, bounds) {
			title_hovered_menu = int(item)
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

title_menu_label :: proc(item: Title_Menu, g: ^Game) -> cstring {
	switch item {
	case .Primary:
		return title_primary_label(g)
	case .Tutorial:
		return "Tutorial"
	case .Settings:
		return "Settings"
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

title_social_layout :: proc(g: ^Game) -> (x: f32, y: f32, size: f32, gap: f32) {
	pad := f32(ui_px(g, 8))
	size = f32(ui_px(g, 24))
	gap = f32(ui_px(g, 4))
	x = pad
	y = g.view.game_size.y - pad - size
	return x, y, size, gap
}

title_social_hit :: proc(g: ^Game, link: Social_Link, mouse: rl.Vector2) -> (rl.Rectangle, bool) {
	x, y, size, gap := title_social_layout(g)
	for i in 0 ..< len(SOCIAL_LINKS) {
		r := rl.Rectangle{x, y, size, size}
		if link == SOCIAL_LINKS[i] {
			return r, rl.CheckCollisionPointRec(mouse, r)
		}
		x += size + gap
	}
	return {}, false
}

draw_title :: proc(g: ^Game) {
	headline_size := title_font_size(g, 28)
	headline_spacing := title_char_spacing(g, 1)
	menu_size := title_font_size(g, 20)
	menu_spacing := title_char_spacing(g, 1)
	menu_step := f32(ui_px(g, 28))

	rl.BeginMode2D(g.cameras.ui_camera)

	if title_pattern != nil {
		bounds := rl.Rectangle{0, 0, g.view.game_size.x, g.view.game_size.y}
		pattern_bg.draw_grid(title_pattern, bounds, TITLE_PATTERN_CELLS_ACROSS)
	}

	title_fx_draw_fish(g)

	top := f32(ui_px(g, 32))
	headline_gap := f32(ui_px(g, 4))
	y := top
	title_draw_centered_outlined(g, TITLE_HEADLINE_SHOLOM, y, headline_size, headline_spacing, rl.WHITE, rl.BLACK)
	m := title_measure(g, TITLE_HEADLINE_SHOLOM, headline_size, headline_spacing)
	y += m.y + headline_gap
	title_draw_centered_default_outlined(
		g,
		TITLE_HEADLINE_SUFFIX,
		y,
		TITLE_HEADLINE_SUFFIX_FONT_DESIGN,
		rl.WHITE,
		rl.BLACK,
	)
	m = title_measure_default(g, TITLE_HEADLINE_SUFFIX, TITLE_HEADLINE_SUFFIX_FONT_DESIGN)
	y += m.y + headline_gap

	_, menu_y := title_menu_layout(g, menu_size, menu_spacing, menu_step)
	items := [4]Title_Menu{.Primary, .Tutorial, .Settings, .Exit}
	for item in items {
		label := title_menu_label(item, g)
		color := rl.LIGHTGRAY
		if title_hovered_menu == int(item) {
			color = rl.WHITE
		}
		title_draw_centered(g, label, menu_y, menu_size, menu_spacing, color)
		menu_y += menu_step
	}

	if title_social_atlas.id != 0 {
		sx, sy, ssize, sgap := title_social_layout(g)
		for i in 0 ..< len(SOCIAL_LINKS) {
			link := SOCIAL_LINKS[i]
			src := title_social_src(link.atlas_index)
			dest := rl.Rectangle{sx, sy, ssize, ssize}
			tint := rl.WHITE
			if title_hovered_social == i {
				tint = theme.SOCIAL_ICON_HOVER
			}
			rl.DrawTexturePro(title_social_atlas, src, dest, {}, 0, tint)
			if title_hovered_social == i {
				outline_pad := f32(ui_px(g, 1))
				outline := rl.Rectangle {
					dest.x - outline_pad,
					dest.y - outline_pad,
					dest.width + outline_pad * 2,
					dest.height + outline_pad * 2,
				}
				rl.DrawRectangleLinesEx(outline, f32(max(ui_px(g, 1), 1)), rl.RED)
			}
			sx += ssize + sgap
		}
	}

	ver := fmt.ctprintf("build: v%s", g.defs.version)
	ver_m := title_measure_default(g, ver, TITLE_VERSION_FONT_DESIGN)
	ver_pad := f32(ui_px(g, 8))
	ver_x := g.view.game_size.x - ver_m.x - ver_pad
	ver_y := g.view.game_size.y - ver_m.y - ver_pad
	ver_font := rl.GetFontDefault()
	ver_size := f32(ui_font(g, TITLE_VERSION_FONT_DESIGN))
	ver_spacing := title_char_spacing(g, 1)
	rl.DrawTextEx(ver_font, ver, {ver_x, ver_y}, ver_size, ver_spacing, rl.RED)

	if title_settings_open {
		rl.DrawRectangle(0, 0, i32(g.view.game_size.x), i32(g.view.game_size.y), theme.OVERLAY_SCRIM_180)
		settings_size := title_font_size(g, 24)
		settings_spacing := title_char_spacing(g, 1)
		block_gap := f32(ui_px(g, 12))
		h_m := title_measure(g, "Settings", settings_size, settings_spacing)
		b_m := title_measure(g, "Coming soon", menu_size, menu_spacing)
		block_h := h_m.y + block_gap + b_m.y
		sy := (g.view.game_size.y - block_h) * 0.5
		title_draw_centered(g, "Settings", sy, settings_size, settings_spacing, rl.WHITE)
		title_draw_centered(g, "Coming soon", sy + h_m.y + block_gap, menu_size, menu_spacing, rl.LIGHTGRAY)
	}

	title_fx_draw_bread(g)

	rl.EndMode2D()
}

package game

import "core:math"
import "core:strings"
import rl "vendor:raylib"
import "../achievements"
import ui_assets "../ui"
import "../theme"

ACHIEVEMENTS_HEADER_DESIGN :: 22
ACHIEVEMENTS_CARD_TITLE_DESIGN :: 12
ACHIEVEMENTS_CARD_DESC_DESIGN :: 10
ACHIEVEMENTS_GRID_COLS :: 3
ACHIEVEMENTS_CARD_PAD_DESIGN :: 10
ACHIEVEMENTS_GRID_GAP_DESIGN :: 6
ACHIEVEMENTS_MARGIN_DESIGN :: 6
ACHIEVEMENTS_HEADER_GAP_DESIGN :: 6

ACHIEVEMENTS_GRID_ROWS :: (achievements.ACHIEVEMENT_COUNT + ACHIEVEMENTS_GRID_COLS - 1) / ACHIEVEMENTS_GRID_COLS
ACHIEVEMENTS_LOCKED_DESC :: "??????"

enter_achievements :: proc(g: ^Game) {
	load_title_assets(g)
	g.mode = .Achievements
}

achievements_exit_to_title :: proc(g: ^Game) {
	g.mode = .Title
}

achievements_grid_layout :: proc(g: ^Game, grid_top: f32) -> (card_w, card_h, gap, margin: i32) {
	margin = ui_px(g, ACHIEVEMENTS_MARGIN_DESIGN)
	gap = ui_px(g, ACHIEVEMENTS_GRID_GAP_DESIGN)
	total_inner_w := i32(g.view.game_size.x) - margin * 2
	card_w = (total_inner_w - gap * (ACHIEVEMENTS_GRID_COLS - 1)) / ACHIEVEMENTS_GRID_COLS

	grid_bottom := g.view.game_size.y - f32(margin)
	avail_h := grid_bottom - grid_top
	if avail_h <= 0 {
		card_h = ui_px(g, 48)
		return
	}
	row_gap := f32(gap * (ACHIEVEMENTS_GRID_ROWS - 1))
	card_h = i32(math.max((avail_h - row_gap) / f32(ACHIEVEMENTS_GRID_ROWS), 1))
	return
}

update_achievements :: proc(g: ^Game) {
	mouse := ui_mouse_game_pos(g)
	clicked := rl.IsMouseButtonPressed(.LEFT)
	update_nav_button_hover(g, "Back", mouse)
	if nav_back_pressed() || nav_button_clicked(g, "Back", mouse, clicked) {
		achievements_exit_to_title(g)
		return
	}
	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.ESCAPE) {
		achievements_exit_to_title(g)
	}
}

@(private = "file")
achievements_text_width :: proc(text: cstring, font: i32) -> i32 {
	spacing := f32(1)
	return i32(rl.MeasureTextEx(rl.GetFontDefault(), text, f32(font), spacing).x)
}

Achievements_Wrap_Ctx :: struct {
	x, cur_y, max_w, font, line_step: i32,
	font_rl:                  rl.Font,
	size, spacing:            f32,
	color:                    rl.Color,
	measure_only:             bool,
	line:                     [256]u8,
	line_len:                 int,
}

@(private = "file")
achievements_wrap_fits :: proc(ctx: ^Achievements_Wrap_Ctx, n: int) -> bool {
	if n <= 0 {
		return true
	}
	ctx.line[n] = 0
	return achievements_text_width(cstring(&ctx.line[0]), ctx.font) <= ctx.max_w
}

@(private = "file")
achievements_wrap_flush :: proc(ctx: ^Achievements_Wrap_Ctx) {
	if ctx.line_len == 0 {
		return
	}
	ctx.line[ctx.line_len] = 0
	line := cstring(&ctx.line[0])
	if !ctx.measure_only {
		line_w := achievements_text_width(line, ctx.font)
		draw_x := ctx.x + (ctx.max_w - line_w) / 2
		rl.DrawTextEx(ctx.font_rl, line, {f32(draw_x), f32(ctx.cur_y)}, ctx.size, ctx.spacing, ctx.color)
	}
	ctx.cur_y += ctx.line_step
	ctx.line_len = 0
}

@(private = "file")
achievements_wrap_put_word :: proc(ctx: ^Achievements_Wrap_Ctx, word: string) {
	if len(word) == 0 {
		return
	}
	trial_len := ctx.line_len
	if trial_len > 0 {
		ctx.line[trial_len] = ' '
		trial_len += 1
	}
	if trial_len+len(word) >= len(ctx.line) {
		achievements_wrap_flush(ctx)
		achievements_wrap_put_word(ctx, word)
		return
	}
	copy(ctx.line[trial_len:], word)
	trial_len += len(word)
	if achievements_wrap_fits(ctx, trial_len) {
		ctx.line_len = trial_len
		return
	}
	if ctx.line_len > 0 {
		achievements_wrap_flush(ctx)
		trial_len = 0
		if len(word) < len(ctx.line) {
			copy(ctx.line[:], word)
			trial_len = len(word)
		}
		if achievements_wrap_fits(ctx, trial_len) {
			ctx.line_len = trial_len
			return
		}
		achievements_wrap_flush(ctx)
	}
	for i := 0; i < len(word); {
		best := i
		for j := i + 1; j <= len(word); j += 1 {
			chunk := word[i:j]
			if len(chunk) >= len(ctx.line) {
				break
			}
			copy(ctx.line[:], chunk)
			if achievements_text_width(cstring(&ctx.line[0]), ctx.font) <= ctx.max_w {
				best = j
			} else {
				break
			}
		}
		if best == i {
			best = min(i + 1, len(word))
		}
		chunk := word[i:best]
		copy(ctx.line[:], chunk)
		ctx.line_len = len(chunk)
		achievements_wrap_flush(ctx)
		i = best
	}
}

@(private = "file")
achievements_wrap_text :: proc(ctx: ^Achievements_Wrap_Ctx, text: cstring) {
	s := string(text)
	if len(s) == 0 {
		return
	}
	rest := s
	for len(rest) > 0 {
		idx := strings.index_byte(rest, ' ')
		if idx < 0 {
			achievements_wrap_put_word(ctx, rest)
			break
		}
		if idx > 0 {
			achievements_wrap_put_word(ctx, rest[:idx])
		}
		rest = rest[idx + 1:]
		for len(rest) > 0 && rest[0] == ' ' {
			rest = rest[1:]
		}
	}
	achievements_wrap_flush(ctx)
}

@(private = "file")
achievements_wrapped_height :: proc(text: cstring, max_w, font, line_step: i32) -> i32 {
	if max_w <= 0 || len(string(text)) == 0 {
		return 0
	}
	ctx := Achievements_Wrap_Ctx {
		max_w         = max_w,
		font          = font,
		line_step     = line_step,
		measure_only  = true,
	}
	achievements_wrap_text(&ctx, text)
	return ctx.cur_y
}

@(private = "file")
achievements_card_inner_pad :: proc(g: ^Game) -> i32 {
	return ui_px(g, 2)
}

@(private = "file")
achievements_line_step :: proc(font: i32) -> i32 {
	return font + 1
}

@(private = "file")
achievements_card_block_height :: proc(
	title, body: cstring,
	text_w, title_font, desc_font, title_step, desc_step, text_gap: i32,
) -> i32 {
	h := achievements_wrapped_height(title, text_w, title_font, title_step)
	if len(string(body)) > 0 {
		h += text_gap + achievements_wrapped_height(body, text_w, desc_font, desc_step)
	}
	return h
}

@(private = "file")
achievements_draw_card_text :: proc(
	g: ^Game,
	content: rl.Rectangle,
	unlocked: bool,
	def: achievements.Achievement_Def,
	title_font, desc_font: i32,
) {
	inner := achievements_card_inner_pad(g)
	text_x := i32(content.x) + inner
	text_w := i32(content.width) - inner * 2
	if text_w <= 0 {
		return
	}
	avail_h := i32(content.height) - inner * 2
	if avail_h <= 0 {
		return
	}

	title_step := achievements_line_step(title_font)
	desc_step := achievements_line_step(desc_font)
	text_gap := ui_px(g, 2)
	body := unlocked ? def.description : ACHIEVEMENTS_LOCKED_DESC
	body_color := unlocked ? theme.TEXT_INK : rl.GRAY
	title_col := unlocked ? theme.TEXT_INK : rl.GRAY

	for _ in 0 ..< 32 {
		block_h := achievements_card_block_height(
			def.title,
			body,
			text_w,
			title_font,
			desc_font,
			title_step,
			desc_step,
			text_gap,
		)
		if block_h <= avail_h {
			break
		}
		if title_step > title_font {
			title_step -= 1
		} else if desc_step > desc_font {
			desc_step -= 1
		} else if text_gap > 1 {
			text_gap -= 1
		} else {
			break
		}
	}

	y0 := i32(content.y) + inner

	ty := achievements_draw_wrapped(def.title, text_x, y0, text_w, title_font, title_step, title_col)
	if len(string(body)) > 0 {
		ty += text_gap
		_ = achievements_draw_wrapped(body, text_x, ty, text_w, desc_font, desc_step, body_color)
	}
}

achievements_draw_wrapped :: proc(text: cstring, x, y, max_w, font, line_step: i32, color: rl.Color) -> i32 {
	if max_w <= 0 {
		return y
	}
	if len(string(text)) == 0 {
		return y
	}

	ctx := Achievements_Wrap_Ctx {
		x          = x,
		cur_y      = y,
		max_w      = max_w,
		font       = font,
		line_step  = line_step,
		font_rl    = rl.GetFontDefault(),
		size       = f32(font),
		spacing    = 1,
		color      = color,
	}
	achievements_wrap_text(&ctx, text)
	return ctx.cur_y
}

draw_achievements :: proc(g: ^Game) {
	rl.BeginMode2D(g.cameras.ui_camera)
	draw_title_pattern_bg(g)

	header_y := f32(ui_px(g, 16))
	title_draw_centered_default_outlined(g, "Achievements", header_y, ACHIEVEMENTS_HEADER_DESIGN, rl.WHITE, rl.BLACK)

	header_h := title_measure_default(g, "Achievements", ACHIEVEMENTS_HEADER_DESIGN).y
	grid_top := header_y + header_h + f32(ui_px(g, ACHIEVEMENTS_HEADER_GAP_DESIGN))
	card_w, card_h, gap, margin := achievements_grid_layout(g, grid_top)

	title_font := ui_font(g, ACHIEVEMENTS_CARD_TITLE_DESIGN)
	desc_font := ui_font(g, ACHIEVEMENTS_CARD_DESC_DESIGN)

	for id in achievements.Id {
		i := int(id)
		col := i % ACHIEVEMENTS_GRID_COLS
		row := i / ACHIEVEMENTS_GRID_COLS
		x := margin + i32(col) * (card_w + gap)
		y := i32(grid_top) + i32(row) * (card_h + gap)

		unlocked := achievements.is_unlocked(g.ach_state, id)
		def := achievements.ACHIEVEMENT_DEFS[id]

		panel := rl.Rectangle{f32(x), f32(y), f32(card_w), f32(card_h)}
		ui_assets.draw_wood_panel(panel)
		content := ui_assets.wood_panel_content(panel, 0)
		achievements_draw_card_text(g, content, unlocked, def, title_font, desc_font)
	}

	draw_nav_button(g, "Back")
	rl.EndMode2D()
}

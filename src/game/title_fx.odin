package game

import "core:log"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../food"

TITLE_FX_SPAWN_MIN :: 1.2
TITLE_FX_SPAWN_MAX :: 2.1
TITLE_FX_STAGGER_MIN :: 0.22
TITLE_FX_STAGGER_MAX :: 0.48
TITLE_FX_CHANCE_MIN :: 30
TITLE_FX_CHANCE_MAX :: 60
TITLE_FX_MAX_SPEED :: 6096.0
TITLE_FX_BASE_SPEED :: 648.0
TITLE_FX_SPEED_PER_MISS :: 72.0
TITLE_FX_MAX_SIZE_SCALE :: 5.0
TITLE_FX_SIZE_PER_MISS :: 0.2
TITLE_FX_MAX_FISH :: 12
TITLE_FX_EDGE_MARGIN :: 20.0
TITLE_FX_BREAD_DESIGN :: 24
TITLE_FX_FISH_BASE_DESIGN :: 24

Title_Fx_Edge :: enum {
	Left,
	Right,
	Top,
	Bottom,
}

Title_Fish :: struct {
	start:     rl.Vector2,
	end:       rl.Vector2,
	t:         f32,
	icon:      int,
	draw_size: f32,
	speed:     f32,
	path_len:  f32,
}

Game_Title_Fx :: struct {
	active:           bool,
	bread_icon:       int,
	miss_streak:      int,
	spawn_cooldown:   f32,
	wave_pending:     int,
	stagger_cooldown: f32,
	fish:             [dynamic]Title_Fish,
}

title_fx_randomize_bread :: proc(g: ^Game, reason: cstring) {
	fx := &g.title.fx
	prev := fx.bread_icon
	fx.bread_icon = rand.int_max(food.BREAD_ICON_COUNT)
	log.infof("title fx: bread icon %d -> %d (%s)", prev, fx.bread_icon, reason)
}

title_fx_next_spawn_delay :: proc() -> f32 {
	return rand.float32() * (TITLE_FX_SPAWN_MAX - TITLE_FX_SPAWN_MIN) + TITLE_FX_SPAWN_MIN
}

title_fx_next_stagger_delay :: proc() -> f32 {
	return rand.float32() * (TITLE_FX_STAGGER_MAX - TITLE_FX_STAGGER_MIN) + TITLE_FX_STAGGER_MIN
}

title_fx_lerp :: proc(a, b: rl.Vector2, t: f32) -> rl.Vector2 {
	return a + (b - a) * t
}

title_fx_fish_pos :: proc(f: ^Title_Fish) -> rl.Vector2 {
	return title_fx_lerp(f.start, f.end, f.t)
}

title_fx_fish_fully_outside :: proc(g: ^Game, pos: rl.Vector2, half: f32) -> bool {
	w := g.view.game_size.x
	h := g.view.game_size.y
	if pos.x + half < 0 {
		return true
	}
	if pos.x - half > w {
		return true
	}
	if pos.y + half < 0 {
		return true
	}
	if pos.y - half > h {
		return true
	}
	return false
}

title_fx_wave_count :: proc(g: ^Game) -> int {
	return min(TITLE_FX_MAX_FISH, 1 + g.title.fx.miss_streak)
}

title_fx_wave_speed :: proc(g: ^Game) -> f32 {
	return min(
		TITLE_FX_MAX_SPEED,
		TITLE_FX_BASE_SPEED + f32(g.title.fx.miss_streak) * TITLE_FX_SPEED_PER_MISS,
	)
}

title_fx_wave_size_scale :: proc(g: ^Game) -> f32 {
	return min(TITLE_FX_MAX_SIZE_SCALE, 1.0 + f32(g.title.fx.miss_streak) * TITLE_FX_SIZE_PER_MISS)
}

title_fx_edge_name :: proc(edge: Title_Fx_Edge) -> cstring {
	switch edge {
	case .Left:
		return "left"
	case .Right:
		return "right"
	case .Top:
		return "top"
	case .Bottom:
		return "bottom"
	}
	return "?"
}

title_fx_rand_on_span :: proc(span: f32) -> f32 {
	if span <= 0 {
		return 0
	}
	return rand.float32() * span
}

title_fx_spawn_points :: proc(
	g: ^Game,
	edge: Title_Fx_Edge,
) -> (
	start: rl.Vector2,
	end: rl.Vector2,
) {
	w := g.view.game_size.x
	h := g.view.game_size.y
	m: f32 = TITLE_FX_EDGE_MARGIN
	switch edge {
	case .Left:
		start = {-m, title_fx_rand_on_span(h)}
		end = {w, title_fx_rand_on_span(h)}
	case .Right:
		start = {w + m, title_fx_rand_on_span(h)}
		end = {0, title_fx_rand_on_span(h)}
	case .Top:
		start = {title_fx_rand_on_span(w), -m}
		end = {title_fx_rand_on_span(w), h}
	case .Bottom:
		start = {title_fx_rand_on_span(w), h + m}
		end = {title_fx_rand_on_span(w), 0}
	}
	return start, end
}

title_fx_spawn_one_fish :: proc(g: ^Game) -> bool {
	fx := &g.title.fx
	if !food.ready() {
		return false
	}
	if len(fx.fish) >= TITLE_FX_MAX_FISH {
		log.infof("title fx: spawn skipped (capped at %d active fish)", TITLE_FX_MAX_FISH)
		return false
	}
	speed := title_fx_wave_speed(g)
	scale := title_fx_wave_size_scale(g)
	base_size := f32(ui_px(g, TITLE_FX_FISH_BASE_DESIGN))
	draw_size := base_size * scale
	edges := [4]Title_Fx_Edge{.Left, .Right, .Top, .Bottom}
	edge := edges[rand.int_max(len(edges))]
	start, end := title_fx_spawn_points(g, edge)
	path_len := max(rl.Vector2Distance(start, end), 1.0)
	icon := rand.int_max(food.FISH_ICON_COUNT)
	append(
		&fx.fish,
		Title_Fish {
			start = start,
			end = end,
			t = 0,
			icon = icon,
			draw_size = draw_size,
			speed = speed,
			path_len = path_len,
		},
	)
	log.infof(
		"title fx: fish #%d icon=%d edge=%s start=(%.0f,%.0f) end=(%.0f,%.0f) path_len=%.0f active=%d",
		len(fx.fish) - 1,
		icon,
		title_fx_edge_name(edge),
		start.x,
		start.y,
		end.x,
		end.y,
		path_len,
		len(fx.fish),
	)
	return true
}

title_fx_begin_wave :: proc(g: ^Game) {
	fx := &g.title.fx
	if !food.ready() {
		log.warn("title fx: spawn wave skipped (food atlases not ready)")
		return
	}
	count := title_fx_wave_count(g)
	log.infof(
		"title fx: wave start count=%d speed=%.0f scale=%.2f miss_streak=%d active=%d",
		count,
		title_fx_wave_speed(g),
		title_fx_wave_size_scale(g),
		fx.miss_streak,
		len(fx.fish),
	)
	fx.wave_pending = count
	fx.stagger_cooldown = 0
}

title_fx_tick_wave_spawn :: proc(g: ^Game) {
	fx := &g.title.fx
	if fx.wave_pending <= 0 || fx.stagger_cooldown > 0 {
		return
	}
	if !title_fx_spawn_one_fish(g) {
		fx.wave_pending = 0
		return
	}
	fx.wave_pending -= 1
	if fx.wave_pending > 0 {
		fx.stagger_cooldown = title_fx_next_stagger_delay()
	}
}

title_fx_try_spawn :: proc(g: ^Game) {
	fx := &g.title.fx
	chance := rand.int_max(TITLE_FX_CHANCE_MAX - TITLE_FX_CHANCE_MIN + 1) + TITLE_FX_CHANCE_MIN
	roll := rand.int_max(100)
	passed := roll < chance
	log.infof(
		"title fx: spawn attempt chance=%d%% roll=%d -> %s (miss_streak=%d)",
		chance,
		roll,
		passed ? "spawn" : "skip",
		fx.miss_streak,
	)
	if !passed {
		return
	}
	title_fx_begin_wave(g)
}

title_fx_reset :: proc(g: ^Game) {
	fx := &g.title.fx
	title_fx_destroy_all_fish(g, "reset")
	fx.miss_streak = 0
	fx.bread_icon = -1
	title_fx_randomize_bread(g, "reset")
	fx.spawn_cooldown = title_fx_next_spawn_delay()
	fx.wave_pending = 0
	fx.stagger_cooldown = 0
	log.infof("title fx: reset miss_streak=0 next_spawn_in=%.2fs", fx.spawn_cooldown)
}

title_fx_on_enter :: proc(g: ^Game) {
	fx := &g.title.fx
	if fx.active {
		return
	}
	log.info("title fx: enter title")
	title_fx_reset(g)
	rl.HideCursor()
	fx.active = true
}

title_fx_on_leave :: proc(g: ^Game) {
	fx := &g.title.fx
	if !fx.active {
		return
	}
	log.info("title fx: leave title")
	title_fx_destroy_all_fish(g, "leave")
	rl.ShowCursor()
	fx.active = false
}

title_fx_bread_size :: proc(g: ^Game) -> f32 {
	return f32(ui_px(g, TITLE_FX_BREAD_DESIGN))
}

title_fx_destroy_fish :: proc(g: ^Game, i: int, reason: cstring) {
	fx := &g.title.fx
	f := fx.fish[i]
	pos := title_fx_fish_pos(&f)
	remaining := len(fx.fish) - 1
	log.infof(
		"title fx: fish destroyed icon=%d reason=%s t=%.2f pos=(%.0f,%.0f) remaining=%d",
		f.icon,
		reason,
		f.t,
		pos.x,
		pos.y,
		remaining,
	)
	ordered_remove(&fx.fish, i)
}

title_fx_destroy_all_fish :: proc(g: ^Game, reason: cstring) {
	fx := &g.title.fx
	for i := len(fx.fish) - 1; i >= 0; i -= 1 {
		title_fx_destroy_fish(g, i, reason)
	}
}

title_fx_update :: proc(g: ^Game, dt: f32, frozen: bool) {
	fx := &g.title.fx
	if !fx.active || !food.ready() {
		return
	}

	if !frozen {
		fx.spawn_cooldown -= dt
		if fx.spawn_cooldown <= 0 {
			next := title_fx_next_spawn_delay()
			log.infof("title fx: spawn timer fired next_in=%.2fs", next)
			fx.spawn_cooldown = next
			title_fx_try_spawn(g)
		}
		if fx.wave_pending > 0 {
			fx.stagger_cooldown -= dt
			title_fx_tick_wave_spawn(g)
		}
	}

	mouse := ui_mouse_game_pos(g)
	bread_r := title_fx_bread_size(g) * 0.5

	for i := len(fx.fish) - 1; i >= 0; i -= 1 {
		f := &fx.fish[i]
		if !frozen {
			f.t += (f.speed * dt) / f.path_len
		}
		pos := title_fx_fish_pos(f)
		fish_r := f.draw_size * 0.5

		if rl.Vector2Distance(pos, mouse) <= fish_r + bread_r {
			title_fx_randomize_bread(g, "catch")
			fx.miss_streak = 0
			title_fx_destroy_fish(g, i, "catch")
			continue
		}

		if f.t >= 1.0 && title_fx_fish_fully_outside(g, pos, fish_r) {
			fx.miss_streak += 1
			log.infof(
				"title fx: miss (next wave count=%d speed=%.0f miss_streak=%d)",
				title_fx_wave_count(g),
				title_fx_wave_speed(g),
				fx.miss_streak,
			)
			title_fx_destroy_fish(g, i, "miss")
		}
	}
}

title_fx_draw_fish :: proc(g: ^Game) {
	fx := &g.title.fx
	if !food.ready() {
		return
	}
	cell := f32(food.FISH_CELL_SIZE)
	cols := food.FISH_ATLAS_COLS

	for &f in fx.fish {
		pos := title_fx_fish_pos(&f)
		delta := f.end - f.start
		rot := math.atan2(delta.y, delta.x) * (180.0 / math.PI)

		src := food.atlas_src_rect(f.icon, cell, cols)
		half := f.draw_size * 0.5
		dest := rl.Rectangle{pos.x - half, pos.y - half, f.draw_size, f.draw_size}
		origin := rl.Vector2{half, half}
		rl.DrawTexturePro(food.fish_tex, src, dest, origin, rot, rl.WHITE)
	}
}

title_fx_draw_bread :: proc(g: ^Game) {
	fx := &g.title.fx
	if !food.ready() {
		return
	}
	mouse := ui_mouse_game_pos(g)
	size := title_fx_bread_size(g)
	food.draw_icon(
		food.bread_tex,
		fx.bread_icon,
		f32(food.BREAD_CELL_SIZE),
		food.BREAD_ATLAS_COLS,
		mouse,
		size,
	)
}

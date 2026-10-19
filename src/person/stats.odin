package person

import "core:fmt"
import rl "vendor:raylib"
import "../food"
import "../ui"

STAT_KIND_COUNT :: 7
STAT_BUBBLE_ICON_INDEX :: 0

Stat_Kind :: enum {
	Total_Served,
	Fish_Given,
	Bread_Given,
	Fed_Kids,
	Fed_Young,
	Fed_Adults,
	Distance_Walked,
}

Run_Stats :: struct {
	total_served: u32,
	fish_given:   u32,
	bread_given:  u32,
	fed_kids:     u32,
	fed_young:    u32,
	fed_adults:   u32,
	distance_walked: u32,
}

Apostle_Req :: struct {
	kind:   Stat_Kind,
	amount: u32,
}

Apostle_Requirements :: struct {
	reqs:  [STAT_KIND_COUNT]Apostle_Req,
	count: u8,
}

stat_value :: proc(stats: Run_Stats, kind: Stat_Kind) -> u32 {
	switch kind {
	case .Total_Served:
		return stats.total_served
	case .Fish_Given:
		return stats.fish_given
	case .Bread_Given:
		return stats.bread_given
	case .Fed_Kids:
		return stats.fed_kids
	case .Fed_Young:
		return stats.fed_young
	case .Fed_Adults:
		return stats.fed_adults
	case .Distance_Walked:
		return stats.distance_walked
	}
	return 0
}

stat_set :: proc(stats: ^Run_Stats, kind: Stat_Kind, v: u32) {
	switch kind {
	case .Total_Served:
		stats.total_served = v
	case .Fish_Given:
		stats.fish_given = v
	case .Bread_Given:
		stats.bread_given = v
	case .Fed_Kids:
		stats.fed_kids = v
	case .Fed_Young:
		stats.fed_young = v
	case .Fed_Adults:
		stats.fed_adults = v
	case .Distance_Walked:
		stats.distance_walked = v
	}
}

stat_add :: proc(stats: ^Run_Stats, kind: Stat_Kind, delta: u32) {
	v := stat_value(stats^, kind)
	stat_set(stats, kind, v + delta)
}

run_stats_available :: proc(run: Run_Stats, pledged: Run_Stats) -> Run_Stats {
	out: Run_Stats
	for k in Stat_Kind {
		a := stat_value(run, k)
		p := stat_value(pledged, k)
		if a > p {
			stat_set(&out, k, a - p)
		}
	}
	return out
}

requirements_met :: proc(available: Run_Stats, reqs: Apostle_Requirements) -> bool {
	for i in 0 ..< int(reqs.count) {
		r := reqs.reqs[i]
		if stat_value(available, r.kind) < r.amount {
			return false
		}
	}
	return true
}

pledge_requirements :: proc(pledged: ^Run_Stats, reqs: Apostle_Requirements) {
	for i in 0 ..< int(reqs.count) {
		r := reqs.reqs[i]
		stat_add(pledged, r.kind, r.amount)
	}
}

stat_kind_short :: proc(kind: Stat_Kind) -> cstring {
	switch kind {
	case .Total_Served:
		return "Served"
	case .Fish_Given:
		return "Fish"
	case .Bread_Given:
		return "Bread"
	case .Fed_Kids:
		return "Kids"
	case .Fed_Young:
		return "Young"
	case .Fed_Adults:
		return "Adults"
	case .Distance_Walked:
		return "Dist"
	}
	return "?"
}

stat_req_met :: proc(available: u32, required: u32) -> bool {
	return available >= required
}

stat_req_numbers :: proc(available: u32, required: u32) -> cstring {
	return fmt.ctprintf("%d/%d", available, required)
}

stat_kind_uses_icon :: proc(kind: Stat_Kind) -> bool {
	switch kind {
	case .Fish_Given, .Bread_Given:
		return food.ready()
	case .Total_Served, .Distance_Walked:
		return ui.ready()
	case .Fed_Kids, .Fed_Young, .Fed_Adults:
		return false
	}
	return false
}

stat_symbol_width :: proc(kind: Stat_Kind, font: i32) -> f32 {
	if stat_kind_uses_icon(kind) {
		return ui.UI_ICON_DRAW_SIZE
	}
	return f32(rl.MeasureText(stat_kind_short(kind), font))
}

draw_stat_symbol :: proc(
	kind: Stat_Kind,
	left_x: f32,
	row_top: f32,
	row_h: f32,
	font: i32,
	text_color: rl.Color,
) {
	symbol_col := ui.UI_ICON_DRAW_SIZE
	cy := row_top + row_h * 0.5
	if stat_kind_uses_icon(kind) {
		cx := left_x + symbol_col * 0.5
		switch kind {
		case .Fish_Given:
			food.draw_icon(
				food.fish_tex,
				STAT_BUBBLE_ICON_INDEX,
				f32(food.FISH_CELL_SIZE),
				food.FISH_ATLAS_COLS,
				{cx, cy},
			)
		case .Bread_Given:
			food.draw_icon(
				food.bread_tex,
				STAT_BUBBLE_ICON_INDEX,
				f32(food.BREAD_CELL_SIZE),
				food.BREAD_ATLAS_COLS,
				{cx, cy},
			)
		case .Total_Served:
			ui.draw_texture_icon(ui.texture(.People), {cx, cy})
		case .Distance_Walked:
			ui.draw_texture_icon(ui.texture(.Sandals), {cx, cy})
		case .Fed_Kids, .Fed_Young, .Fed_Adults:
			break
		}
		return
	}
	label := stat_kind_short(kind)
	ty := i32(row_top + row_h) - font
	rl.DrawText(label, i32(left_x), ty, font, text_color)
}

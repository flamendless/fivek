package person

import "core:math"
import "../assets"
import ui_assets "../ui"
import rl "vendor:raylib"

emote_display_to_asset :: proc(k: Emote_Display_Kind) -> assets.Emote_Kind {
	switch k {
	case .Heart:
		return .Heart
	case .Exclamation:
		return .Exclamation
	case .Question:
		return .Question
	case .None:
		return .Heart
	}
	return .Heart
}

person_emote_asset :: proc(p: ^People, i: int) -> (k: assets.Emote_Kind, ok: bool) {
	if i < 0 || i >= len(p.rows) {
		return .Heart, false
	}
	row := p.rows[i]
	if row.identity.role != .Crowd || row.motion.phase == .Gone {
		return .Heart, false
	}
	if row.behavior.reaction_emote_timer > 0 {
		return .Exclamation, true
	}
	if row.motion.state == .Celebrating && row.behavior.celebrate_emote != .None {
		return emote_display_to_asset(row.behavior.celebrate_emote), true
	}
	if row.behavior.wake_emote_timer > 0 && row.motion.phase == .Active && !row.food.served {
		return .Zzz, true
	}
	if person_is_sleeping(p, i) && row.motion.phase == .Active && !row.food.served {
		return .Zzz, true
	}
	return .Heart, false
}

emote_pivot_y :: proc(p: ^People, i: int) -> f32 {
	row := p.rows[i]
	if food_bubble_visible(p, i) {
		icon_d := assets.food_icon_draw_size()
		bubble_h := ui_assets.parchment_height_for_inner(icon_d, 0)
		return row.transform.pos_y - bubble_h - FOOD_BUBBLE_ABOVE - EMOTE_TAIL_GAP
	}
	head_top := row.transform.pos_y + row.transform.size_h * EMOTE_HEAD_TOP_FRAC
	return head_top - EMOTE_TAIL_GAP
}

draw_person_emote :: proc(p: ^People, i: int) {
	if !assets.gameplay_ready() {
		return
	}
	kind, ok := person_emote_asset(p, i)
	if !ok {
		return
	}
	tex := assets.emote(kind)
	if tex.id == 0 {
		return
	}
	row := p.rows[i]
	size := assets.food_icon_draw_size()
	half := size * 0.5
	pcx := row.transform.pos_x + row.transform.size_w * 0.5
	src := rl.Rectangle{0, 0, f32(assets.EMOTE_CELL), f32(assets.EMOTE_CELL)}
	// Raylib: dest.x/y is the screen position of `pivot`, not dest top-left.
	anchor_y: f32
	if kind == .Zzz {
		anchor_y = row.transform.pos_y
	} else {
		anchor_y = emote_pivot_y(p, i)
	}
	dest := rl.Rectangle{pcx, anchor_y, size, size}
	pivot := rl.Vector2{half, size}
	alpha: f32 = 1
	rotation: f32 = 0
	if kind == .Zzz {
		if row.behavior.wake_emote_timer > 0 {
			alpha = row.behavior.wake_emote_timer / WAKE_EMOTE_FADE
			if row.behavior.wake_emote_shake_t > 0 {
				phase := (WAKE_EMOTE_SHAKE - row.behavior.wake_emote_shake_t) * 48
				rotation = math.sin(phase) * 12
			}
		} else if person_is_sleeping(p, i) {
			rotation = math.sin(row.motion.idle_anim_t * SLEEP_EMOTE_SWAY_SPEED) * SLEEP_EMOTE_SWAY_DEG
		}
	}
	tint := rl.Color{255, 255, 255, u8(alpha * 255)}
	rl.DrawTexturePro(tex, src, dest, pivot, rotation, tint)
}

draw_person_emotes :: proc(p: ^People, view: rl.Rectangle) {
	for i in 0 ..< len(p.rows) {
		if p.rows[i].motion.phase == .Gone {
			continue
		}
		pr := person_rect_at(p, i)
		if !rl.CheckCollisionRecs(pr, view) {
			continue
		}
		draw_person_emote(p, i)
	}
}

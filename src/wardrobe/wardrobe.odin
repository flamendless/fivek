package wardrobe

import "core:math/rand"

LOOK_VARIANTS :: 6

IDLE_FRAMES :: 6
WALK_BODY_FRAMES :: 6
WALK_OVERLAY_STEPS :: 3

CROWD_ANIM_FPS :: 9.0

Motion_Kind :: enum {
	Idle,
	Walk,
}

Idle_Layer :: enum {
	Upper,
	Head,
	Hair,
}

Appearance :: struct {
	dress: u8,
	hair:  u8,
	head:  u8,
}

roll :: proc() -> Appearance {
	return {
		dress = u8(rand.int_max(LOOK_VARIANTS)),
		hair  = u8(rand.int_max(LOOK_VARIANTS)),
		head  = u8(rand.int_max(LOOK_VARIANTS)),
	}
}

overlay_column :: proc(look: u8) -> int {
	if int(look) >= LOOK_VARIANTS {
		return LOOK_VARIANTS - 1
	}
	return int(look)
}

idle_base_frame :: proc(idle_anim_t: f32) -> int {
	return int(idle_anim_t * CROWD_ANIM_FPS) % IDLE_FRAMES
}

walk_body_frame :: proc(walk_anim_t: f32) -> int {
	return int(walk_anim_t * CROWD_ANIM_FPS) % WALK_BODY_FRAMES
}

walk_overlay_index :: proc(look: u8, walk_anim_t: f32) -> int {
	body := walk_body_frame(walk_anim_t)
	step := body / 2
	return overlay_column(look) + step * LOOK_VARIANTS
}

idle_layer_look :: proc(appearance: Appearance, layer: Idle_Layer) -> u8 {
	switch layer {
	case .Upper:
		return appearance.dress
	case .Head:
		return appearance.head
	case .Hair:
		return appearance.hair
	}
	return 0
}

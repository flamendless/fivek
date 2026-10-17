package person

import "core:math/rand"
import rl "vendor:raylib"
import "../world"

WALK_SPEED :: 28.0
RUN_SPEED :: 56.0
OFFSCREEN_UPDATE_INTERVAL :: 4
CELEBRATE_HOP_MIN :: 2
CELEBRATE_HOP_MAX :: 5
CELEBRATE_HOP_HEIGHT :: 12.0
CELEBRATE_HOP_DURATION :: 0.12

LINEUP_PAD :: 4.0
LINEUP_SLOT_PITCH :: 14.0
LINEUP_ROW_DEPTH :: 8.0
POST_SERVE_SPEED_MULT :: 2.0
WALL_IDLE_GRACE :: 0.15
CHILD_FLEE_DISTANCE_MIN :: 48.0
CHILD_FLEE_DISTANCE_MAX :: 96.0

Person_State :: enum {
	Idle,
	Walking,
	Running,
	Celebrating,
}

Person_Phase :: enum {
	Active,
	Run_Lineup,
	Run_Home,
	In_Lineup,
	Gone,
	Following,
}

Person_Role :: enum {
	Crowd,
	Apostle,
}

Person_Age :: enum {
	Adult,
	Young,
	Kid,
}

Person_Subbehavior :: enum {
	None,
	Flee_After_Food,
}

Person :: struct {
	pos_x, pos_y: f32,
	size_w, size_h: f32,
	bound_min_x, bound_max_x: f32,
	state: Person_State,
	phase: Person_Phase,
	age: Person_Age,
	timer: f32,
	dir: f32,
	hop_step: u8,
	hop_count: u8,
	hop_timer: f32,
	base_y: f32,
	target_x, target_y: f32,
	line_row: int,
	has_fish, has_bread: bool,
	fish_icon, bread_icon: u8,
	served: bool,
	speed_scale: f32,
	color: rl.Color,
	last_roam: Person_State,
	subbehavior: Person_Subbehavior,
	flee_remaining: f32,
	role: Person_Role,
	apostle_idx: u8,
	required_served: u16,
	party_slot: int,
	reject_flash: f32,
}

PARTY_TRAIL_CAP :: 2048

People :: struct {
	rows: #soa[]Person,
	crowd_count: int,
	party_count: int,
	lineup_chunk_width: f32,
	lineup_ground_y: f32,
	lineup_next_slot: int,
	party_trail_x: [PARTY_TRAIL_CAP]f32,
	party_trail_head: int,
	party_trail_count: int,
}

Give_Item :: enum {
	Fish,
	Bread,
}

age_from_u8 :: proc(v: u8) -> Person_Age {
	switch v {
	case 0:
		return .Adult
	case 1:
		return .Young
	case:
		return .Kid
	}
}

color_from_u32 :: proc(c: u32) -> rl.Color {
	return {
		u8((c >> 16) & 0xff),
		u8((c >> 8) & 0xff),
		u8(c & 0xff),
		u8((c >> 24) & 0xff),
	}
}

rand_float_range :: proc(lo, hi: f32) -> f32 {
	return lo + (hi - lo) * rand.float32()
}

init_people :: proc(spawn: #soa[]world.Spawn_Person, lineup_chunk_width: f32, lineup_ground_y: f32) -> ^People {
	p := new(People)
	p.lineup_chunk_width = lineup_chunk_width
	p.lineup_ground_y = lineup_ground_y
	n := len(spawn)
	p.crowd_count = n
	p.party_count = 0
	p.rows = make_soa_slice(#soa[]Person, n) or_else panic("people alloc failed")
	for i in 0 ..< n {
		s := spawn[i]
		p.rows[i] = Person{
			pos_x = s.pos_x,
			pos_y = s.pos_y,
			size_w = s.size_w,
			size_h = s.size_h,
			base_y = s.pos_y,
			bound_min_x = s.bound_min_x,
			bound_max_x = s.bound_max_x,
			state = .Idle,
			phase = .Active,
			age = age_from_u8(s.age),
			timer = rand_float_range(0.5, 2.0),
			dir = 1,
			speed_scale = s.speed_scale,
			color = color_from_u32(s.color),
			role = .Crowd,
			party_slot = -1,
		}
	}
	return p
}

free_people :: proc(p: ^People) {
	if p == nil {
		return
	}
	delete(p.rows)
	free(p)
}

person_rect_at :: proc(p: ^People, i: int) -> rl.Rectangle {
	return {p.rows[i].pos_x, p.rows[i].pos_y, p.rows[i].size_w, p.rows[i].size_h}
}

draw_rect_outline :: proc(rect: rl.Rectangle, color: rl.Color) {
	rl.DrawRectangleLinesEx(rect, 1, color)
}

is_interactable :: proc(p: ^People, i: int) -> bool {
	return p.rows[i].role == .Crowd &&
		p.rows[i].phase == .Active &&
		!p.rows[i].served &&
		p.rows[i].state != .Celebrating &&
		p.rows[i].subbehavior == .None
}

is_crowd_row :: proc(p: ^People, i: int) -> bool {
	return i >= 0 && i < p.crowd_count
}

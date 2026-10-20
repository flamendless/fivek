package person

import "core:math/rand"
import rl "vendor:raylib"
import "../currency"
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
PARTY_TRAIL_CAP :: 2048

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
	Frozen_Talk,
	Escort_To_Player,
	Scared_To_Chunk,
}

Apostle_Perk :: enum {
	Follow,
	Minister_Approach,
	Minister_Give,
	Peter_To_Chunk0,
	Peter_Return,
	Andrew_Go,
	Andrew_Escort,
	James_Hop,
	John_Hop,
	Philip_Think,
	Bartholomew_Visit,
	Bartholomew_Idle,
	Thomas_Fade_Out,
	Thomas_Hidden,
	Thomas_Fade_In,
	Judas_Approach,
	Judas_Talk,
	Judas_Angry,
}

Perk_Bubble_Kind :: enum {
	None,
	Intent_Text,
	Judas_Coin,
	Judas_Angry,
	Philip_Calc,
	Passive_Text,
}

Perk_Bubble :: struct {
	kind:   Perk_Bubble_Kind,
	timer:  f32,
	text:   cstring,
	coin_icon: u8,
	philip_fish: u8,
	philip_bread: u8,
}

Give_Item :: enum {
	Fish,
	Bread,
}

Person_Transform :: struct {
	pos_x, pos_y: f32,
	size_w, size_h: f32,
	bound_min_x, bound_max_x: f32,
	base_y: f32,
	dir: f32,
}

Person_Nav :: struct {
	target_x, target_y: f32,
	line_row: int,
}

Person_Motion :: struct {
	state: Person_State,
	phase: Person_Phase,
	timer: f32,
	last_roam: Person_State,
	hop_step, hop_count: u8,
	hop_timer: f32,
}

Person_Traits :: struct {
	age: Person_Age,
	color: rl.Color,
	speed_scale: f32,
	draw_alpha: f32,
}

Person_Food :: struct {
	has_fish, has_bread: bool,
	fish_icon, bread_icon: u8,
	served: bool,
}

Person_Behavior :: struct {
	subbehavior: Person_Subbehavior,
	flee_remaining: f32,
	reject_speech_show: bool,
}

Person_Identity :: struct {
	role: Person_Role,
	apostle_idx: u8,
	party_slot: int,
}

Person_Perk :: struct {
	apostle_perk: Apostle_Perk,
	perk_timer: f32,
	perk_cooldown: f32,
	minister_cooldown: f32,
	perk_target_i: int,
	perk_aux: int,
	perk_bubble: Perk_Bubble,
	passive_timer: f32,
}

Person :: struct {
	transform: Person_Transform,
	nav:       Person_Nav,
	motion:    Person_Motion,
	traits:    Person_Traits,
	food:      Person_Food,
	behavior:  Person_Behavior,
	identity:  Person_Identity,
	perk:      Person_Perk,
}

People_Lineup :: struct {
	chunk_width: f32,
	ground_y: f32,
	next_slot: int,
}

People_Party :: struct {
	count: int,
	trail_x: [PARTY_TRAIL_CAP]f32,
	trail_head: int,
	trail_count: int,
}

People_Escort :: struct {
	targets: [5]int,
	count: int,
}

People_Debug :: struct {
	apostle_perk_log:           bool,
	apostle_inspector_open:      bool,
	apostle_inspector_slot:      int,
}

People :: struct {
	rows: #soa[]Person,
	crowd_count: int,
	lineup: People_Lineup,
	party: People_Party,
	apostle_requirements: [APOSTLE_COUNT]Apostle_Requirements,
	apostle_reject_speech: [APOSTLE_COUNT]u8,
	run_stats: ^Run_Stats,
	coin_drops: ^[dynamic]currency.Dropped_Coin,
	escort: People_Escort,
	debug: People_Debug,
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
	p.lineup.chunk_width = lineup_chunk_width
	p.lineup.ground_y = lineup_ground_y
	n := len(spawn)
	p.crowd_count = n
	p.party.count = 0
	p.rows = make_soa_slice(#soa[]Person, n) or_else panic("people alloc failed")
	for i in 0 ..< n {
		s := spawn[i]
		p.rows[i] = Person{
			transform = {
				pos_x = s.pos_x,
				pos_y = s.pos_y,
				size_w = s.size_w,
				size_h = s.size_h,
				base_y = s.pos_y,
				bound_min_x = s.bound_min_x,
				bound_max_x = s.bound_max_x,
				dir = 1,
			},
			motion = {
				state = .Idle,
				phase = .Active,
				timer = rand_float_range(0.5, 2.0),
			},
			traits = {
				age = age_from_u8(s.age),
				speed_scale = s.speed_scale,
				color = color_from_u32(s.color),
				draw_alpha = 1,
			},
			identity = {
				role = .Crowd,
				party_slot = -1,
			},
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
	t := p.rows[i].transform
	return {t.pos_x, t.pos_y, t.size_w, t.size_h}
}

draw_rect_outline :: proc(rect: rl.Rectangle, color: rl.Color) {
	rl.DrawRectangleLinesEx(rect, 1, color)
}

is_interactable :: proc(p: ^People, i: int) -> bool {
	row := p.rows[i]
	return row.identity.role == .Crowd &&
		row.motion.phase == .Active &&
		!row.food.served &&
		row.motion.state != .Celebrating &&
		row.behavior.subbehavior == .None
}

is_crowd_row :: proc(p: ^People, i: int) -> bool {
	return i >= 0 && i < p.crowd_count
}

package person

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import w "../world"

CROWD_SCENE_DEFAULT_COUNT :: 32
CROWD_SCENE_GROUND_Y_FRAC :: 0.9
TUTORIAL_CROWD_COUNT :: 10
TUTORIAL_APOSTLE_COUNT :: 3

CROWD_APOSTLE_THOMAS_MIN_ALPHA :: 0.3
CROWD_APOSTLE_FADE_SPEED :: 0.85
CROWD_APOSTLE_SPEECH_MIN :: 2.5
CROWD_APOSTLE_SPEECH_MAX :: 5.0
CROWD_APOSTLE_IDLE_MIN :: 1.0
CROWD_APOSTLE_IDLE_MAX :: 4.0
CROWD_APOSTLE_THOMAS_HOLD_MIN :: 2.0
CROWD_APOSTLE_THOMAS_HOLD_MAX :: 5.0

Crowd_Apostle_Thomas_Phase :: enum {
	Wait,
	Fade_Out,
	Hold,
	Fade_In,
}

Crowd_Apostle_Play :: struct {
	speech_timer:      f32,
	speech_show_reqs:  bool,
	idle_timer:        f32,
	thomas_phase:      Crowd_Apostle_Thomas_Phase,
	thomas_hold_timer: f32,
}

Crowd_Scene :: struct {
	ground:   ^w.Ground,
	people:   ^People,
	apostles: [APOSTLE_COUNT]Crowd_Apostle_Play,
}

Crowd_Scene_Config :: struct {
	seed:          u64,
	game_width:    f32,
	game_height:   f32,
	crowd_count:   int,
	apostle_count: int,
}

init_crowd_scene :: proc(cfg: Crowd_Scene_Config) -> ^Crowd_Scene {
	scene := new(Crowd_Scene)
	scene.ground = w.init_ground(cfg.game_width, cfg.game_height, CROWD_SCENE_GROUND_Y_FRAC)
	spawn := w.spawn_flat_crowd(
		cfg.game_width,
		scene.ground.top_y,
		cfg.crowd_count,
		cfg.seed,
	)
	scene.people = init_people(spawn, cfg.game_width, scene.ground.top_y)
	delete(spawn)
	spawn_apostles_lineup_center(
		scene.people,
		cfg.seed,
		cfg.game_width,
		scene.ground.top_y,
		cfg.apostle_count,
	)
	crowd_scene_seed_motion(scene.people)
	crowd_scene_seed_apostles(scene)
	return scene
}

free_crowd_scene :: proc(scene: ^Crowd_Scene) {
	if scene == nil {
		return
	}
	free_people(scene.people)
	free(scene.ground)
	free(scene)
}

crowd_scene_seed_apostles :: proc(scene: ^Crowd_Scene) {
	for a in 0 ..< APOSTLE_COUNT {
		scene.apostles[a].idle_timer = rand_float_range(0.5, CROWD_APOSTLE_IDLE_MAX)
		if a == THOMAS_APOSTLE_IDX {
			scene.apostles[a].thomas_phase = .Wait
		}
	}
}

crowd_scene_apostle_idle_delay :: proc() -> f32 {
	return rand_float_range(CROWD_APOSTLE_IDLE_MIN, CROWD_APOSTLE_IDLE_MAX)
}

crowd_scene_apostle_pick_action :: proc(scene: ^Crowd_Scene, person_i: int) {
	apostle_idx := int(scene.people.rows[person_i].identity.apostle_idx)
	if apostle_idx == THOMAS_APOSTLE_IDX {
		return
	}
	play := &scene.apostles[apostle_idx]
	roll := rand.int_max(100)
	switch {
	case roll < 40:
		begin_celebrating(scene.people, person_i)
	case roll < 75:
		play.speech_timer = rand_float_range(CROWD_APOSTLE_SPEECH_MIN, CROWD_APOSTLE_SPEECH_MAX)
		play.speech_show_reqs = rand.int_max(100) < 15
	case:
		play.idle_timer = crowd_scene_apostle_idle_delay()
	}
}

crowd_scene_apostle_finish_jump :: proc(scene: ^Crowd_Scene, person_i: int) {
	p := scene.people
	p.rows[person_i].transform.pos_y = p.rows[person_i].transform.base_y
	p.rows[person_i].motion.hop_step = 0
	p.rows[person_i].motion.state = .Idle
	apostle_idx := int(p.rows[person_i].identity.apostle_idx)
	scene.apostles[apostle_idx].idle_timer = crowd_scene_apostle_idle_delay()
}

crowd_scene_update_apostle_jump :: proc(scene: ^Crowd_Scene, person_i: int, dt: f32) {
	p := scene.people
	row := &p.rows[person_i]
	row.motion.hop_timer -= dt
	if row.motion.hop_timer <= 0 {
		row.motion.hop_step += 1
		if row.motion.hop_step >= row.motion.hop_count {
			crowd_scene_apostle_finish_jump(scene, person_i)
		} else {
			row.motion.hop_timer = CELEBRATE_HOP_DURATION
		}
	}
	if row.motion.hop_step < row.motion.hop_count {
		t := math.max(row.motion.hop_timer / CELEBRATE_HOP_DURATION, 0)
		row.transform.pos_y =
			row.transform.base_y - CELEBRATE_HOP_HEIGHT * math.abs(math.sin(t * math.PI))
	}
}

crowd_scene_update_thomas :: proc(scene: ^Crowd_Scene, person_i: int, dt: f32) {
	play := &scene.apostles[THOMAS_APOSTLE_IDX]
	row := &scene.people.rows[person_i]
	switch play.thomas_phase {
	case .Wait:
		play.idle_timer -= dt
		if play.idle_timer <= 0 {
			play.thomas_phase = .Fade_Out
		}
	case .Fade_Out:
		row.traits.draw_alpha -= CROWD_APOSTLE_FADE_SPEED * dt
		if row.traits.draw_alpha <= CROWD_APOSTLE_THOMAS_MIN_ALPHA {
			row.traits.draw_alpha = CROWD_APOSTLE_THOMAS_MIN_ALPHA
			play.thomas_phase = .Hold
			play.thomas_hold_timer = rand_float_range(
				CROWD_APOSTLE_THOMAS_HOLD_MIN,
				CROWD_APOSTLE_THOMAS_HOLD_MAX,
			)
		}
	case .Hold:
		play.thomas_hold_timer -= dt
		if play.thomas_hold_timer <= 0 {
			play.thomas_phase = .Fade_In
		}
	case .Fade_In:
		row.traits.draw_alpha += CROWD_APOSTLE_FADE_SPEED * dt
		if row.traits.draw_alpha >= 1 {
			row.traits.draw_alpha = 1
			play.thomas_phase = .Wait
			play.idle_timer = crowd_scene_apostle_idle_delay()
		}
	}
}

crowd_scene_update_apostle :: proc(scene: ^Crowd_Scene, person_i: int, dt: f32) {
	p := scene.people
	row := &p.rows[person_i]
	apostle_idx := int(row.identity.apostle_idx)
	play := &scene.apostles[apostle_idx]

	if apostle_idx == THOMAS_APOSTLE_IDX {
		crowd_scene_update_thomas(scene, person_i, dt)
		return
	}

	if play.speech_timer > 0 {
		play.speech_timer -= dt
	}

	switch row.motion.state {
	case .Celebrating:
		crowd_scene_update_apostle_jump(scene, person_i, dt)
		return
	case .Idle:
		if play.speech_timer > 0 {
			return
		}
		play.idle_timer -= dt
		if play.idle_timer <= 0 {
			crowd_scene_apostle_pick_action(scene, person_i)
		}
	case .Walking, .Running:
		row.motion.state = .Idle
		play.idle_timer = crowd_scene_apostle_idle_delay()
	}
}

crowd_scene_seed_motion :: proc(p: ^People) {
	for i in 0 ..< p.crowd_count {
		roll := rand.int_max(100)
		switch {
		case roll < 12:
			begin_celebrating(p, i)
		case roll < 55:
			pick_roam_from_idle(p, i)
		case:
			p.rows[i].motion.timer = pick_idle_duration(p.rows[i].traits.age)
		}
	}
}

crowd_scene_finish_celebrate :: proc(p: ^People, i: int) {
	p.rows[i].transform.pos_y = p.rows[i].transform.base_y
	p.rows[i].motion.hop_step = 0
	if rand.int_max(100) < 20 {
		begin_celebrating(p, i)
	} else {
		roam_to_idle(p, i)
	}
}

crowd_scene_update_person :: proc(p: ^People, i: int, dt: f32) {
	if i >= p.crowd_count {
		return
	}
	switch p.rows[i].motion.state {
	case .Celebrating:
		p.rows[i].motion.hop_timer -= dt
		if p.rows[i].motion.hop_timer <= 0 {
			p.rows[i].motion.hop_step += 1
			if p.rows[i].motion.hop_step >= p.rows[i].motion.hop_count {
				crowd_scene_finish_celebrate(p, i)
			} else {
				p.rows[i].motion.hop_timer = CELEBRATE_HOP_DURATION
			}
		}
		if p.rows[i].motion.hop_step < p.rows[i].motion.hop_count {
			t := math.max(p.rows[i].motion.hop_timer / CELEBRATE_HOP_DURATION, 0)
			p.rows[i].transform.pos_y =
				p.rows[i].transform.base_y - CELEBRATE_HOP_HEIGHT * math.abs(math.sin(t * math.PI))
		}
	case .Idle:
		p.rows[i].motion.timer -= dt
		if p.rows[i].motion.timer <= 0 {
			pick_roam_from_idle(p, i)
		}
	case .Walking, .Running:
		p.rows[i].motion.timer -= dt
		if p.rows[i].motion.timer <= 0 {
			roam_to_idle(p, i)
			return
		}
		speed := person_move_speed(p, i, p.rows[i].motion.state)
		p.rows[i].transform.pos_x += p.rows[i].transform.dir * speed * dt
		roam_after_step(p, i)
	}
}

update_crowd_scene :: proc(scene: ^Crowd_Scene, view: rl.Rectangle, frame: int, dt: f32) {
	if scene == nil || scene.people == nil {
		return
	}
	p := scene.people
	for i in 0 ..< p.crowd_count {
		pr := person_rect_at(p, i)
		visible := rl.CheckCollisionRecs(pr, view)
		always := p.rows[i].motion.state == .Celebrating
		if visible || always || (frame + i) % OFFSCREEN_UPDATE_INTERVAL == 0 {
			crowd_scene_update_person(p, i, dt)
		}
	}
	for i in p.crowd_count ..< len(p.rows) {
		crowd_scene_update_apostle(scene, i, dt)
	}
}

update_crowd_scene_lineup_apostles :: proc(scene: ^Crowd_Scene, dt: f32) {
	if scene == nil || scene.people == nil {
		return
	}
	p := scene.people
	for i in p.crowd_count ..< len(p.rows) {
		if p.rows[i].motion.phase == .Following {
			continue
		}
		crowd_scene_update_apostle(scene, i, dt)
	}
}

crowd_scene_apostle_hit :: proc(scene: ^Crowd_Scene, at: rl.Vector2) -> int {
	if scene == nil || scene.people == nil {
		return -1
	}
	return apostle_hit_index_at(scene.people, at)
}

draw_crowd_scene :: proc(scene: ^Crowd_Scene, view: rl.Rectangle, hovered_apostle: int) {
	if scene == nil {
		return
	}
	if scene.ground != nil {
		rl.DrawRectangleV(scene.ground.pos, scene.ground.size, rl.BROWN)
	}
	if scene.people == nil {
		return
	}
	draw_people(scene.people, view)
	p := scene.people
	for i in p.crowd_count ..< len(p.rows) {
		if hovered_apostle == i {
			continue
		}
		apostle_idx := int(p.rows[i].identity.apostle_idx)
		play := scene.apostles[apostle_idx]
		if play.speech_timer <= 0 {
			continue
		}
		draw_apostle_credits_speech_at(p, i, play.speech_show_reqs)
	}
	draw_apostle_credits_hover(scene.people, hovered_apostle)
}

package game

import rl "vendor:raylib"
import "../config"
import "../currency"
import "../input"
import "../person"
import "../player"

update_playing :: proc(g: ^Game) {
	if input.key_pressed(.P) {
		g.run.paused = !g.run.paused
	}
	person.tick_apostle_reject_speech(g.scene.people, g.scene.player.pos, g.scene.player.size)
	if g.run.paused {
		return
	}

	dt := rl.GetFrameTime()
	when config.IS_AUTOTEST {
		if g.autotest.autoplay {
			dt *= AUTOPLAY_SIM_SPEED
			autobot_tick(g)
		}
	}
	g.run.play_time += dt

	bonuses := person.party_bonuses(g.scene.people)
	mods := person.party_player_modifiers(bonuses)
	moved := player.update(g.scene.player, g.scene.ground, g.view.world_width, mods, dt)
	if moved > 0 {
		person.stat_add(&g.run.run_stats, .Distance_Walked, u32(moved))
	}

	update_camera(g)
	view := camera_view_rect(g)
	party_before := g.scene.people.party.count
	person.update_people(g.scene.people, view, g.frame, dt)
	when config.IS_DEBUG {
		g.scene.people.debug.apostle_perk_log = playing_debug_visible(g)
	}
	interact_radius := g.defs.interact_radius + bonuses.interact_radius_add
	perk_ctx := person.Apostle_Perk_Ctx {
		world = g.scene.level,
		player_pos = g.scene.player.pos,
		player_size = g.scene.player.size,
		player_facing = g.scene.player.facing,
		interact_radius = interact_radius,
		run_stats = &g.run.run_stats,
		coins = &g.run.coins,
	}
	person.update_apostle_follow(g.scene.people, perk_ctx, dt)
	currency.tick_drops(&g.run.dropped_coins, dt)
	if g.scene.people.party.count > party_before {
		person.sync_apostle_bits(g.scene.people, g.run.apostle_bits)
		bonuses = person.party_bonuses(g.scene.people)
		mods = person.party_player_modifiers(bonuses)
		interact_radius = g.defs.interact_radius + bonuses.interact_radius_add
	}

	fish_down := input.key_down(.F)
	bread_down := input.key_down(.B)
	e_down := input.key_down(.E)
	g.input.interact_index = person.nearest_interact_index(
		g.scene.people,
		g.scene.player.pos,
		g.scene.player.size,
		interact_radius,
	)
	g.input.apostle_interact_index = person.nearest_apostle_interact_index(
		g.scene.people,
		g.scene.player.pos,
		g.scene.player.size,
		interact_radius,
	)

	if fish_down && !g.input.fish_was_down {
		person.try_give_item(
			g.scene.people,
			g.scene.player.pos,
			g.scene.player.size,
			interact_radius,
			.Fish,
			&g.run.run_stats,
		)
	}
	if bread_down && !g.input.bread_was_down {
		person.try_give_item(
			g.scene.people,
			g.scene.player.pos,
			g.scene.player.size,
			interact_radius,
			.Bread,
			&g.run.run_stats,
		)
	}
	g.input.fish_was_down = fish_down
	g.input.bread_was_down = bread_down
	if e_down && !g.input.e_was_down {
		player_rect := rl.Rectangle{g.scene.player.pos.x, g.scene.player.pos.y, g.scene.player.size.x, g.scene.player.size.y}
		currency.try_pickup(&g.run.dropped_coins, player_rect, &g.run.coins)
		available := person.run_stats_available(g.run.run_stats, g.run.stats_pledged)
		person.try_interact_apostle(
			g.scene.people,
			g.scene.player.pos,
			g.scene.player.size,
			interact_radius,
			available,
			&g.run.stats_pledged,
		)
	}
	g.input.e_was_down = e_down

	when config.IS_DEBUG {
		if input.key_pressed(.M) {
			person.debug_serve_next(g.scene.people)
		}
		if input.key_pressed(.L) {
			person.debug_recruit_nearest_apostle(
				g.scene.people,
				g.scene.player.pos,
				g.scene.player.size,
				interact_radius,
			)
		}
		if playing_debug_visible(g) {
			person.apostle_debug_tick_input(g.scene.people)
		}
	}

	before := person.count_served(g.scene.people)
	person.sync_served_bits(g.scene.people, g.run.served_bits)
	after := person.count_served(g.scene.people)
	maybe_persist_on_chunk_change(g)
	if after >= g.run.person_count && g.run.person_count > 0 && person.sim_settled(g.scene.people) {
		begin_victory_march(g)
	}
}

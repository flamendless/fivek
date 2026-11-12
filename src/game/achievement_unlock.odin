package game

import "../achievements"
import "../person"

game_sync_achievements :: proc(g: ^Game) {
	if achievement_sync_from_career(&g.ach_state, g.career) > 0 {
		save_achievements(&g.ach_state)
	}
}

achievement_sync_from_career :: proc(state: ^achievements.State, career: person.Career_Stats) -> int {
	if state == nil {
		return 0
	}
	before := achievement_unlock_count(state^)
	achievement_sync_bit(state, .SmallActBigChange, career.post_celebrate_lineup > 0)
	achievement_sync_bit(state, .NotTheRejectedOne, career.post_celebrate_home > 0)
	achievement_sync_bit(state, .MoreHandsFeet, person.career_apostle_recruits_total(career) > 0)
	achievement_sync_bit(state, .WellDoneFaithful, career.runs_won > 0)
	achievement_sync_bit(state, .JourneyFiveThousand, career.lifetime.distance_walked >= 5000)
	achievement_sync_bit(state, .LoavesAndFishes, career.lifetime.total_served >= 500)
	achievement_sync_bit(state, .MothDothCorrupt, career.total_coins > 0)
	return achievement_unlock_count(state^) - before
}

@(private = "file")
achievement_sync_bit :: proc(state: ^achievements.State, id: achievements.Id, cond: bool) {
	if state == nil || !cond || achievements.is_unlocked(state^, id) {
		return
	}
	i := int(id)
	state.unlocked[i / 8] |= u8(1 << uint(i % 8))
}

@(private = "file")
achievement_unlock_count :: proc(s: achievements.State) -> int {
	n := 0
	for id in achievements.Id {
		if achievements.is_unlocked(s, id) {
			n += 1
		}
	}
	return n
}

achievement_check_after_career_commit :: proc(g: ^Game, won: bool) {
	c := &g.career
	if won {
		achievements.try_unlock(&g.ach_state, &g.achievement_pending, .WellDoneFaithful)
	}
	if c.lifetime.distance_walked >= 5000 {
		achievements.try_unlock(&g.ach_state, &g.achievement_pending, .JourneyFiveThousand)
	}
	if c.lifetime.total_served >= 500 {
		achievements.try_unlock(&g.ach_state, &g.achievement_pending, .LoavesAndFishes)
	}
}

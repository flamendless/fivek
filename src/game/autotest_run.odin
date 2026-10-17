#+build !js
package game

import "core:fmt"
import "core:os"
import "core:strconv"
import "../config"

when config.IS_AUTOTEST {

AUTOTEST_POPULATION :: 8
AUTOTEST_SEED :: 12345
FRAMES_PER_PERSON :: 15_000

run_autotest :: proc() -> int {
	defs := get_defs()
	defs.target_population = AUTOTEST_POPULATION

	g := init(defs)

	seed: u64 = AUTOTEST_SEED
	if len(os.args) > 1 {
		if v, ok := strconv.parse_u64(os.args[1]); ok {
			seed = v
		}
	}
	g.seed = seed
	g.seed_len = write_seed_text(g.seed, &g.seed_text)
	g.autoplay = true
	g.autoplay_max_frames = AUTOTEST_POPULATION * FRAMES_PER_PERSON
	g.autobot_target = -1
	g.save_path = "save_autotest.bin"

	init_window(g)

	start_run(g, false)

	ok := loop_until_credits(g)
	served := served_count(g)
	total := person_count(g)
	frames := run_frame(g)
	seed_out := g.seed
	done := g.autoplay_done
	failed := g.autoplay_failed

	close_window()
	close(g)

	if ok && done && served >= total {
		fmt.printf("PASS seed=%d served=%d/%d frames=%d\n", seed_out, served, total, frames)
		return 0
	}

	fmt.printf(
		"FAIL seed=%d served=%d/%d frames=%d timeout=%v\n",
		seed_out,
		served,
		total,
		frames,
		failed,
	)
	return 1
}

}

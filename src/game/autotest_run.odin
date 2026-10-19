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
	g.seed.value = seed
	g.seed.len = write_seed_text(g.seed.value, &g.seed.text)
	g.autotest.autoplay = true
	g.autotest.autoplay_max_frames = AUTOTEST_POPULATION * FRAMES_PER_PERSON
	g.autotest.autobot_target = -1
	g.persist.save_path = "save_autotest.bin"

	init_window(g)

	start_run(g, false)

	ok := loop_until_credits(g)
	served := served_count(g)
	total := person_count(g)
	frames := run_frame(g)
	seed_out := g.seed.value
	done := g.autotest.autoplay_done
	failed := g.autotest.autoplay_failed

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

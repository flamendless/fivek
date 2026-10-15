package game

import "../config"

when !config.IS_AUTOTEST {
	autobot_tick :: proc(g: ^Game) {
		_ = g
	}
}

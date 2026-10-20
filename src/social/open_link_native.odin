#+build !js
package social

import rl "vendor:raylib"

open_link :: proc(url: cstring) {
	rl.OpenURL(url)
}

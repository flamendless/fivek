#+build !js
package game

import "core:os"

exit_autotest :: proc(code: int) {
	os.exit(code)
}

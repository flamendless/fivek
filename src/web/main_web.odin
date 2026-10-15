package web

import "base:runtime"
import "core:mem"
import "../game"

main :: proc() {}

@(private = "file")
web_context: runtime.Context

@export
main_start :: proc "c" () {
	context = runtime.default_context()
	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1 * mem.Megabyte)
	context.logger = create_emscripten_logger()
	web_context = context
	game.web_start()
}

@export
main_update :: proc "c" () -> bool {
	context = web_context
	return game.web_update()
}

@export
main_end :: proc "c" () {
	context = web_context
	game.web_end()
}

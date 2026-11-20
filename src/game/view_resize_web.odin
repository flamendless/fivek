#+build js
package game

foreign import "env"

@(default_calling_convention = "c")
foreign env {
	web_viewport_set_fullscreen :: proc(enabled: bool) ---
	web_viewport_size :: proc(out_w, out_h: ^i32) ---
	web_viewport_is_fullscreen :: proc() -> bool ---
	web_set_system_cursor_visible :: proc(visible: bool) ---
}
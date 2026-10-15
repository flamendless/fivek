package game

ui_px :: proc(g: ^Game, design: f32) -> i32 {
	return i32(design * g.ui_scale + 0.5)
}

ui_font :: proc(g: ^Game, design: i32) -> i32 {
	size := i32(f32(design) * g.ui_scale + 0.5)
	if size < 8 {
		return 8
	}
	return size
}

package ui

import "../assets"
import rl "vendor:raylib"

texture :: proc(t: assets.UI_Texture) -> rl.Texture2D {
	return assets.texture(t)
}

draw_texture_icon :: proc(tex: rl.Texture2D, center: rl.Vector2, size: f32 = 0) {
	draw_size := size > 0 ? size : assets.ui_layout().icon_draw_size
	if tex.id == 0 {
		return
	}
	half := draw_size * 0.5
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - half, center.y - half, draw_size, draw_size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

draw_general_icon :: proc(frame: int, center: rl.Vector2, size: f32 = 0) {
	layout := assets.ui_layout()
	draw_size := size > 0 ? size : layout.general_frame_size
	tex := assets.texture(.General)
	if tex.id == 0 {
		return
	}
	half := draw_size * 0.5
	frame_size := layout.general_frame_size
	src_x := f32(frame) * frame_size
	src := rl.Rectangle{src_x, 0, frame_size, frame_size}
	dest := rl.Rectangle{center.x - half, center.y - half, draw_size, draw_size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

hourglass_draw_width :: proc(height: f32 = 0) -> f32 {
	layout := assets.ui_layout()
	draw_h := height > 0 ? height : layout.hourglass_draw_height
	tex := assets.texture(.Hourglass)
	if tex.id == 0 || tex.height == 0 {
		return draw_h
	}
	return draw_h * f32(tex.width) / f32(tex.height)
}

draw_hourglass_icon :: proc(center: rl.Vector2, height: f32 = 0) {
	layout := assets.ui_layout()
	draw_h := height > 0 ? height : layout.hourglass_draw_height
	tex := assets.texture(.Hourglass)
	if tex.id == 0 {
		return
	}
	draw_w := hourglass_draw_width(draw_h)
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - draw_w * 0.5, center.y - draw_h * 0.5, draw_w, draw_h}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

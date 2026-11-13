package ui

import "../assets"
import rl "vendor:raylib"

Npatch_Margins :: struct {
	left, top, right, bottom: i32,
}

// 10px on 48px² 2x wood — center starts at y=10 (tan); 8px showed a stretched cream seam.
NPATCH_PANEL :: Npatch_Margins{10, 10, 10, 10}
COZY_INNER_PAD :: f32(2)
NPATCH_BUTTON :: Npatch_Margins{8, 8, 8, 10}
NPATCH_BAR_FRAME :: Npatch_Margins{6, 6, 6, 6}
NPATCH_BAR_FILL :: Npatch_Margins{2, 2, 2, 2}
NPATCH_DIALOG :: Npatch_Margins{8, 8, 8, 8}

cozy_content_pad :: proc(extra_pad: f32) -> f32 {
	if extra_pad > 0 {
		return extra_pad
	}
	return COZY_INNER_PAD
}

draw_npatch :: proc(tex: rl.Texture2D, m: Npatch_Margins, dest: rl.Rectangle, tint: rl.Color) {
	if tex.id == 0 {
		return
	}
	source := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	info := rl.NPatchInfo {
		source = source,
		left   = m.left,
		top    = m.top,
		right  = m.right,
		bottom = m.bottom,
		layout = .NINE_PATCH,
	}
	rl.DrawTextureNPatch(tex, info, dest, {}, 0, tint)
}

@(private = "file")
frame_content_rect :: proc(dest: rl.Rectangle, m: Npatch_Margins, extra_pad: f32) -> rl.Rectangle {
	pad := cozy_content_pad(extra_pad)
	il := f32(m.left)
	ir := f32(m.right)
	it := f32(m.top)
	ib := f32(m.bottom)
	return {
		dest.x + il + pad,
		dest.y + it + pad,
		max(dest.width - il - ir - pad * 2, 0),
		max(dest.height - it - ib - pad * 2, 0),
	}
}

@(private = "file")
outer_size_for_inner :: proc(inner_w, inner_h: f32, m: Npatch_Margins, extra_pad: f32) -> rl.Vector2 {
	pad := cozy_content_pad(extra_pad)
	bw := f32(m.left + m.right)
	bh := f32(m.top + m.bottom)
	return {inner_w + bw + pad * 2, inner_h + bh + pad * 2}
}

wood_panel_content :: proc(dest: rl.Rectangle, extra_pad: f32) -> rl.Rectangle {
	return frame_content_rect(dest, NPATCH_PANEL, extra_pad)
}

@(private = "file")
npatch_inner_size_ratio :: proc(tex: rl.Texture2D, m: Npatch_Margins) -> (w_ratio, h_ratio: f32) {
	if tex.id == 0 || tex.width == 0 || tex.height == 0 {
		return 0.5, 0.5
	}
	tw := f32(tex.width)
	th := f32(tex.height)
	w_ratio = 1 - f32(m.left + m.right) / tw
	h_ratio = 1 - f32(m.top + m.bottom) / th
	return max(w_ratio, 0.25), max(h_ratio, 0.25)
}

// Outer panel size so wood_panel_content(dest, extra_pad) fits text_w x text_h.
wood_panel_outer_size :: proc(text_w, text_h, extra_pad: f32) -> rl.Vector2 {
	pad := cozy_content_pad(extra_pad)
	return {
		wood_panel_width_for_inner(text_w, pad),
		wood_panel_height_for_inner(text_h, pad),
	}
}

wood_panel_height_for_inner :: proc(inner_h, extra_pad: f32) -> f32 {
	return outer_size_for_inner(0, inner_h, NPATCH_PANEL, extra_pad).y
}

wood_panel_width_for_inner :: proc(inner_w, extra_pad: f32) -> f32 {
	return outer_size_for_inner(inner_w, 0, NPATCH_PANEL, extra_pad).x
}

parchment_height_for_inner :: proc(inner_h, extra_pad: f32) -> f32 {
	return outer_size_for_inner(0, inner_h, NPATCH_DIALOG, extra_pad).y
}

parchment_width_for_inner :: proc(inner_w, extra_pad: f32) -> f32 {
	return outer_size_for_inner(inner_w, 0, NPATCH_DIALOG, extra_pad).x
}

parchment_content :: proc(dest: rl.Rectangle, extra_pad: f32) -> rl.Rectangle {
	return frame_content_rect(dest, NPATCH_DIALOG, extra_pad)
}

npatch_inner_dest :: proc(dest: rl.Rectangle, tex: rl.Texture2D, m: Npatch_Margins) -> rl.Rectangle {
	if tex.id == 0 || tex.width == 0 || tex.height == 0 {
		return dest
	}
	tw := f32(tex.width)
	th := f32(tex.height)
	il := dest.width * f32(m.left) / tw
	ir := dest.width * f32(m.right) / tw
	it := dest.height * f32(m.top) / th
	ib := dest.height * f32(m.bottom) / th
	return {
		dest.x + il,
		dest.y + it,
		dest.width - il - ir,
		max(dest.height - it - ib, 0),
	}
}

draw_wood_panel :: proc(dest: rl.Rectangle, tint: rl.Color = rl.WHITE) {
	draw_npatch(assets.cozy_panel_wood(), NPATCH_PANEL, dest, tint)
}

draw_parchment_dialog :: proc(dest: rl.Rectangle, tint: rl.Color = rl.WHITE) {
	draw_npatch(assets.cozy_dialog_parchment(), NPATCH_DIALOG, dest, tint)
}

draw_wood_button :: proc(state: assets.Cozy_Button, dest: rl.Rectangle, tint: rl.Color = rl.WHITE) {
	draw_npatch(assets.cozy_button(state), NPATCH_BUTTON, dest, tint)
}

draw_stamina_bar :: proc(dest: rl.Rectangle, ratio: f32, fill_tint: rl.Color) {
	frame_tex := assets.cozy_bar_frame()
	fill_tex := assets.cozy_bar_fill_health()
	draw_npatch(frame_tex, NPATCH_BAR_FRAME, dest, rl.WHITE)
	if ratio <= 0 {
		return
	}
	inner := npatch_inner_dest(dest, frame_tex, NPATCH_BAR_FRAME)
	if inner.width <= 0 || inner.height <= 0 {
		return
	}
	clamped := clamp(ratio, 0, 1)
	fill_dest := inner
	fill_dest.width = inner.width * clamped
	if fill_dest.width <= 0 {
		return
	}
	draw_npatch(fill_tex, NPATCH_BAR_FILL, fill_dest, fill_tint)
}

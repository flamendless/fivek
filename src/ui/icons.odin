package ui

import "core:log"
import rl "vendor:raylib"

UI_ICON_DRAW_SIZE: f32 : 16
GENERAL_ICON_FRAME_SIZE: f32 : 16
HOURGLASS_DRAW_HEIGHT: f32 : 22

UI_Texture :: enum {
	People,
	Sandals,
	General,
	Hourglass,
}

UI_TEXTURE_PATHS: [UI_Texture]cstring = {
	.People    = "assets/ui/people.png",
	.Sandals   = "assets/ui/sandals.png",
	.General   = "assets/ui/general.png",
	.Hourglass = "assets/ui/hourglass.png",
}

ui_tex: [UI_Texture]rl.Texture2D

texture :: proc(t: UI_Texture) -> rl.Texture2D {
	return ui_tex[t]
}

load_texture_slot :: proc(slot: ^rl.Texture2D, path: cstring) {
	if slot.id != 0 {
		return
	}
	log.infof("loading ui texture %s", path)
	tex := rl.LoadTexture(path)
	if tex.id != 0 {
		rl.SetTextureFilter(tex, .POINT)
		slot^ = tex
	} else {
		log.warnf("failed to load ui texture %s", path)
	}
}

ready :: proc() -> bool {
	for t in ui_tex {
		if t.id == 0 {
			return false
		}
	}
	return true
}

load :: proc() {
	if ready() {
		return
	}
	for key in UI_Texture {
		load_texture_slot(&ui_tex[key], UI_TEXTURE_PATHS[key])
	}
}

unload :: proc() {
	for key in UI_Texture {
		if ui_tex[key].id != 0 {
			log.infof("unloading ui texture %s", UI_TEXTURE_PATHS[key])
			rl.UnloadTexture(ui_tex[key])
			ui_tex[key] = {}
		}
	}
}

draw_texture_icon :: proc(tex: rl.Texture2D, center: rl.Vector2, size: f32 = UI_ICON_DRAW_SIZE) {
	if tex.id == 0 {
		return
	}
	half := size * 0.5
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - half, center.y - half, size, size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

draw_general_icon :: proc(frame: int, center: rl.Vector2, size: f32 = GENERAL_ICON_FRAME_SIZE) {
	tex := ui_tex[.General]
	if tex.id == 0 {
		return
	}
	half := size * 0.5
	src_x := f32(frame) * GENERAL_ICON_FRAME_SIZE
	src := rl.Rectangle{src_x, 0, GENERAL_ICON_FRAME_SIZE, GENERAL_ICON_FRAME_SIZE}
	dest := rl.Rectangle{center.x - half, center.y - half, size, size}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

hourglass_draw_width :: proc(height: f32 = HOURGLASS_DRAW_HEIGHT) -> f32 {
	tex := ui_tex[.Hourglass]
	if tex.id == 0 || tex.height == 0 {
		return height
	}
	return height * f32(tex.width) / f32(tex.height)
}

draw_hourglass_icon :: proc(center: rl.Vector2, height: f32 = HOURGLASS_DRAW_HEIGHT) {
	tex := ui_tex[.Hourglass]
	if tex.id == 0 {
		return
	}
	draw_w := hourglass_draw_width(height)
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dest := rl.Rectangle{center.x - draw_w * 0.5, center.y - height * 0.5, draw_w, height}
	rl.DrawTexturePro(tex, src, dest, {}, 0, rl.WHITE)
}

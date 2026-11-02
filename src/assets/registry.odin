package assets

import rl "vendor:raylib"

UI_Texture :: enum {
	People,
	Sandals,
	General,
	Hourglass,
}

Atlas :: enum {
	Fish,
	Bread,
	Social,
}

texture :: proc(t: UI_Texture) -> rl.Texture2D {
	return peek_texture(UI_TEXTURE_PATHS[t])
}

coin :: proc(index: int) -> rl.Texture2D {
	if index < 0 || index >= COIN_ICON_COUNT {
		return {}
	}
	return peek_texture(COIN_PATHS[index])
}

atlas :: proc(a: Atlas) -> rl.Texture2D {
	switch a {
	case .Fish:
		return peek_texture(FISH_ATLAS_PATH)
	case .Bread:
		return peek_texture(BREAD_ATLAS_PATH)
	case .Social:
		return peek_texture(SOCIAL_ATLAS_PATH)
	}
	return {}
}

boot_splash :: proc() -> rl.Texture2D {
	return peek_texture(SPLASH_LOGO_PATH)
}

boot_title_font :: proc() -> rl.Font {
	return peek_font(TITLE_FONT_PATH)
}

atlas_src_rect :: proc(index: int, grid: Grid_Atlas) -> rl.Rectangle {
	col := index % grid.cols
	row := index / grid.cols
	return {f32(col) * grid.cell, f32(row) * grid.cell, grid.cell, grid.cell}
}

social_atlas_src :: proc(atlas_index: int) -> rl.Rectangle {
	grid := social_grid()
	i := atlas_index - 1
	col := i % grid.cols
	row := i / grid.cols
	return {
		f32(col) * grid.cell,
		f32(row) * grid.cell,
		grid.cell,
		grid.cell,
	}
}

gameplay_ready :: proc() -> bool {
	if atlas(.Fish).id == 0 || atlas(.Bread).id == 0 {
		return false
	}
	for t in UI_Texture {
		if texture(t).id == 0 {
			return false
		}
	}
	for i in 0 ..< COIN_ICON_COUNT {
		if coin(i).id == 0 {
			return false
		}
	}
	return true
}

boot_ready :: proc() -> bool {
	if boot_splash().id == 0 {
		return false
	}
	if boot_title_font().texture.id == 0 {
		return false
	}
	if atlas(.Social).id == 0 {
		return false
	}
	return true
}

package assets

import rl "vendor:raylib"

COZY_PANEL_WOOD_PATH :: "assets/ui/cozyuikit/2x/panels/panel_wood.png"
COZY_DIALOG_PARCHMENT_PATH :: "assets/ui/cozyuikit/2x/dialogs/dialog_parchment.png"
COZY_BAR_FRAME_PATH :: "assets/ui/cozyuikit/2x/bars/bar_frame_wood.png"
COZY_BAR_FILL_HEALTH_PATH :: "assets/ui/cozyuikit/2x/bars/bar_fill_health.png"

Cozy_Button :: enum {
	Normal,
	Hover,
	Pressed,
	Disabled,
}

COZY_BUTTON_PATHS: [Cozy_Button]cstring = {
	.Normal   = "assets/ui/cozyuikit/2x/buttons/button_wood_normal.png",
	.Hover    = "assets/ui/cozyuikit/2x/buttons/button_wood_hover.png",
	.Pressed  = "assets/ui/cozyuikit/2x/buttons/button_wood_pressed.png",
	.Disabled = "assets/ui/cozyuikit/2x/buttons/button_wood_disabled.png",
}

cozy_panel_wood :: proc() -> rl.Texture2D {
	return peek_texture(COZY_PANEL_WOOD_PATH)
}

cozy_dialog_parchment :: proc() -> rl.Texture2D {
	return peek_texture(COZY_DIALOG_PARCHMENT_PATH)
}

cozy_bar_frame :: proc() -> rl.Texture2D {
	return peek_texture(COZY_BAR_FRAME_PATH)
}

cozy_bar_fill_health :: proc() -> rl.Texture2D {
	return peek_texture(COZY_BAR_FILL_HEALTH_PATH)
}

cozy_button :: proc(state: Cozy_Button) -> rl.Texture2D {
	return peek_texture(COZY_BUTTON_PATHS[state])
}

COZY_PATHS: []cstring = {
	COZY_PANEL_WOOD_PATH,
	COZY_DIALOG_PARCHMENT_PATH,
	COZY_BAR_FRAME_PATH,
	COZY_BAR_FILL_HEALTH_PATH,
}

load_cozy_textures :: proc() -> bool {
	ok := true
	for path in COZY_PATHS {
		_, tex_ok := acquire_texture(path, OPT_POINT_CLAMP)
		ok = ok && tex_ok
	}
	for path in COZY_BUTTON_PATHS {
		_, tex_ok := acquire_texture(path, OPT_POINT_CLAMP)
		ok = ok && tex_ok
	}
	return ok
}

release_cozy_textures :: proc() {
	for path in COZY_PATHS {
		release_texture(path)
	}
	for path in COZY_BUTTON_PATHS {
		release_texture(path)
	}
}

cozy_ui_ready :: proc() -> bool {
	if cozy_panel_wood().id == 0 {
		return false
	}
	for path in COZY_BUTTON_PATHS {
		if peek_texture(path).id == 0 {
			return false
		}
	}
	if cozy_bar_frame().id == 0 || cozy_bar_fill_health().id == 0 {
		return false
	}
	if cozy_dialog_parchment().id == 0 {
		return false
	}
	return true
}

package assets

Grid_Atlas :: struct {
	cell:        f32,
	cols:        int,
	icon_count:  int,
}

Social_Grid :: struct {
	cell: f32,
	cols: int,
}

UI_Layout :: struct {
	icon_draw_size:       f32,
	general_frame_size:   f32,
	hourglass_draw_height: f32,
}

Coin_Layout :: struct {
	icon_count:     int,
	icon_draw_size: f32,
	hud_icon_index: int,
}

FISH_GRID :: Grid_Atlas{cell = 16, cols = 6, icon_count = 30}
BREAD_GRID :: Grid_Atlas{cell = 32, cols = 8, icon_count = 32}
SOCIAL_GRID :: Social_Grid{cell = 32, cols = 11}

UI_LAYOUT :: UI_Layout {
	icon_draw_size        = 16,
	general_frame_size    = 16,
	hourglass_draw_height = 22,
}

COIN_LAYOUT :: Coin_Layout {
	icon_count     = 8,
	icon_draw_size = 16,
	hud_icon_index = 0,
}

FOOD_ICON_DRAW_SIZE: f32 : 16

fish_grid :: proc() -> Grid_Atlas {
	return FISH_GRID
}

bread_grid :: proc() -> Grid_Atlas {
	return BREAD_GRID
}

social_grid :: proc() -> Social_Grid {
	return SOCIAL_GRID
}

ui_layout :: proc() -> UI_Layout {
	return UI_LAYOUT
}

coin_layout :: proc() -> Coin_Layout {
	return COIN_LAYOUT
}

food_icon_draw_size :: proc() -> f32 {
	return FOOD_ICON_DRAW_SIZE
}

COIN_ICON_COUNT :: COIN_LAYOUT.icon_count
HUD_COIN_ICON :: COIN_LAYOUT.hud_icon_index

package game

import rl "vendor:raylib"
import "../assets"
import "../currency"
import "../food"
import "../person"
import ui_assets "../ui"

UI_Row_Icon :: enum {
	People,
	Sandals,
	Fish,
	Bread,
	Coin,
	Hourglass,
	General_Play,
}

row_icon_layout_width :: proc(icon: UI_Row_Icon, nominal_size: f32) -> f32 {
	switch icon {
	case .Hourglass:
		return ui_assets.hourglass_draw_width(nominal_size)
	case .People, .Sandals, .Fish, .Bread, .Coin, .General_Play:
		return nominal_size
	}
	return nominal_size
}

draw_row_icon :: proc(icon: UI_Row_Icon, center: rl.Vector2, size: f32) {
	fish := assets.fish_grid()
	bread := assets.bread_grid()
	switch icon {
	case .People:
		ui_assets.draw_texture_icon(ui_assets.texture(.People), center, size)
	case .Sandals:
		ui_assets.draw_texture_icon(ui_assets.texture(.Sandals), center, size)
	case .Fish:
		food.draw_icon(
			assets.atlas(.Fish),
			person.STAT_BUBBLE_ICON_INDEX,
			fish.cell,
			fish.cols,
			center,
			size,
		)
	case .Bread:
		food.draw_icon(
			assets.atlas(.Bread),
			person.STAT_BUBBLE_ICON_INDEX,
			bread.cell,
			bread.cols,
			center,
			size,
		)
	case .Coin:
		currency.draw_coin_icon_sized(assets.HUD_COIN_ICON, center, size)
	case .Hourglass:
		ui_assets.draw_hourglass_icon(center, size)
	case .General_Play:
		ui_assets.draw_general_icon(0, center, size)
	}
}

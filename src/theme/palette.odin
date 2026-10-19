package theme

import "core:math/rand"
import rl "vendor:raylib"

Pattern_Bg :: enum {
	Cream_Paper,
	Warm_Sand,
	Cool_Mist,
	Warm_Stone,
	Soft_Sage,
	Light_Peach,
}

PATTERN_BG_COLORS: [Pattern_Bg]rl.Color = {
	.Cream_Paper = {236, 228, 210, 255},
	.Warm_Sand   = {245, 235, 215, 255},
	.Cool_Mist   = {220, 228, 235, 255},
	.Warm_Stone  = {228, 222, 214, 255},
	.Soft_Sage   = {224, 232, 218, 255},
	.Light_Peach = {245, 228, 218, 255},
}

PATTERN_DARK_BG :: rl.Color{32, 28, 24, 255}

TEXT_INK :: rl.Color{0, 0, 0, 255}

OVERLAY_SCRIM_140 :: rl.Color{0, 0, 0, 140}
OVERLAY_SCRIM_150 :: rl.Color{0, 0, 0, 150}
OVERLAY_SCRIM_160 :: rl.Color{0, 0, 0, 160}
OVERLAY_SCRIM_180 :: rl.Color{0, 0, 0, 180}

BUBBLE_FILL :: rl.Color{255, 255, 255, 230}
BUBBLE_BORDER :: rl.Color{40, 40, 40, 255}

BAR_TRACK :: rl.Color{40, 40, 40, 200}

REQ_MET :: rl.Color{60, 180, 70, 255}
REQ_SHORT :: rl.Color{220, 60, 60, 255}

DEBUG_CYAN :: rl.Color{100, 220, 255, 255}
DEBUG_CYAN_BRIGHT :: rl.Color{120, 220, 255, 255}
DEBUG_GREEN :: rl.Color{180, 255, 180, 255}
PARTY_BONUS_GREEN :: rl.Color{140, 220, 160, 255}

CHUNK_OUTLINE :: rl.Color{0, 220, 255, 220}
CHUNK_OUTLINE_ACTIVE :: rl.Color{255, 200, 64, 220}

SOCIAL_ICON_HOVER :: rl.Color{255, 140, 140, 255}

APOSTLE_IDENTITY_COLORS: [12]rl.Color = {
	{220, 60, 60, 255},
	{230, 120, 50, 255},
	{230, 190, 40, 255},
	{180, 210, 50, 255},
	{80, 180, 70, 255},
	{50, 170, 150, 255},
	{60, 190, 220, 255},
	{70, 110, 220, 255},
	{90, 80, 200, 255},
	{150, 80, 200, 255},
	{200, 70, 180, 255},
	{140, 30, 40, 255},
}

pattern_bg_color :: proc(which: Pattern_Bg) -> rl.Color {
	return PATTERN_BG_COLORS[which]
}

random_pattern_bg_color :: proc() -> rl.Color {
	return PATTERN_BG_COLORS[Pattern_Bg(rand.int_max(int(Pattern_Bg.Light_Peach) + 1))]
}

color_alpha :: proc(c: rl.Color, a: u8) -> rl.Color {
	return {c.r, c.g, c.b, a}
}

white_alpha :: proc(a: u8) -> rl.Color {
	return {255, 255, 255, a}
}

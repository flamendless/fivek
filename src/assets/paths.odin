package assets

SPLASH_LOGO_PATH :: "assets/flamendless_logo.png"
TITLE_FONT_PATH :: "assets/fonts/sholom/Sholom-Yz3J4.ttf"

FISH_ATLAS_PATH :: "assets/fishes/fishes.png"
BREAD_ATLAS_PATH :: "assets/breads/breads.png"
SOCIAL_ATLAS_PATH :: "assets/social/atlas.png"

COIN_PATHS: [COIN_ICON_COUNT]cstring = {
	"assets/coins/1.png",
	"assets/coins/2.png",
	"assets/coins/3.png",
	"assets/coins/4.png",
	"assets/coins/5.png",
	"assets/coins/6.png",
	"assets/coins/7.png",
	"assets/coins/8.png",
}

UI_TEXTURE_PATHS: [UI_Texture]cstring = {
	.People     = "assets/ui/people.png",
	.Sandals    = "assets/ui/sandals.png",
	.General    = "assets/ui/general.png",
	.Hourglass  = "assets/ui/hourglass.png",
	.Head_Kid   = "assets/ui/head_kid.png",
	.Head_Young = "assets/ui/head_young.png",
	.Head_Adult = "assets/ui/head_adult.png",
}

PATTERN_PATH_FMT :: "assets/patterns/%s/%s_%02d.png"

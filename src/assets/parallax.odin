package assets

Parallax_Set :: struct {
	name:   cstring,
	layers: []cstring,
}

PARALLAX_SETS := []Parallax_Set{
	{
		name = "nature_1",
		layers = {
			"assets/bg/nature_1/1.png",
			"assets/bg/nature_1/2.png",
			"assets/bg/nature_1/3.png",
			"assets/bg/nature_1/5.png",
			"assets/bg/nature_1/6.png",
			"assets/bg/nature_1/7.png",
			"assets/bg/nature_1/8.png",
		},
	},
	{
		name = "nature_2",
		layers = {
			"assets/bg/nature_2/1.png",
			"assets/bg/nature_2/2.png",
			"assets/bg/nature_2/3.png",
			"assets/bg/nature_2/4.png",
		},
	},
	{
		name = "nature_3",
		layers = {
			"assets/bg/nature_3/1.png",
			"assets/bg/nature_3/2.png",
			"assets/bg/nature_3/3.png",
			"assets/bg/nature_3/4.png",
		},
	},
	{
		name = "nature_4",
		layers = {
			"assets/bg/nature_4/1.png",
			"assets/bg/nature_4/2.png",
			"assets/bg/nature_4/3.png",
			"assets/bg/nature_4/4.png",
		},
	},
	{
		name = "nature_5",
		layers = {
			"assets/bg/nature_5/1.png",
			"assets/bg/nature_5/2.png",
			"assets/bg/nature_5/3.png",
			"assets/bg/nature_5/4.png",
			"assets/bg/nature_5/5.png",
		},
	},
}

parallax_set_count :: proc() -> int {
	return len(PARALLAX_SETS)
}

parallax_set :: proc(i: int) -> Parallax_Set {
	return PARALLAX_SETS[i]
}

pick_parallax_set :: proc(seed: u64) -> Parallax_Set {
	if len(PARALLAX_SETS) == 0 {
		return {}
	}
	return PARALLAX_SETS[int(seed % u64(len(PARALLAX_SETS)))]
}

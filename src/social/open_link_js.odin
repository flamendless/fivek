#+build js
package social

@(default_calling_convention = "c")
foreign "env" {
	fivek_open_url :: proc(url: cstring) ---
}

open_link :: proc(url: cstring) {
	fivek_open_url(url)
}

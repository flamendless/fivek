#+build js
package game

@(private = "file")
intro_seen_session: bool

@(private = "file")
tutorial_seen_session: bool

load_intro_seen :: proc() -> bool {
	return intro_seen_session
}

save_intro_seen :: proc() {
	intro_seen_session = true
}

load_tutorial_seen :: proc() -> bool {
	return tutorial_seen_session
}

save_tutorial_seen :: proc() {
	tutorial_seen_session = true
}

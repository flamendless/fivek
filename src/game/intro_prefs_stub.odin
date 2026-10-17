#+build js
package game

@(private = "file")
intro_seen_session: bool

load_intro_seen :: proc() -> bool {
	return intro_seen_session
}

save_intro_seen :: proc() {
	intro_seen_session = true
}

package game

delete_run_save :: proc(path: string) -> bool {
	when ODIN_OS == .JS {
		return delete_run_save_web(path)
	} else {
		return delete_run_save_file(path)
	}
}

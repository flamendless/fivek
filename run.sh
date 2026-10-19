#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OUT_GAME="${ROOT}/fivek"
OUT_AUTOTEST="${ROOT}/fivek_autotest"
WEB_DIR="${ROOT}/web"
OUT_WASM_OBJ="${WEB_DIR}/game.wasm.o"
INDEX_SHELL="${WEB_DIR}/index_shell.html"
FIVEK_STORAGE_JS="${WEB_DIR}/fivek_storage.js"
WEB_SAVE_KEY="fivek:save_fivek.bin"

usage() {
	cat <<'EOF'
Usage: ./run.sh <command> [args...]

Commands:
	run          Build and run the game (STATE=splash|disclaimer|title|play to skip intro flow)
	autotest     Build and run headless autoplay test
	build        Build native game binary only
	check        Type-check game and autotest entrypoints
	wasm         Build WebAssembly for the browser (needs emcc)
	wasm-deps    Install wasm toolchain (lld, emsdk, raylib wasm libs)
	wasm-run     Build wasm and serve web/
	clear-save   Remove native save files; hint for clearing browser save
EOF
}

clear_save() {
	local removed=0
	for f in save_fivek.bin save_autotest.bin; do
		if [[ -f "${ROOT}/${f}" ]]; then
			rm -f "${ROOT}/${f}"
			echo "removed ${f}"
			removed=1
		fi
	done
	[[ "${removed}" -eq 1 ]] || echo "no native save files found"
	echo "wasm: open your dev server with ?clearSave=1 (clears localStorage ${WEB_SAVE_KEY})"
}

build_game() {
	odin build src/main.odin -file -out:"${OUT_GAME}" "$@"
}

build_autotest() {
	odin build src/main.odin -file -out:"${OUT_AUTOTEST}" -define:AUTOTEST=true -define:DEBUG=true
}

ensure_wasm_ld() {
	if command -v wasm-ld >/dev/null 2>&1; then
		return 0
	fi
	local prefix
	for prefix in "$(brew --prefix lld@22 2>/dev/null)" "$(brew --prefix lld 2>/dev/null)"; do
		if [[ -n "${prefix}" && -x "${prefix}/bin/wasm-ld" ]]; then
			export PATH="${prefix}/bin:${PATH}"
			return 0
		fi
	done
	echo "wasm: wasm-ld not found (brew install lld@22)" >&2
	return 1
}

ensure_emcc() {
	if command -v emcc >/dev/null 2>&1; then
		return 0
	fi
	local emsdk="${EMSCRIPTEN_SDK_DIR:-$HOME/repos/emsdk}"
	if [[ -f "${emsdk}/emsdk_env.sh" ]]; then
		# shellcheck disable=SC1090
		source "${emsdk}/emsdk_env.sh"
	fi
	if command -v emcc >/dev/null 2>&1; then
		return 0
	fi
	echo "wasm: emcc not found (install Emscripten SDK, or set EMSCRIPTEN_SDK_DIR)" >&2
	return 1
}

install_wasm_deps() {
	if ! command -v wasm-ld >/dev/null 2>&1; then
		if command -v brew >/dev/null 2>&1; then
			echo "wasm-deps: installing lld@22 (wasm-ld)" >&2
			brew install lld@22
		else
			echo "wasm-deps: wasm-ld missing; install LLVM lld or: brew install lld@22" >&2
			exit 1
		fi
	fi

	local emsdk="${EMSCRIPTEN_SDK_DIR:-$HOME/repos/emsdk}"
	if ! command -v emcc >/dev/null 2>&1; then
		if [[ ! -f "${emsdk}/emsdk_env.sh" ]]; then
			echo "wasm-deps: cloning emsdk into ${emsdk}" >&2
			mkdir -p "$(dirname "${emsdk}")"
			git clone https://github.com/emscripten-core/emsdk.git "${emsdk}"
		fi
		echo "wasm-deps: emsdk install latest (may take a while)" >&2
		(
			cd "${emsdk}"
			./emsdk install latest
			./emsdk activate latest
		)
		echo "wasm-deps: add to your shell: source \"${emsdk}/emsdk_env.sh\"" >&2
		echo "wasm-deps: or set EMSCRIPTEN_SDK_DIR=${emsdk}" >&2
	fi

	ensure_raylib_wasm_libs
	echo "wasm-deps: done" >&2
}

raylib_wasm_ar_ok() {
	[[ -f "$1" ]] && [[ "$(file -b "$1")" == "current ar archive" ]]
}

fetch_raylib_wasm_ar() {
	local dest="$1" url="$2"
	curl -fsSL -o "${dest}" "${url}"
	if ! raylib_wasm_ar_ok "${dest}"; then
		rm -f "${dest}"
		echo "wasm: ${dest} is not a valid .a (got Git LFS pointer?)" >&2
		return 1
	fi
}

ensure_raylib_wasm_libs() {
	local odin_root wasm_dir base
	odin_root="$(odin root)"
	wasm_dir="${odin_root}/vendor/raylib/wasm"
	base="https://github.com/odin-lang/Odin/raw/master/vendor/raylib/wasm"
	mkdir -p "${wasm_dir}"

	if ! raylib_wasm_ar_ok "${wasm_dir}/libraylib.web.a"; then
		echo "wasm: fetching libraylib.web.a into ${wasm_dir}" >&2
		fetch_raylib_wasm_ar "${wasm_dir}/libraylib.web.a" "${base}/libraylib.web.a"
	fi
	if ! raylib_wasm_ar_ok "${wasm_dir}/libraygui.a"; then
		echo "wasm: fetching libraygui.a into ${wasm_dir}" >&2
		fetch_raylib_wasm_ar "${wasm_dir}/libraygui.a" "${base}/libraygui.a"
	fi
}

build_wasm() {
	ensure_wasm_ld
	ensure_emcc
	ensure_raylib_wasm_libs
	if [[ ! -f "${INDEX_SHELL}" ]]; then
		echo "wasm: missing ${INDEX_SHELL}" >&2
		exit 1
	fi

	local odin_root
	odin_root="$(odin root)"
	mkdir -p "${WEB_DIR}"

	odin build src/web \
		-target:js_wasm32 \
		-build-mode:obj \
		-define:RAYLIB_WASM_LIB=env.o \
		-out:"${OUT_WASM_OBJ}"

	cp "${odin_root}/core/sys/wasm/js/odin.js" "${WEB_DIR}/"

	emcc -o "${WEB_DIR}/index.html" \
		"${OUT_WASM_OBJ}" \
		"${odin_root}/vendor/raylib/wasm/libraylib.web.a" \
		"${odin_root}/vendor/raylib/wasm/libraygui.a" \
		--js-library "${FIVEK_STORAGE_JS}" \
		-sUSE_GLFW=3 \
		-sASYNCIFY \
		-sWARN_ON_UNDEFINED_SYMBOLS=0 \
		--preload-file "${ROOT}/assets/bg@assets/bg" \
		--preload-file "${ROOT}/assets/patterns@assets/patterns" \
		--preload-file "${ROOT}/assets/flamendless_logo.png@assets/flamendless_logo.png" \
		--preload-file "${ROOT}/assets/social@assets/social" \
		--preload-file "${ROOT}/assets/fonts/sholom@assets/fonts/sholom" \
		--shell-file "${INDEX_SHELL}"

	rm -f "${OUT_WASM_OBJ}"
}

if [[ $# -eq 0 ]]; then
	usage
	exit 0
fi
cmd="$1"
shift

case "${cmd}" in
	run)
		run_build_args=(-define:DEBUG=true)
		if [[ -n "${STATE:-}" ]]; then
			run_build_args+=(-define:START_STATE="${STATE}")
		fi
		build_game "${run_build_args[@]}"
		exec "${OUT_GAME}" "$@"
		;;
	autotest)
		build_autotest
		exec "${OUT_AUTOTEST}" "$@"
		;;
	build)
		build_game
		;;
	check)
		odin check src/main.odin -file
		odin check src/main.odin -file -define:AUTOTEST=true
		odin check src/web
		;;
	wasm)
		build_wasm
		;;
	wasm-deps)
		install_wasm_deps
		;;
	clear-save)
		clear_save
		;;
	wasm-run)
		build_wasm
		port="${1:-5555}"
		echo "Serving ${WEB_DIR} at http://localhost:${port}/"
		echo "Clear wasm save: http://localhost:${port}/?clearSave=1"
		exec python3 -m http.server "${port}" --directory "${WEB_DIR}"
		;;
	-h | --help | help)
		usage
		;;
	*)
		echo "Unknown command: ${cmd}" >&2
		usage >&2
		exit 1
		;;
esac

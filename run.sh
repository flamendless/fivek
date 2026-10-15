#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

OUT_GAME="${ROOT}/fivek"
OUT_AUTOTEST="${ROOT}/fivek_autotest"
WEB_DIR="${ROOT}/web"
OUT_WASM_OBJ="${WEB_DIR}/game.wasm.o"
INDEX_SHELL="${WEB_DIR}/index_shell.html"

usage() {
	cat <<'EOF'
Usage: ./run.sh <command> [args...]

Commands:
  run          Build and run the game
  autotest     Build and run headless autoplay test
  build        Build native game binary only
  check        Type-check game and autotest entrypoints
  wasm         Build WebAssembly for the browser (needs emcc)
  wasm-run     Build wasm and serve web/
EOF
}

build_game() {
	odin build src/main.odin -file -out:"${OUT_GAME}" "$@"
}

build_autotest() {
	odin build src/main.odin -file -out:"${OUT_AUTOTEST}" -define:AUTOTEST=true
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

ensure_raylib_wasm_libs() {
	local odin_root wasm_dir
	odin_root="$(odin root)"
	wasm_dir="${odin_root}/vendor/raylib/wasm"
	if [[ -f "${wasm_dir}/libraylib.web.a" ]]; then
		return 0
	fi
	echo "wasm: fetching raylib wasm libs into ${wasm_dir}" >&2
	mkdir -p "${wasm_dir}"
	curl -fsSL -o "${wasm_dir}/libraylib.web.a" \
		"https://raw.githubusercontent.com/odin-lang/Odin/master/vendor/raylib/wasm/libraylib.web.a"
	curl -fsSL -o "${wasm_dir}/libraygui.a" \
		"https://raw.githubusercontent.com/odin-lang/Odin/master/vendor/raylib/wasm/libraygui.a"
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
		-sUSE_GLFW=3 \
		-sWASM_BIGINT \
		-sWARN_ON_UNDEFINED_SYMBOLS=0 \
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
		build_game -define:DEBUG=true
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
	wasm-run)
		build_wasm
		port="${1:-5555}"
		echo "Serving ${WEB_DIR} at http://localhost:${port}/"
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

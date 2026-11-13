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
MINISERVE_VERSION="0.35.0"
MINISERVE_CACHE="${ROOT}/tools/miniserve/${MINISERVE_VERSION}"
DIST_DIR="${ROOT}/dist"
LAUNCHER_DIR="${ROOT}/launcher"
MINISERVE_BASE_URL="https://github.com/svenstaro/miniserve/releases/download/v${MINISERVE_VERSION}"

usage() {
	cat <<'EOF'
Usage: ./run.sh <command> [args...]

Commands:
	run          Build and run the game (DEBUG: STATE=title|stats|achievements|credits|tutorial|play|postgame|end|end:N|…)
	autotest     Build and run headless autoplay test
	build        Build native game binary only
	check        Type-check game and autotest entrypoints
	wasm         Build WebAssembly for the browser (needs emcc)
	wasm-deps    Install wasm toolchain (lld, emsdk, raylib wasm libs)
	wasm-run     Build wasm (DEBUG) and serve web/ with miniserve
	wasm-package       Build shareable browser folders under dist/ [mac|win|all]
	wasm-package-debug Same as wasm-package with DEBUG wasm (-g, -O0); STATE= for START_STATE
	clear-save         Remove native save files; hint for clearing browser save
EOF
}

clear_save() {
	local removed=0
	for f in save_fivek.bin save_autotest.bin career_stats.bin achievements.bin; do
		if [[ -f "${ROOT}/${f}" ]]; then
			rm -f "${ROOT}/${f}"
			echo "removed ${f}"
			removed=1
		fi
	done
	[[ "${removed}" -eq 1 ]] || echo "no native save files found"
	echo "wasm: open your dev server with ?clearSave=1 (clears localStorage ${WEB_SAVE_KEY}, fivek:career_stats, fivek:achievements, fivek:intro_prefs)"
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
	local mode="${1:-release}"
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

	local odin_extra=()
	local emcc_extra=()
	if [[ "${mode}" == "debug" ]]; then
		odin_extra=(-define:DEBUG=true)
		if [[ -n "${STATE:-}" ]]; then
			odin_extra+=(-define:START_STATE="${STATE}")
		fi
		emcc_extra=(-g -O0 -sASSERTIONS=2)
		echo "wasm: debug build (STATE=${STATE:-} sets START_STATE when set)" >&2
	fi

	odin build src/web \
		-target:js_wasm32 \
		-build-mode:obj \
		-define:RAYLIB_WASM_LIB=env.o \
		-out:"${OUT_WASM_OBJ}" \
		"${odin_extra[@]}"

	cp "${odin_root}/core/sys/wasm/js/odin.js" "${WEB_DIR}/"

	emcc -o "${WEB_DIR}/index.html" \
		"${OUT_WASM_OBJ}" \
		"${odin_root}/vendor/raylib/wasm/libraylib.web.a" \
		"${odin_root}/vendor/raylib/wasm/libraygui.a" \
		--js-library "${FIVEK_STORAGE_JS}" \
		-sUSE_GLFW=3 \
		-sASYNCIFY \
		-sWARN_ON_UNDEFINED_SYMBOLS=0 \
		--preload-file "${ROOT}/assets@assets" \
		--shell-file "${INDEX_SHELL}" \
		"${emcc_extra[@]}"

	rm -f "${OUT_WASM_OBJ}"
}

wasm_browser_dist_name() {
	local mode="${1:-release}"
	if [[ "${mode}" == "debug" ]]; then
		printf '%s\n' "fivek-browser-debug"
	else
		printf '%s\n' "fivek-browser"
	fi
}

WASM_WEB_ARTIFACTS=(index.html index.js index.wasm index.data odin.js)

assert_wasm_web_build() {
	local f
	for f in "${WASM_WEB_ARTIFACTS[@]}"; do
		if [[ ! -f "${WEB_DIR}/${f}" ]]; then
			echo "wasm-package: missing ${WEB_DIR}/${f} (run wasm build first)" >&2
			exit 1
		fi
	done
}

miniserve_mac_ok() {
	[[ -f "$1" ]] && [[ -x "$1" ]] && file -b "$1" | grep -q "Mach-O"
}

miniserve_win_ok() {
	[[ -f "$1" ]] && file -b "$1" | grep -qi "PE32"
}

fetch_miniserve() {
	local platform="$1"
	local asset dest url
	mkdir -p "${MINISERVE_CACHE}"

	case "${platform}" in
	mac)
		asset="miniserve-${MINISERVE_VERSION}-aarch64-apple-darwin"
		dest="${MINISERVE_CACHE}/${asset}"
		url="${MINISERVE_BASE_URL}/${asset}"
		if miniserve_mac_ok "${dest}"; then
			printf '%s\n' "${dest}"
			return 0
		fi
		echo "wasm-package: fetching ${asset}" >&2
		curl -fsSL -o "${dest}" "${url}"
		chmod +x "${dest}"
		if ! miniserve_mac_ok "${dest}"; then
			rm -f "${dest}"
			echo "wasm-package: ${dest} is not a valid macOS binary" >&2
			exit 1
		fi
		printf '%s\n' "${dest}"
		;;
	win)
		asset="miniserve-${MINISERVE_VERSION}-x86_64-pc-windows-msvc.exe"
		dest="${MINISERVE_CACHE}/${asset}"
		url="${MINISERVE_BASE_URL}/${asset}"
		if miniserve_win_ok "${dest}"; then
			printf '%s\n' "${dest}"
			return 0
		fi
		echo "wasm-package: fetching ${asset}" >&2
		curl -fsSL -o "${dest}" "${url}"
		if ! miniserve_win_ok "${dest}"; then
			rm -f "${dest}"
			echo "wasm-package: ${dest} is not a valid Windows executable" >&2
			exit 1
		fi
		printf '%s\n' "${dest}"
		;;
	*)
		echo "wasm-package: unknown platform ${platform}" >&2
		exit 1
		;;
	esac
}

copy_wasm_web_to() {
	local dest_dir="$1"
	local f
	for f in "${WASM_WEB_ARTIFACTS[@]}"; do
		cp "${WEB_DIR}/${f}" "${dest_dir}/${f}"
	done
}

wasm_package_mac() {
	local mode="${1:-release}"
	local base
	base="$(wasm_browser_dist_name "${mode}")"
	local out="${DIST_DIR}/${base}-macos-arm64"
	local miniserve_src
	miniserve_src="$(fetch_miniserve mac)"

	rm -rf "${out}"
	mkdir -p "${out}"
	copy_wasm_web_to "${out}"
	cp "${miniserve_src}" "${out}/miniserve"
	cp "${LAUNCHER_DIR}/README-player.txt" "${out}/README.txt"
	cp "${LAUNCHER_DIR}/macos/PlayFivek.command" "${out}/PlayFivek.command"
	chmod +x "${out}/miniserve" "${out}/PlayFivek.command"
	if command -v xattr >/dev/null 2>&1; then
		xattr -cr "${out}/miniserve" 2>/dev/null || true
	fi

	local zip="${DIST_DIR}/${base}-macos-arm64.zip"
	(
		cd "${DIST_DIR}"
		rm -f "${zip}"
		zip -qr "$(basename "${zip}")" "$(basename "${out}")"
	)
	echo "wasm-package: ${out}"
	echo "wasm-package: ${zip}"
}

wasm_package_win() {
	local mode="${1:-release}"
	local base
	base="$(wasm_browser_dist_name "${mode}")"
	local out="${DIST_DIR}/${base}-win64"
	local miniserve_src
	miniserve_src="$(fetch_miniserve win)"

	rm -rf "${out}"
	mkdir -p "${out}"
	copy_wasm_web_to "${out}"
	cp "${miniserve_src}" "${out}/miniserve.exe"
	cp "${LAUNCHER_DIR}/README-player.txt" "${out}/README.txt"
	cp "${LAUNCHER_DIR}/windows/PlayFivek.bat" "${out}/PlayFivek.bat"

	local zip="${DIST_DIR}/${base}-win64.zip"
	(
		cd "${DIST_DIR}"
		rm -f "${zip}"
		zip -qr "$(basename "${zip}")" "$(basename "${out}")"
	)
	echo "wasm-package: ${out}"
	echo "wasm-package: ${zip}"
}

wasm_package() {
	local which="${1:-all}"
	local mode="${2:-release}"
	local tag="wasm-package"
	[[ "${mode}" == "debug" ]] && tag="wasm-package-debug"

	build_wasm "${mode}"
	assert_wasm_web_build
	mkdir -p "${DIST_DIR}"

	case "${which}" in
	all)
		wasm_package_mac "${mode}"
		wasm_package_win "${mode}"
		;;
	mac)
		wasm_package_mac "${mode}"
		;;
	win)
		wasm_package_win "${mode}"
		;;
	*)
		echo "${tag}: use mac, win, or all (got ${which})" >&2
		exit 1
		;;
	esac
}

ensure_dev_miniserve() {
	if command -v miniserve >/dev/null 2>&1; then
		command -v miniserve
		return 0
	fi
	case "$(uname -s)" in
	Darwin)
		fetch_miniserve mac
		;;
	*)
		echo "wasm-run: miniserve not found (install it or use wasm-package to cache tools/miniserve/)" >&2
		exit 1
		;;
	esac
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
		odin check src/web -define:DEBUG=true
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
		build_wasm debug
		assert_wasm_web_build
		port="${1:-5555}"
		ms="$(ensure_dev_miniserve)"
		echo "Serving ${WEB_DIR} at http://127.0.0.1:${port}/"
		echo "Clear wasm save: http://127.0.0.1:${port}/?clearSave=1"
		exec "${ms}" -i 127.0.0.1 -p "${port}" --index index.html --quiet "${WEB_DIR}"
		;;
	wasm-package)
		wasm_package "${1:-all}" release
		;;
	wasm-package-debug)
		wasm_package "${1:-all}" debug
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

#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

PORT="${FIVEK_PORT:-5555}"
SERVER="./miniserve"

if [[ ! -f index.html ]]; then
	echo "Missing index.html — this folder is incomplete."
	read -r -p "Press Enter to close…"
	exit 1
fi
if [[ ! -x "$SERVER" ]]; then
	echo "Missing or non-executable miniserve."
	read -r -p "Press Enter to close…"
	exit 1
fi

echo "Starting game at http://127.0.0.1:${PORT}/"
echo "Close this window when you are done playing."
open "http://127.0.0.1:${PORT}/"
exec "$SERVER" -i 127.0.0.1 -p "${PORT}" --index index.html --quiet .

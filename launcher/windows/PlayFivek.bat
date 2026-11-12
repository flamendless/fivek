@echo off
setlocal
cd /d "%~dp0"

if not defined FIVEK_PORT set FIVEK_PORT=5555

if not exist "index.html" (
	echo Missing index.html — this folder is incomplete.
	pause
	exit /b 1
)
if not exist "miniserve.exe" (
	echo Missing miniserve.exe.
	pause
	exit /b 1
)

echo Starting game at http://127.0.0.1:%FIVEK_PORT%/
echo Close this window when you are done playing.
start "" "http://127.0.0.1:%FIVEK_PORT%/"
miniserve.exe -i 127.0.0.1 -p %FIVEK_PORT% --index index.html --quiet .

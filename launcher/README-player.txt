Bread, Fish, Repeat 5000x — browser build

HOW TO PLAY
  macOS:   double-click PlayFivek.command
  Windows: double-click PlayFivek.bat

  Keep the terminal window open while you play. Close it when you are done (that stops
  the local server).

  Do not open index.html directly from the file manager — the game needs a small local
  web server (started automatically by the Play script).

CLEAR SAVE
  While the game is running, open in your browser:
  http://127.0.0.1:5555/?clearSave=1
  (Use a different port if you set FIVEK_PORT.)

macOS
  If macOS blocks the app, right-click PlayFivek.command or miniserve and choose
  Open once. You may also need to allow local network access if prompted.

Windows
  Allow through Windows Firewall if asked (private network is enough).
  If SmartScreen warns about an unrecognized app: More info -> Run anyway.

TROUBLESHOOTING
  "Missing index.html" — the folder is incomplete; re-download the full zip.
  Port in use — close another copy of the game or set FIVEK_PORT to another number.

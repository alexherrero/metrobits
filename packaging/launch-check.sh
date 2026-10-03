#!/usr/bin/env bash
# Starts a packaged Metrobits the way a player would, on a scenario, has it save
# a screenshot and quit, and checks it drew the city and logged no script
# errors. It's how a release checks the platforms nobody has played it on yet:
#   bash packaging/launch-check.sh <package> <folder for the screenshot and log>
#   Windows (from Git Bash)  Metrobits-<version>-setup.exe: installs it
#                            silently, checks the Start-menu entry, plays it,
#                            then uninstalls it and checks it's gone
#   Linux                    Metrobits-<version>-x86_64.AppImage: plays it on
#                            a virtual display (xvfb-run)
# The screenshot is launch-<platform>.png and the game's own log
# launch-<platform>.log, both kept by the release run so you can look at them.
set -euo pipefail

PACKAGE=$(cd "$(dirname "${1:?usage: launch-check.sh <package> <folder>}")" && pwd)/$(basename "$1")
OUT=$(mkdir -p "${2:?usage: launch-check.sh <package> <folder>}" && cd "$2" && pwd)
# A busy scenario from the start, at a fixed seed.
ARGS=(--scenario=tokyo --seed=1989 --after=8)
# A screenshot of the city is a few hundred KB; a blank window is a few KB.
MIN_BYTES=50000
fail() { echo "launch check failed: $*" >&2; exit 1; }

case "$(uname -s)" in
MINGW* | MSYS*)
	PLATFORM=windows
	APP="/c/Program Files/Metrobits"
	MENU="/c/ProgramData/Microsoft/Windows/Start Menu/Programs/Metrobits.lnk"
	LOG="$(cygpath -u "$APPDATA")/Metrobits/logs/godot.log"
	SHOT="$OUT/launch-windows.png"
	rm -f "$LOG" "$SHOT"
	echo "==> installing $(basename "$PACKAGE")"
	"$PACKAGE" //VERYSILENT //SUPPRESSMSGBOXES //NORESTART
	[[ -f "$APP/Metrobits.exe" ]] || fail "no $APP/Metrobits.exe after installing"
	[[ -f "$APP/micropolis-core/content/images/tiles.png" ]] || fail "no content beside the game"
	[[ -f "$MENU" ]] || fail "no Start-menu entry"
	echo "==> playing"
	MSYS2_ARG_CONV_EXCL='*' timeout 300 "$APP/Metrobits.exe" -- "${ARGS[@]}" "--screenshot=$(cygpath -w "$SHOT")" \
		|| fail "the game exited with $?"
	cp "$LOG" "$OUT/launch-windows.log" || fail "the game wrote no log"
	echo "==> uninstalling"
	"$APP/unins000.exe" //VERYSILENT //SUPPRESSMSGBOXES //NORESTART
	# The uninstaller hands over to a copy of itself and returns at once.
	for _ in $(seq 1 60); do
		[[ -e "$APP/Metrobits.exe" || -e "$MENU" ]] || break
		sleep 2
	done
	[[ ! -e "$APP/Metrobits.exe" ]] || fail "uninstalling left $APP/Metrobits.exe"
	[[ ! -e "$MENU" ]] || fail "uninstalling left the Start-menu entry"
	;;
Linux)
	PLATFORM=linux
	LOG="${XDG_DATA_HOME:-$HOME/.local/share}/Metrobits/logs/godot.log"
	SHOT="$OUT/launch-linux.png"
	rm -f "$LOG" "$SHOT"
	chmod +x "$PACKAGE"
	echo "==> playing $(basename "$PACKAGE")"
	# GitHub's runners have no FUSE, so the AppImage unpacks itself and runs.
	APPIMAGE_EXTRACT_AND_RUN=1 timeout 300 xvfb-run -a -s "-screen 0 1600x1200x24" \
		"$PACKAGE" -- "${ARGS[@]}" "--screenshot=$SHOT" || fail "the game exited with $?"
	cp "$LOG" "$OUT/launch-linux.log" || fail "the game wrote no log"
	;;
*) fail "no launch check for $(uname -s)" ;;
esac

echo "==> what it drew and logged"
[[ -f "$SHOT" ]] || fail "no screenshot"
bytes=$(wc -c < "$SHOT")
echo "screenshot: $bytes bytes"
(( bytes >= MIN_BYTES )) || fail "the screenshot is $bytes bytes, too small to be the city"
cat "$OUT/launch-$PLATFORM.log"
! grep -n "SCRIPT ERROR" "$OUT/launch-$PLATFORM.log" || fail "the game logged script errors"
echo "==> $PLATFORM: the game installs, starts, plays and draws the city"

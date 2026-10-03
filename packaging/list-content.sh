#!/usr/bin/env bash
# Lists every file under micropolis-core the game reads, into
# packaging/content-used.txt, which package.sh copies into the app and nothing
# else. It runs the GUT tests, the game's soak and the
# scripted screens (which need a window) with Content.note_used recording, and
# adds the cities, which the engine reads itself. Run it again when the game
# starts reading other files. Needs Godot 4.7 (`godot`, or GODOT=).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT="${GODOT:-godot}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export CONTENT_USED="$WORK/used.txt"

echo "==> the tests"
"$GODOT" --headless --path "$ROOT/game" -s res://addons/gut/gut_cmdln.gd >"$WORK/gut.log" 2>&1 \
	|| { tail -20 "$WORK/gut.log" >&2; exit 1; }
echo "==> the game's soak"
"$GODOT" --headless --path "$ROOT/game" --script res://tools/soak.gd -- --out="$WORK/soak" >"$WORK/soak.log" 2>&1 \
	|| { tail -20 "$WORK/soak.log" >&2; exit 1; }
echo "==> the screens"
"$GODOT" --path "$ROOT/game" --script res://tools/take_screens.gd -- --out="$WORK/screens" --seed=1989 >"$WORK/screens.log" 2>&1 \
	|| { tail -20 "$WORK/screens.log" >&2; exit 1; }

# The engine opens the cities and scenarios itself, so they all go. A file
# only the tests read stays out: FogHornLow, which the game never plays (it
# plays HonkHonk-Low in its place, as the OLPC did).
(cd "$ROOT/micropolis-core" && find content/cities -type f) >>"$CONTENT_USED"
grep -v -x -e 'content/sounds/FogHornLow.mp3' "$CONTENT_USED" | sort -u >"$ROOT/packaging/content-used.txt"
echo "==> $(wc -l <"$ROOT/packaging/content-used.txt" | tr -d ' ') files in packaging/content-used.txt"

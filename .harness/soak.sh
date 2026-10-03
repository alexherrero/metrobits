#!/usr/bin/env bash
# soak.sh: the soak, long runs of the game and the engine. It builds everything,
# including the soak program twice (plain, and with clang's AddressSanitizer and
# UndefinedBehaviorSanitizer), then runs it all twice over, into run-1 and run-2
# under the folder given (default .harness/soak-results):
#
#   game.txt       the game itself, headless (game/tools/soak.gd): each of the 8
#                  scenarios at Super Fast to its end, its notice and what 1989
#                  did after; a city built with the palette's tools on a
#                  generated map, past 10,000 people, 50 years, saved and
#                  reloaded half way. build.txt records the build for the next.
#   native.txt     the engine (extension/native/soak.cpp): the 8 scenarios and
#                  the game's build replayed, 50 years each, saved and reloaded
#                  half way.
#   sanitized.txt  the same, under ASan and UBSan.
#
# It fails if a check in any of them fails, if the game's scenario ends differ
# from the engine's, if the sanitized run differs from the plain one, or if the
# second run differs from the first. About a minute on this Mac.
# Needs what init.sh needs, and runs after it or on its own.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="${1:-$ROOT/.harness/soak-results}"
GODOT="${GODOT:-godot}"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

SCONS_ARGS=()
case "$(uname -s)" in
  Darwin) PLATFORM=macos ;;
  Linux)  PLATFORM=linux; SCONS_ARGS+=(use_llvm=yes) ;;
  *) echo "soak.sh: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) echo "soak.sh: unsupported CPU $(uname -m)" >&2; exit 1 ;;
esac
SUFFIX="$PLATFORM.template_debug.$ARCH"
SOAK="$ROOT/extension/build/micropolis_soak.$SUFFIX"
SOAK_SAN="$ROOT/extension/build/micropolis_soak_san.$SUFFIX"
CONTENT="$ROOT/micropolis-core/content"
# Undefined behaviour, memory errors and, on Linux, leaks stop the run.
# LeakSanitizer doesn't run on arm64 macOS, so there leak checking is off.
# Engine edit 13 frees the sprites the engine pools, the one leak Linux
# reported before.
if [[ "$PLATFORM" == linux ]]; then LEAKS=1; else LEAKS=0; fi
export ASAN_OPTIONS="${ASAN_OPTIONS:-halt_on_error=1:detect_leaks=$LEAKS}"
export UBSAN_OPTIONS="${UBSAN_OPTIONS:-halt_on_error=1:print_stacktrace=1}"

echo "==> build, with the soak programs"
git submodule update --init --recursive
(cd extension && scons -j"$JOBS" platform="$PLATFORM" arch="$ARCH" target=template_debug \
  ${SCONS_ARGS[@]+"${SCONS_ARGS[@]}"} engine smoke extension soak)
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true

# The engine prints "init" and "destroyMapArrays: ..." to standard output.
engine_quiet() {
  sed -E 's/init|destroyMapArrays: mapBase: 0x[0-9a-f]+//g' | grep -v '^[[:space:]]*$' || true
}

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

for run in 1 2; do
  dir="$OUT/run-$run"
  rm -rf "$dir"
  mkdir -p "$dir"
  echo "==> run $run: the game ($dir/game.txt)"
  "$GODOT" --headless --path game --script res://tools/soak.gd -- --out="$dir" >"$dir/game.log" 2>&1 \
    || fail "run $run: the game's soak (see $dir/game.log)"
  cat "$dir/game.txt" 2>/dev/null || true
  echo "==> run $run: the engine, plain and sanitized"
  "$SOAK" "$CONTENT" "$dir" --build="$dir/build.txt" 2>"$dir/native.log" | engine_quiet >"$dir/native.txt" \
    || fail "run $run: the native soak (see $dir/native.txt)"
  "$SOAK_SAN" "$CONTENT" "$dir" --build="$dir/build.txt" 2>"$dir/sanitized.log" | engine_quiet >"$dir/sanitized.txt" \
    || fail "run $run: the sanitized soak (see $dir/sanitized.txt and sanitized.log)"
  grep -E '^(FAIL|SOAK)' "$dir/native.txt" "$dir/sanitized.txt" || true
  cat "$dir/sanitized.log"
  diff <(grep ' ends ' "$dir/game.txt") <(grep ' ends ' "$dir/native.txt") \
    || fail "run $run: the game's scenario ends differ from the engine's"
  diff "$dir/native.txt" "$dir/sanitized.txt" || fail "run $run: the sanitized run differs from the plain one"
done

echo "==> run 2 against run 1"
for file in game.txt build.txt native.txt sanitized.txt; do
  diff "$OUT/run-1/$file" "$OUT/run-2/$file" >/dev/null || fail "$file differs between the runs"
done
for city in "$OUT"/run-1/*.cty; do
  cmp -s "$city" "$OUT/run-2/$(basename "$city")" || fail "$(basename "$city") differs between the runs"
done

if [[ $failed -ne 0 ]]; then
  echo "==> soak FAILED" >&2
  exit 1
fi
echo "==> soak OK: both runs pass, agree with each other, and the sanitized engine runs as the plain one"

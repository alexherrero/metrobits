#!/usr/bin/env bash
# init.sh: build everything and run the tests, from a fresh clone or a dirty tree.
# Every /work and /review session runs this to reach a known-good state; CI runs
# it too. Needs: clang (on Windows, Visual Studio's C++ compiler, with this run
# from Git Bash), SCons, and Godot 4.7 on PATH as `godot` (or
# GODOT=/path/to/godot).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-godot}"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

SCONS_ARGS=()
case "$(uname -s)" in
  Darwin) PLATFORM=macos ;;
  Linux)  PLATFORM=linux; SCONS_ARGS+=(use_llvm=yes) ;; # clang, as on the Mac
  MINGW*|MSYS*) PLATFORM=windows ;; # Git Bash, building with Microsoft's compiler
  *) echo "init.sh: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) echo "init.sh: unsupported CPU $(uname -m)" >&2; exit 1 ;;
esac
SUFFIX="$PLATFORM.template_debug.$ARCH"

echo "==> tools"
command -v scons >/dev/null || { echo "missing scons (brew install scons / pip install scons)" >&2; exit 1; }
command -v "$GODOT" >/dev/null || { echo "missing godot ($GODOT); want $(cat .godot-version)" >&2; exit 1; }
want="$(cat .godot-version)"
have="$("$GODOT" --version | head -1)"
[[ "$have" == "$want".* ]] || { echo "godot is $have, want $want (.godot-version)" >&2; exit 1; }

echo "==> submodules"
git submodule update --init --recursive

echo "==> build engine, smoke program and extension ($SUFFIX)"
(cd extension && scons -j"$JOBS" platform="$PLATFORM" arch="$ARCH" target=template_debug ${SCONS_ARGS[@]+"${SCONS_ARGS[@]}"})

echo "==> smoke: the 8 scenarios, natively"
for scenario in 1 2 3 4 5 6 7 8; do
  "extension/build/micropolis_smoke.$SUFFIX" micropolis-core/content "$scenario" 2000 | grep -E "^(end|SMOKE)"
done

echo "==> godot: import the project headless"
# The first import registers the extension; its exit code isn't meaningful.
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true

echo "==> godot: the extension loads"
"$GODOT" --headless --path game --script res://tools/check_extension.gd

echo "==> godot: GUT tests, headless"
"$GODOT" --headless --path game -s res://addons/gut/gut_cmdln.gd

echo "==> ready"

#!/usr/bin/env bash
# verify.sh: fast per-file check, well under 2 s. Full builds and tests belong in
# init.sh and CI. Silent with exit 0 on success; non-zero on failure.
# $1 is the file just written.
set -uo pipefail
FILE="${1:-}"; [[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"
REL="${FILE#"$ROOT"/}"
GODOT="${GODOT:-godot}"
CPP=(clang++ -x c++ -std=c++17 -fsyntax-only -Wno-pragma-once-outside-header)
G="$ROOT/extension/godot-cpp"

case "$REL" in
  game/*.gd)
    # godot --check-only exits 0 even on a parse error, so read its output.
    out="$("$GODOT" --headless --path "$ROOT/game" --check-only --script "res://${REL#game/}" 2>&1)"
    if grep -qE 'SCRIPT ERROR|Parse Error|Parse error|ERROR:' <<<"$out"; then
      echo "$out" >&2; exit 1
    fi ;;
  extension/src/*.cpp|extension/src/*.h)
    # Needs godot-cpp's generated headers, which the first build creates.
    [[ -d "$G/gen/include" ]] || exit 0
    "${CPP[@]}" -I"$ROOT/extension/src" -I"$ROOT/extension/native" -I"$ROOT/micropolis-core/engine" \
      -I"$G/include" -I"$G/gen/include" -I"$G/gdextension" "$FILE" || exit 1 ;;
  extension/native/*.cpp|extension/native/*.h)
    "${CPP[@]}" -I"$ROOT/extension/native" -I"$ROOT/micropolis-core/engine" "$FILE" || exit 1 ;;
  micropolis-core/engine/emscripten.cpp|micropolis-core/engine/callback.cpp|micropolis-core/engine/js_callback.h)
    ;; # web-only; not in the native build
  micropolis-core/engine/*.cpp)
    "${CPP[@]}" -w -I"$ROOT/micropolis-core/engine" "$FILE" || exit 1 ;;
  *SConstruct|*SConscript)
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$FILE" || exit 1 ;;
  *.sh)
    bash -n "$FILE" || exit 1 ;;
esac
exit 0

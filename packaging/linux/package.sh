#!/usr/bin/env bash
# Builds Metrobits for Linux, x86_64, in build/linux:
#   Metrobits.AppDir                     the game, with the micropolis-core
#                                        content it reads and the licences
#                                        beside it (copy-content.sh), a
#                                        .desktop file and the icon
#   Metrobits-<version>-x86_64.AppImage  that folder as one file, which runs
#                                        on most distributions
# Needs SCons, clang, Godot 4.7.2 with its export templates (`godot` on PATH,
# or GODOT=/path/to/godot), and appimagetool (on PATH, or APPIMAGETOOL=), with
# the AppImage runtime it builds in (APPIMAGE_RUNTIME=; without it,
# appimagetool downloads its own). The version is the export presets'
# application/short_version. GitHub builds it too (release.yml).
set -euo pipefail

GODOT="${GODOT:-godot}"
APPIMAGETOOL="${APPIMAGETOOL:-appimagetool}"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HERE="$ROOT/packaging/linux"
OUT="$ROOT/build/linux"
APPDIR="$OUT/Metrobits.AppDir"
VERSION=$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' "$ROOT/game/export_presets.cfg")
APPIMAGE="Metrobits-$VERSION-x86_64.AppImage"

echo "==> the GDExtension, release, x86_64"
(cd "$ROOT/extension" && scons -j"$(nproc)" platform=linux arch=x86_64 target=template_release use_llvm=yes extension)

echo "==> Metrobits $VERSION for Linux"
rm -rf "$OUT"
mkdir -p "$APPDIR/usr/bin"
# A fresh checkout has nothing imported yet, and the export needs it.
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --export-release Linux "$APPDIR/usr/bin/metrobits.x86_64"

echo "==> the content and licences, beside the game"
bash "$ROOT/packaging/copy-content.sh" "$APPDIR/usr/bin" "$APPDIR"

echo "==> the AppImage's own files"
cp "$HERE/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"
cp "$HERE/metrobits.desktop" "$APPDIR/metrobits.desktop"
cp "$ROOT/game/art/app-icon.png" "$APPDIR/metrobits.png"
ln -s metrobits.png "$APPDIR/.DirIcon"

echo "==> $APPIMAGE"
ARCH=x86_64 "$APPIMAGETOOL" --no-appstream ${APPIMAGE_RUNTIME:+--runtime-file "$APPIMAGE_RUNTIME"} \
	"$APPDIR" "$OUT/$APPIMAGE"
(cd "$OUT" && sha256sum "$APPIMAGE" > "$APPIMAGE.sha256")

echo "==> done: $OUT/$APPIMAGE"

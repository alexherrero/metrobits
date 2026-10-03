#!/usr/bin/env bash
# Builds Metrobits for Windows, x86_64, in build/windows, from Git Bash:
#   Metrobits/                       the game, with the micropolis-core content
#                                    it reads and the licences beside it
#                                    (copy-content.sh)
#   Metrobits-<version>-setup.exe    an installer for that folder
#                                    (metrobits.iss): into Program Files, with
#                                    a Start-menu entry and an uninstaller.
#                                    It's unsigned, so SmartScreen warns
#                                    before it runs.
# Needs SCons, Visual Studio's C++ compiler, Godot 4.7.2 with its export
# templates (`godot` on PATH, or GODOT=/path/to/godot), and Inno Setup 6
# (ISCC=, default its usual place in Program Files). The version is the export
# presets' application/short_version. GitHub builds it too (release.yml).
set -euo pipefail

GODOT="${GODOT:-godot}"
ISCC="${ISCC:-/c/Program Files (x86)/Inno Setup 6/ISCC.exe}"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HERE="$ROOT/packaging/windows"
OUT="$ROOT/build/windows"
GAME="$OUT/Metrobits"
VERSION=$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' "$ROOT/game/export_presets.cfg")
SETUP="Metrobits-$VERSION-setup.exe"

echo "==> the GDExtension, release, x86_64"
(cd "$ROOT/extension" && scons -j"${NUMBER_OF_PROCESSORS:-4}" platform=windows arch=x86_64 target=template_release extension)

echo "==> Metrobits $VERSION for Windows"
rm -rf "$OUT"
mkdir -p "$GAME"
# A fresh checkout has nothing imported yet, and the export needs it.
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --export-release "Windows Desktop" "$GAME/Metrobits.exe"

echo "==> the content and licences, beside the game"
bash "$ROOT/packaging/copy-content.sh" "$GAME"

echo "==> $SETUP"
# EA's notice without its web page header, then the GPL, as on the Mac.
{ awk 'past >= 2; /^---$/ { past++ }' "$ROOT/micropolis-core/MicropolisGPLLicenseNotice.md"
	echo; cat "$ROOT/LICENSE"; } > "$OUT/license.txt"
# Inno Setup takes Windows paths, and its /D options aren't paths at all, so
# Git Bash mustn't rewrite them.
MSYS2_ARG_CONV_EXCL='*' "$ISCC" /Q \
	"/DVersion=$VERSION" \
	"/DSource=$(cygpath -w "$GAME")" \
	"/DLicense=$(cygpath -w "$OUT/license.txt")" \
	"/DIcon=$(cygpath -w "$ROOT/game/art/app-icon.ico")" \
	"/DOutput=$(cygpath -w "$OUT")" \
	"$(cygpath -w "$HERE/metrobits.iss")"
(cd "$OUT" && sha256sum "$SETUP" > "$SETUP.sha256")

echo "==> done: $OUT/$SETUP"

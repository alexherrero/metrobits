#!/usr/bin/env bash
# Copies what ships beside the game into <folder>/micropolis-core, the folder
# the game reads its content from (Content.core_dir), and checks the result
# holds no Windows art:
#   bash packaging/copy-content.sh <folder> [<package to check>]
# What ships: only the content the game reads (packaging/content-used.txt, from
# list-content.sh), each file traced to EA's 2008 release in
# CONTENT-PROVENANCE.md, and never content/tilesets, the Windows edition's
# retail art, which the GPL doesn't cover; the OLPC's own folder whole, since
# its PROVENANCE.md lists every file; and the licences. The check covers the
# whole package, <package to check>, or <folder> if there's none.
# Each platform's package script uses it.
set -euo pipefail

DEST=${1:?usage: copy-content.sh <folder> [<package to check>]}
CHECK=${2:-$DEST}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CORE="$DEST/micropolis-core"

mkdir -p "$CORE"
while IFS= read -r file; do
	[[ "$file" == content/* ]] || continue
	mkdir -p "$CORE/$(dirname "$file")"
	cp "$ROOT/micropolis-core/$file" "$CORE/$file"
done < "$ROOT/packaging/content-used.txt"
cp -R "$ROOT/micropolis-core/olpc" "$CORE/"
for file in MicropolisGPLLicenseNotice.md MicropolisPublicNameLicense.md CONTENT-PROVENANCE.md; do
	cp "$ROOT/micropolis-core/$file" "$CORE/"
done
cp "$ROOT/LICENSE" "$DEST/LICENSE"

windows_art=$(find "$CHECK" -ipath '*tilesets*' -o -iname 'splash.bmp' -o -iname 'smltitle.bmp' -o -iname 'micropolis-title*')
if [[ -n "$windows_art" ]]; then
	echo "the package holds art the GPL doesn't cover:" >&2
	echo "$windows_art" >&2
	exit 1
fi

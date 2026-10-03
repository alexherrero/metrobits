#!/usr/bin/env bash
# Copies a tagged tree of this repo into a checkout of the public repo,
# alexherrero/metrobits, as one commit, "Metrobits <version>", tagged the same
#:
#   bash packaging/snapshot.sh v<version> <public checkout>
# It leaves out what stays private (AGENTS.md, CLAUDE.md, this repo's own
# README) and the content that never ships (micropolis-core/content/tilesets,
# the Windows edition's retail art, and images/robot_odyssey.png, which nothing
# explains), puts packaging/public/README.md in as the README, and keeps
# godot-cpp as a submodule at the tag's commit. It fails, committing nothing,
# if what's left holds a home-folder path, Windows art, a mention of the private
# notes or the old project name, or EA's trademark outside micropolis-core's
# own files from upstream. Pushing is left to you: it prints the command.
set -euo pipefail

TAG=${1:?usage: snapshot.sh v<version> <public checkout>}
PUBLIC=$(cd "${2:?usage: snapshot.sh v<version> <public checkout>}" && pwd)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${TAG#v}
git -C "$ROOT" rev-parse -q --verify "$TAG^{commit}" >/dev/null || { echo "no tag $TAG here" >&2; exit 1; }
[[ -d "$PUBLIC/.git" ]] || { echo "$PUBLIC isn't a git checkout" >&2; exit 1; }
[[ -z "$(git -C "$PUBLIC" status --porcelain)" ]] || { echo "$PUBLIC has changes" >&2; exit 1; }

echo "==> $TAG into $PUBLIC"
find "$PUBLIC" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git -C "$ROOT" archive "$TAG" | tar -x -C "$PUBLIC"
bash "$ROOT/packaging/check-release-notes.sh" "$VERSION" "$PUBLIC" \
	|| { git -C "$PUBLIC" checkout -q -- . 2>/dev/null; git -C "$PUBLIC" clean -fdq; exit 1; }
rm -rf "$PUBLIC/AGENTS.md" "$PUBLIC/CLAUDE.md" \
	"$PUBLIC/micropolis-core/content/tilesets" "$PUBLIC/micropolis-core/content/images/robot_odyssey.png"
mv "$PUBLIC/packaging/public/README.md" "$PUBLIC/README.md"
rmdir "$PUBLIC/packaging/public"

echo "==> checks"
cd "$PUBLIC"
# The words are split so this script doesn't find itself.
trademark="sim""city" old_name="pixel.\?""city" notes="va""ult"
problems=$(
	grep -rIl --exclude-dir=.git '/Us''ers/' . || true
	find . -path ./.git -prune -o \( -ipath '*tilesets*' -o -iname 'splash.bmp' -o -iname 'smltitle.bmp' \) -print
	grep -rIli --exclude-dir=.git --exclude-dir=micropolis-core -e "$trademark" -e "$old_name" -e "$notes" . || true
	grep -rIli -e "$old_name" -e "$notes" micropolis-core || true
)
if [[ -n "$problems" ]]; then
	echo "not committed; these need a look:" >&2
	echo "$problems" >&2
	exit 1
fi

echo "==> Metrobits $VERSION"
git add -A
git update-index --add --cacheinfo "160000,$(git -C "$ROOT" rev-parse "$TAG:extension/godot-cpp"),extension/godot-cpp"
git commit -q -m "Metrobits $VERSION"
git tag -a "$TAG" -m "Metrobits $VERSION"
git log --oneline -1
echo "==> to publish it: git -C $PUBLIC push origin HEAD:main $TAG"

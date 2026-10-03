#!/usr/bin/env bash
# Releases Metrobits: checks everything a release needs, tags this repo, copies
# the release into the public repo as one commit (snapshot.sh), pushes it once
# you say yes, and waits for the draft release: the signed, notarized Mac
# installer, the Windows installer and the Linux AppImage. Publishing the draft stays yours: on GitHub, or the command it
# prints at the end.
#   bash packaging/release.sh v<version> [<public checkout>]
# Before running it, on main and pushed, with CI green:
#   - the version in game/project.godot (application/config/version) and in
#     game/export_presets.cfg (application/short_version and version);
#   - packaging/release-notes/<version>.md, one "- " bullet per feature or fix.
set -euo pipefail

TAG=${1:?usage: release.sh v<version> [<public checkout>]}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PUBLIC=$(cd "${2:-$ROOT/../metrobits}" && pwd)
REPO=alexherrero/metrobits
VERSION=${TAG#v}
fail() { echo "not released: $*" >&2; exit 1; }

cd "$ROOT"
echo "==> checks for Metrobits $VERSION"
[[ "$TAG" == v[0-9]* ]] || fail "the tag is v<version>, e.g. v1.0.2"
[[ "$(git rev-parse --abbrev-ref HEAD)" == main ]] || fail "not on main"
[[ -z "$(git status --porcelain)" ]] || fail "there are uncommitted changes"
git fetch -q origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "main isn't pushed"
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || fail "$TAG already exists"
grep -q "^config/version=\"$VERSION\"$" game/project.godot || fail "game/project.godot's version isn't $VERSION"
grep -q "^application/short_version=\"$VERSION\"$" game/export_presets.cfg || fail "game/export_presets.cfg's short_version isn't $VERSION"
grep -q "^application/version=\"$VERSION\"$" game/export_presets.cfg || fail "game/export_presets.cfg's version isn't $VERSION"
bash packaging/check-release-notes.sh "$VERSION"
ci=$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json conclusion --jq '.[0].conclusion')
[[ "$ci" == success ]] || fail "CI isn't green for $(git rev-parse --short HEAD) (${ci:-no run yet})"
[[ -z "$(git -C "$PUBLIC" status --porcelain)" ]] || fail "$PUBLIC has changes"
git -C "$PUBLIC" pull -q --ff-only

echo "==> tagging $TAG"
git tag -a "$TAG" -m "Metrobits $VERSION"
git push -q origin "$TAG"

echo "==> the public snapshot"
bash packaging/snapshot.sh "$TAG" "$PUBLIC"
read -r -p "Push Metrobits $VERSION to $REPO, where everyone can see it? [y/N] " answer || answer=""
if [[ "$answer" != [yY] ]]; then
	echo "not pushed: $PUBLIC holds the commit and tag. Push them with: git -C $PUBLIC push origin HEAD:main $TAG"
	exit 0
fi
git -C "$PUBLIC" push -q origin HEAD:main "$TAG"

echo "==> waiting for the Mac, Windows and Linux builds"
run=""
for _ in $(seq 1 20); do
	run=$(gh run list --repo "$REPO" --workflow release.yml --branch "$TAG" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
	[[ -n "$run" ]] && break
	sleep 6
done
[[ -n "$run" ]] || fail "no release run started for $TAG; start it with: gh workflow run release.yml --repo $REPO --ref $TAG"
gh run watch "$run" --repo "$REPO" --exit-status >/dev/null || fail "the release run failed: gh run view $run --repo $REPO"
gh release view "$TAG" --repo "$REPO" --json url,assets --jq '.url, (.assets[] | "  \(.name)")'
assets=$(gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name')
for package in "Metrobits-$VERSION.pkg" "Metrobits-$VERSION-setup.exe" "Metrobits-$VERSION-x86_64.AppImage"; do
	grep -qx "$package" <<<"$assets" || echo "missing from the draft: $package (a Mac installer Apple was slow on is finished by packaging/macos/finish-notarization.sh $TAG)"
done
echo "==> the draft is ready. To publish it: gh release edit $TAG --repo $REPO --draft=false --latest"

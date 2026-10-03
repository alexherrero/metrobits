#!/usr/bin/env bash
# Finishes a release whose notarization Apple hadn't answered while
# release-macos.yml waited: downloads that tag's signed .pkg
# and its notary id from the release run's artifact, waits for Apple's answer,
# staples the ticket, checks Gatekeeper's verdict, and puts the .pkg and its
# SHA-256 on the tag's draft release. Run it on a Mac with the notary
# credentials stored as a keychain profile (`xcrun notarytool
# store-credentials`; default metrobits-notary, or NOTARY_PROFILE=):
#   bash packaging/macos/finish-notarization.sh v<version>
set -euo pipefail

TAG=${1:?usage: finish-notarization.sh v<version>}
REPO=${REPO:-alexherrero/metrobits}
PROFILE=${NOTARY_PROFILE:-metrobits-notary}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

run=$(gh run list --repo "$REPO" --workflow release-macos.yml --branch "$TAG" --limit 1 --json databaseId --jq '.[0].databaseId')
[[ -n "$run" ]] || { echo "no release run for $TAG in $REPO" >&2; exit 1; }
echo "==> the signed installer from run $run"
gh run download "$run" --repo "$REPO" --dir "$WORK"
pkg=$(find "$WORK" -name 'Metrobits-*.pkg' | head -1)
[[ -f "$pkg.notary-id" ]] || { echo "that run's installer isn't waiting on Apple (no .notary-id)" >&2; exit 1; }
id=$(cat "$pkg.notary-id")

echo "==> waiting for Apple: $id"
xcrun notarytool wait "$id" --keychain-profile "$PROFILE"
status=$(xcrun notarytool info "$id" --keychain-profile "$PROFILE" --output-format json \
	| python3 -c 'import json, sys; print(json.load(sys.stdin).get("status", ""))')
if [[ "$status" != Accepted ]]; then
	xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2 || true
	echo "Apple's answer: $status" >&2
	exit 1
fi
xcrun stapler staple "$pkg"
spctl --assess --type install --verbose=2 "$pkg"
(cd "$(dirname "$pkg")" && shasum -a 256 "$(basename "$pkg")" > "$(basename "$pkg").sha256")

echo "==> onto the draft release $TAG"
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
	prerelease=$([[ "$TAG" == *-* ]] && echo --prerelease || true)
	notes_file="$(cd "$(dirname "$0")/.." && pwd)/release-notes/${TAG#v}.md"
	if [[ ! -f "$notes_file" ]]; then
		notes_file="$WORK/notes.md"
		echo "Metrobits ${TAG#v} for macOS (Apple Silicon and Intel): open the .pkg to install it into Applications. It's signed with a Developer ID and notarized by Apple." > "$notes_file"
	fi
	gh release create "$TAG" --repo "$REPO" --draft $prerelease --verify-tag --title "Metrobits ${TAG#v}" \
		--notes-file "$notes_file"
fi
gh release upload "$TAG" --repo "$REPO" --clobber "$pkg" "$pkg.sha256"
echo "==> done"

#!/usr/bin/env bash
# Checks a version's release notes, packaging/release-notes/<version>.md: the
# file exists, isn't empty, and every line is a bullet ("- ") naming a feature
# or a fix. Nothing else goes in release notes; the README carries the rest.
# The release workflow, snapshot.sh, release.sh and finish-notarization.sh run
# it, and a test checks the current version's notes on every push.
#   bash packaging/check-release-notes.sh <version> [<repo root>]
set -euo pipefail

VERSION=${1:?usage: check-release-notes.sh <version> [<repo root>]}
ROOT=${2:-$(cd "$(dirname "$0")/.." && pwd)}
NOTES="$ROOT/packaging/release-notes/$VERSION.md"

[[ -f "$NOTES" ]] || { echo "no release notes for $VERSION: write $NOTES, one '- ' bullet per feature or fix" >&2; exit 1; }
grep -q '[^[:space:]]' "$NOTES" || { echo "$NOTES is empty" >&2; exit 1; }
if grep -v '^[[:space:]]*$' "$NOTES" | grep -qv '^- '; then
	echo "$NOTES has lines that aren't '- ' bullets:" >&2
	grep -v '^[[:space:]]*$' "$NOTES" | grep -v '^- ' >&2
	exit 1
fi
echo "release notes for $VERSION: $(grep -c '^- ' "$NOTES") bullet(s)"

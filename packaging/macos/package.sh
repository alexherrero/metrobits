#!/usr/bin/env bash
# Builds the Mac app and its installer in build/macos:
#   Metrobits.app             universal (Apple Silicon and Intel), with the
#                              micropolis-core content the game reads
#                              (packaging/content-used.txt) and the olpc
#                              folder inside it, in Contents/Resources
#                              (Content.core_dir); never the Windows art
#   Metrobits-<version>.pkg   a standard installer for macOS's Installer: a
#                              welcome page, the licence (EA's notice, then the
#                              GPL), and the app into /Applications
# Signing: with MACOS_SIGN_APP and MACOS_SIGN_INSTALLER naming
# the Developer ID Application and Installer identities in a keychain, the app
# is signed with the hardened runtime and the .pkg with the installer identity.
# With notary credentials as well (NOTARY_PROFILE, a `notarytool
# store-credentials` profile; or NOTARY_KEY, an App Store Connect API key's .p8
# file, with NOTARY_KEY_ID and NOTARY_ISSUER), Apple notarizes the .pkg, which
# covers the app inside it, and its ticket is stapled to the .pkg. If Apple
# hasn't answered within NOTARY_WAIT (default 20m), the signed .pkg is kept
# unstapled beside Metrobits-<version>.pkg.notary-id, and
# finish-notarization.sh finishes it later. Without the identities, both are
# ad-hoc signed and a downloaded copy shows Gatekeeper's warning.
# Needs SCons, and Godot 4.7.2 with its export templates: `godot` on PATH, or
# GODOT=/path/to/godot. The version is the export preset's
# application/short_version. GitHub builds it too (release-macos.yml).
set -euo pipefail

GODOT="${GODOT:-godot}"
SIGN_APP="${MACOS_SIGN_APP:-}"
SIGN_INSTALLER="${MACOS_SIGN_INSTALLER:-}"
NOTARY_WAIT="${NOTARY_WAIT:-20m}"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
	NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "${NOTARY_KEY:-}" ]]; then
	NOTARY_ARGS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
else
	NOTARY_ARGS=()
fi
NOTARIZE=$([[ -n "$SIGN_APP" && -n "$SIGN_INSTALLER" && ${#NOTARY_ARGS[@]} -gt 0 ]] && echo yes || echo no)

# Sends a file to Apple's notary service and waits up to NOTARY_WAIT. Returns 0
# once Apple accepts it; 2, with its submission id in <file>.notary-id, if
# Apple is still working on it; 1, printing Apple's log, if Apple rejects it.
notarize() {
	local id status
	id=$(xcrun notarytool submit "$1" "${NOTARY_ARGS[@]}" --output-format json \
		| python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')
	echo "submitted $(basename "$1") to Apple's notary service: $id"
	xcrun notarytool wait "$id" "${NOTARY_ARGS[@]}" --timeout "$NOTARY_WAIT" >/dev/null 2>&1 || true
	status=$(xcrun notarytool info "$id" "${NOTARY_ARGS[@]}" --output-format json \
		| python3 -c 'import json, sys; print(json.load(sys.stdin).get("status", ""))')
	echo "notarization of $(basename "$1"): $status"
	case "$status" in
		Accepted) return 0 ;;
		"In Progress") echo "$id" > "$1.notary-id"; return 2 ;;
		*) xcrun notarytool log "$id" "${NOTARY_ARGS[@]}" >&2 || true; return 1 ;;
	esac
}

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HERE="$ROOT/packaging/macos"
OUT="$ROOT/build/macos"
APP="$OUT/Metrobits.app"
ID=io.github.alexherrero.metrobits
VERSION=$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' "$ROOT/game/export_presets.cfg")

echo "==> the GDExtension, release, universal"
(cd "$ROOT/extension" && scons -j"$(sysctl -n hw.ncpu)" target=template_release arch=universal extension)

echo "==> Metrobits.app $VERSION"
rm -rf "$OUT"
mkdir -p "$OUT"
# A fresh checkout has nothing imported yet, and the export needs it.
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --export-release macOS "$APP"

echo "==> the content and licences, inside the app"
RESOURCES="$APP/Contents/Resources"
# Only the content the game reads (packaging/content-used.txt, from
# list-content.sh), each file traced to EA's 2008 release in
# CONTENT-PROVENANCE.md: never content/tilesets, the Windows
# edition's retail art, which the GPL doesn't cover. The OLPC's own
# folder goes whole; its PROVENANCE.md lists every file.
grep '^content/' "$ROOT/packaging/content-used.txt" \
	| rsync -a --files-from=- "$ROOT/micropolis-core/" "$RESOURCES/micropolis-core/"
ditto "$ROOT/micropolis-core/olpc" "$RESOURCES/micropolis-core/olpc"
for file in MicropolisGPLLicenseNotice.md MicropolisPublicNameLicense.md CONTENT-PROVENANCE.md; do
	cp "$ROOT/micropolis-core/$file" "$RESOURCES/micropolis-core/"
done
cp "$ROOT/LICENSE" "$RESOURCES/LICENSE"

echo "==> no Windows art in the app"
windows_art=$(find "$APP" -ipath '*tilesets*' -o -iname 'splash.bmp' -o -iname 'smltitle.bmp' -o -iname 'micropolis-title*')
if [[ -n "$windows_art" ]]; then
	echo "the app holds art the GPL doesn't cover:" >&2
	echo "$windows_art" >&2
	exit 1
fi

if [[ -n "$SIGN_APP" ]]; then
	echo "==> signing the app: $SIGN_APP"
	# Inside out: the engine library, then the app, with the hardened runtime
	# and a secure timestamp, which notarization requires.
	codesign --force --options runtime --timestamp --sign "$SIGN_APP" "$APP"/Contents/Frameworks/*.dylib
	codesign --force --options runtime --timestamp --sign "$SIGN_APP" "$APP"
else
	echo "==> ad-hoc signing"
	codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "==> Metrobits-$VERSION.pkg"
WORK="$OUT/pkg"
mkdir -p "$WORK/root" "$WORK/resources"
ditto "$APP" "$WORK/root/Metrobits.app"
# Install where it's told, never over a copy found elsewhere on the disk.
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$WORK/component.plist"
pkgbuild --root "$WORK/root" --component-plist "$WORK/component.plist" \
	--install-location /Applications --identifier "$ID" --version "$VERSION" "$WORK/Metrobits.pkg"
cp "$HERE/welcome.html" "$WORK/resources/"
# EA's notice without its web page header, then the GPL.
{ awk 'past >= 2; /^---$/ { past++ }' "$ROOT/micropolis-core/MicropolisGPLLicenseNotice.md"
	echo; cat "$ROOT/LICENSE"; } > "$WORK/resources/license.txt"
sed -e "s/@ID@/$ID/g" -e "s/@VERSION@/$VERSION/g" "$HERE/distribution.xml" > "$WORK/distribution.xml"
productbuild --distribution "$WORK/distribution.xml" --resources "$WORK/resources" \
	--package-path "$WORK" ${SIGN_INSTALLER:+--sign "$SIGN_INSTALLER" --timestamp} "$OUT/Metrobits-$VERSION.pkg"
rm -rf "$WORK"
PKG="$OUT/Metrobits-$VERSION.pkg"
if [[ "$NOTARIZE" == yes ]]; then
	echo "==> notarizing the installer"
	if notarize "$PKG"; then
		xcrun stapler staple "$PKG"
		echo "==> Gatekeeper's verdict"
		spctl --assess --type install --verbose=2 "$PKG"
	elif [[ -f "$PKG.notary-id" ]]; then
		echo "==> Apple is still working on it: finish with packaging/macos/finish-notarization.sh"
	else
		echo "Apple rejected the installer" >&2
		exit 1
	fi
fi
(cd "$OUT" && shasum -a 256 "Metrobits-$VERSION.pkg" > "Metrobits-$VERSION.pkg.sha256")

echo "==> done: $APP and $OUT/Metrobits-$VERSION.pkg"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Set release VERSION (e.g. 1.0.0)}"
: "${BUILD_NUMBER:?Set increasing BUILD_NUMBER}"
: "${SIGNING_IDENTITY:?Set Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set existing notarytool keychain profile}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]
archive="build/dist/SelectionTranslator-$VERSION-$BUILD_NUMBER.zip"
[[ ! -e "$archive" ]] || { echo "Release archive already exists; choose a new build number." >&2; exit 1; }
export CONFIGURATION=Release
scripts/build.sh
app=build/DerivedData/Build/Products/Release/SelectionTranslator.app
/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
scripts/validate-app.sh "$app"
mkdir -p build/dist
submission="build/dist/SelectionTranslator-$VERSION-$BUILD_NUMBER-notarization.zip"
/usr/bin/ditto -c -k --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
/usr/sbin/spctl --assess --type execute --verbose=2 "$app"
archive="build/dist/SelectionTranslator-$VERSION-$BUILD_NUMBER.zip"
/usr/bin/ditto -c -k --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
rm "$submission"
printf 'Signed, notarized release: %s\n' "$archive"

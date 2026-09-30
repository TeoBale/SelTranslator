#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
app="build/DerivedData/Build/Products/${CONFIGURATION:-Release}/SelectionTranslator.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build_number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
mkdir -p build/dist
archive="build/dist/SelectionTranslator-$version-$build_number-local.zip"
/usr/bin/ditto -c -k --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
printf 'Local unsigned package: %s\n' "$archive"

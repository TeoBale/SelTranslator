#!/bin/bash
set -euo pipefail
app="${1:?Usage: validate-app.sh /path/to/SelectionTranslator.app}"
plist="$app/Contents/Info.plist"
read_key() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
[[ "$(read_key CFBundleIdentifier)" == com.selectiontranslator.app ]]
[[ "$(read_key LSMinimumSystemVersion)" == 26.0 ]]
[[ "$(read_key LSUIElement)" == true ]]
[[ "$(read_key CFBundleShortVersionString)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$(read_key CFBundleVersion)" =~ ^[1-9][0-9]*$ ]]
executable="$app/Contents/MacOS/$(read_key CFBundleExecutable)"
[[ -x "$executable" ]]
# Validate every architecture's linked minimum OS, not merely Info.plist.
xcrun vtool -show-build "$executable" | awk '/minos/ { if ($2 != "26.0") exit 1; found=1 } END { if (!found) exit 1 }'
if [[ -n "${VERSION:-}" ]]; then [[ "$(read_key CFBundleShortVersionString)" == "$VERSION" ]]; fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then [[ "$(read_key CFBundleVersion)" == "$BUILD_NUMBER" ]]; fi
printf 'Validated %s (%s), macOS 26.0+\n' "$(read_key CFBundleShortVersionString)" "$(read_key CFBundleVersion)"

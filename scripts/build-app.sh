#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/SelTranslator.app"
ZIP_PATH="$DIST_DIR/SelTranslator-macos.zip"
BIN_PATH="$ROOT_DIR/.build/release/SelTranslator"

mkdir -p "$DIST_DIR"

swift build -c release --product SelTranslator

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/SelTranslator"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>SelTranslator</string>
  <key>CFBundleExecutable</key>
  <string>SelTranslator</string>
  <key>CFBundleIdentifier</key>
  <string>com.teobale.seltranslator</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SelTranslator</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "$APP_DIR/Contents/MacOS/SelTranslator"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" || true
fi

rm -f "$ZIP_PATH"
(cd "$DIST_DIR" && zip -qry "SelTranslator-macos.zip" "SelTranslator.app")

echo "Artifact: $ZIP_PATH"
shasum -a 256 "$ZIP_PATH"

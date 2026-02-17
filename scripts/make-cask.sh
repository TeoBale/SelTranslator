#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <version> <artifact-url>"
  echo "Example: $0 0.1.0 https://github.com/TeoBale/SelTranslator/releases/download/v0.1.0/SelTranslator-macos.zip"
  exit 1
fi

VERSION="$1"
URL="$2"
TMP_FILE="$(mktemp -t seltranslator-artifact)"
trap 'rm -f "$TMP_FILE"' EXIT

curl -fsSL "$URL" -o "$TMP_FILE"
SHA256="$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')"

cat <<EOF
cask "sel-translator" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$URL"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
EOF

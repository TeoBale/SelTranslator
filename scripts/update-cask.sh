#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <version> <sha256> [owner/repo]"
  echo "Example: $0 0.2.0 abc123... TeoBale/SelTranslator"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASK_DIR="$ROOT_DIR/Casks"
CASK_PATH="$CASK_DIR/sel-translator.rb"

VERSION="$1"
SHA256="$2"
REPOSITORY="${3:-TeoBale/SelTranslator}"

mkdir -p "$CASK_DIR"

cat > "$CASK_PATH" <<EOF
cask "sel-translator" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/${REPOSITORY}/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/${REPOSITORY}"

  app "SelTranslator.app"
end
EOF

echo "Updated cask at $CASK_PATH"

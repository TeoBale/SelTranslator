#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --package-path Packages/TranslationCore
fixture_dir=$(mktemp -d /tmp/SelectionTranslator-shortcuts.XXXXXX)
trap 'rm -rf "$fixture_dir"' EXIT
swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  -I Packages/TranslationCore/.build/debug/Modules \
  App/Hotkeys.swift Tools/ShortcutFixtureCheck.swift \
  Packages/TranslationCore/.build/debug/TranslationCore.build/InterfaceSafety.swift.o \
  -o "$fixture_dir/ShortcutFixtureCheck"
"$fixture_dir/ShortcutFixtureCheck"

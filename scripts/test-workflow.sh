#!/bin/bash
# Opt-in GUI integration; requires Accessibility permission and installed en/it models.
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
cd "$(dirname "$0")/.."
swift build --package-path Packages/TranslationCore
fixture_dir=$(mktemp -d /tmp/SelectionTranslator-workflow.XXXXXX)
fixture_name="SelectionTranslator-workflow-$(basename "$fixture_dir").txt"
fixture_path="/private/tmp/$fixture_name"
trap 'rm -rf "$fixture_dir"; rm -f "$fixture_path"' EXIT
swiftc -sdk "$sdk_path" -swift-version 6 -strict-concurrency=complete -parse-as-library \
  -I Packages/TranslationCore/.build/debug/Modules \
  App/SelectionAccess.swift App/AppleTranslationEngine.swift App/Diagnostics.swift \
  Tools/WorkflowFixtureCheck.swift \
  Packages/TranslationCore/.build/debug/TranslationCore.build/Workflow.swift.o \
  -o "$fixture_dir/WorkflowFixtureCheck"
printf '  Hello from SelectionTranslator.  \n' > "$fixture_path"
osascript - "$fixture_path" <<'APPLESCRIPT'
on run args
    set fixtureFile to POSIX file (item 1 of args)
    with timeout of 15 seconds
        tell application "TextEdit"
            open fixtureFile
            activate
        end tell
    end timeout
end run
APPLESCRIPT
"$fixture_dir/WorkflowFixtureCheck"
osascript - "$fixture_name" <<'APPLESCRIPT'
on run args
    with timeout of 15 seconds
        tell application "TextEdit" to close document (item 1 of args) saving no
    end timeout
end run
APPLESCRIPT

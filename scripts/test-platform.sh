#!/bin/bash
# Interactive, opt-in AX integration against a disposable TextEdit document.
set -euo pipefail
cd "$(dirname "$0")/.."
swift Tools/AXProbe.swift
swift build --package-path Packages/TranslationCore
probe_dir=$(mktemp -d /tmp/SelectionTranslator-AX.XXXXXX)
trap 'rm -rf "$probe_dir"' EXIT
swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  -I Packages/TranslationCore/.build/debug/Modules \
  App/SelectionAccess.swift Tools/AXFixtureCheck.swift \
  Packages/TranslationCore/.build/debug/TranslationCore.build/Workflow.swift.o \
  -o "$probe_dir/AXFixtureCheck"
# Unique fixed fixture name/value is verified inside the test before any AX writes.
# Close only our disposable fixture before restoring its content.
osascript <<'APPLESCRIPT'
tell application "TextEdit"
    if exists document "SelectionTranslator-AX-fixture.txt" then
        set existingFixture to document "SelectionTranslator-AX-fixture.txt"
        if path of existingFixture is not "/tmp/SelectionTranslator-AX-fixture.txt" then error "Refusing to close a different document with the fixture name."
        close existingFixture saving no
    end if
end tell
APPLESCRIPT
python3 - <<'PY'
from pathlib import Path
Path('/tmp/SelectionTranslator-AX-fixture.txt').write_text('  Hello from SelectionTranslator.  \nA second paragraph for selection validation.\n')
PY
osascript -e 'tell application "TextEdit" to open POSIX file "/tmp/SelectionTranslator-AX-fixture.txt"' -e 'tell application "TextEdit" to activate'
"$probe_dir/AXFixtureCheck"

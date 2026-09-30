#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-Release}"
args=(-project SelectionTranslator.xcodeproj -scheme SelectionTranslator -configuration "$configuration" -destination "generic/platform=macOS" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO)
if [[ -n "${VERSION:-}" ]]; then args+=("MARKETING_VERSION=$VERSION"); fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then args+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER"); fi
xcodebuild "${args[@]}" build
scripts/validate-app.sh "build/DerivedData/Build/Products/$configuration/SelectionTranslator.app"

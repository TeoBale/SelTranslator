# Build and release

Requirements: macOS 26+, Xcode 26 with the macOS 26 SDK (development verified with Xcode 26.2 / SDK 26.2). Open `SelectionTranslator.xcodeproj`, choose the shared SelectionTranslator scheme, and run. The app is a menu-bar application. The target uses Swift 6 with complete concurrency checking and intentionally disables App Sandbox for cross-process Accessibility access.

From the repository root:

```sh
swift test --package-path Packages/TranslationCore
CONFIGURATION=Debug scripts/build.sh
open build/DerivedData/Build/Products/Debug/SelectionTranslator.app
scripts/package.sh
```

`package.sh` creates a Release app and a local ZIP plus SHA-256 file under `build/dist`. Local artifacts are unsigned for distribution (the executable may have a linker-generated ad-hoc signature). Gatekeeper approval for downloaded distribution artifacts requires the signed release procedure below. Builds are reproducible from checked-in project and local package; byte-identical outputs are not promised by Xcode. Build products are excluded from git.

## Versions and signing

Checked-in defaults are version `1.0.0`, build `1`. Release scripts require a three-component version and an increasing positive integer build number and pass both into Xcode, then verify the resulting bundle. Every release must increase the build number; scripts cannot infer previously published versions. All target/package/bundle minimum OS settings are macOS 26.0. Artifact validation checks both Info.plist and Mach-O metadata.

Install a Developer ID Application certificate into a local keychain. Store Apple notarization credentials in a keychain profile with `xcrun notarytool store-credentials`; do not put certificates, passwords, API keys, or private keys in the repository. Then run:

```sh
VERSION=1.0.0 BUILD_NUMBER=1 \
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE=SelectionTranslator scripts/release.sh
```

The script builds, signs with hardened runtime, verifies signatures, submits for notarization, staples the ticket, validates the ticket, checks Gatekeeper, then packages the stapled app. It exits on any failure. There are no third-party embedded frameworks to sign separately. Outputs are immutable version-and-build filenames; upload only the final ZIP and checksum. No publication credentials or automated public distribution are configured. CI builds an unsigned local package and validates the extracted artifact.

## Release checklist

- Run package behavioral tests and Release build; inspect CI artifact validation.
- On a fresh macOS 26 account, install the signed app into Applications and verify Gatekeeper accepts the downloaded ZIP.
- Launch from Applications, grant Accessibility permission, and verify the displayed permission status updates. Verify denial explains Translate Clipboard as fallback.
- With models absent, select a supported pair and complete the visible model download setup; retry the preserved request. Verify download cancellation and unavailable network show readable errors.
- Verify selection translation, direct replacement, and clipboard translation. Confirm clipboard changes only on Copy.
- Run the documented application-compatibility matrix and performance measurements for the release OS/hardware.
- Change shortcuts; test a conflict and confirm old working registration survives.
- Install over the previous signed version; verify preferences, shortcuts, model state, and Accessibility authorization. A local unsigned build may need renewed Accessibility authorization after rebuilding.
- Verify all bundle/Mach-O metadata targets 26.0; verify version/build against release name.
- Confirm signature, notarization, stapled ticket, and Gatekeeper acceptance. Credential-dependent checks remain pending until a Developer ID identity and notary profile are available.

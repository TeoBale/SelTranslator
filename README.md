# SelectionTranslator

A native macOS 26+ menu-bar translator using Apple's on-device Translation framework. Swift 6, SwiftUI, AppKit, Accessibility, and a small local Swift package; no third-party dependencies, server, accounts, analytics, or translation history.

## Build and run

Requires a Mac running macOS 26 or later and Xcode 26.2 (the verified SDK). Use full Xcode, not only Command Line Tools:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --package-path Packages/TranslationCore
scripts/package.sh
open build/DerivedData/Build/Products/Release/SelectionTranslator.app
```

The local ZIP and SHA-256 checksum are in `build/dist/`. For development, open `SelectionTranslator.xcodeproj`, select the SelectionTranslator scheme, and Run; or use `CONFIGURATION=Debug scripts/build.sh`. Release builds include arm64 and x86_64; runtime verification was on Apple M1 only. The local build is unsigned and intended for this machine. See [release instructions](docs/release.md) for Developer ID signing and notarization.

## Use

The menu-bar speech-bubble icon provides three commands:

- **Translate Selection** reads selected text through Accessibility, then shows the translation, detected source, target, source correction, and Copy. Default shortcut: **⌘⌥F6** (Fn/🌐 may be required by your keyboard settings).
- **Translate and Replace** writes directly to the selected text only if the original app, focused element, selected text, range, editability, and request still validate. A successful replacement does not open a window or activate SelectionTranslator. Enable its independent shortcut in Settings. Failed replacement retains the translation and an explanation.
- **Translate Clipboard** explicitly reads existing plain text and shows a result. Neither capture nor translation changes the clipboard; only **Copy** does.

Settings includes framework-supported source/target languages, shortcut editors, Accessibility status, and model setup. Click **Record Shortcut…** and press any key combination, such as **⌃⇧J**, to register it immediately. Press **Esc** to cancel recording. Key labels follow the current keyboard layout. Failed registrations leave the previous working shortcut active.

Enable SelectionTranslator in **System Settings → Privacy & Security → Accessibility** for selection commands. The terminal's permission does not grant the packaged app access. No simulated Command-C, paste events, or automatic undo is used.

If models are missing, choose **Set Up Models**, then **Prepare Models** in the visible setup window and accept Apple's prompt. Downloads can require internet and disk space; text translation stays on device. After setup, use **Retry Retained Request** for a result, or return to the original app and selection and choose **Retry Last Request** from the menu bar for another validated replacement attempt. There are no automatic retries.

Short or ambiguous text may require choosing a source language. Source correction applies to the retained request; starting a new request uses Settings. Same-language operations preserve the original text exactly. Translation preserves leading/trailing whitespace; replacement is plain text and may lose rich formatting.

## Verification and limitations

- [Verification record and remaining checks](docs/verification.md)
- [Compatibility matrix and real TextEdit checks](docs/compatibility.md)
- [Measured performance and measurement gaps](docs/performance.md)
- [Architecture, API verification, and safety policy](docs/architecture.md)
- [Release checklist and signing](docs/release.md)

Run `scripts/test-platform.sh` for the opt-in disposable TextEdit fixture (requires terminal Accessibility access and changes application focus), and `scripts/benchmark.sh` for content-free Translation framework benchmarks using installed models. CI runs behavioral tests, a Release build, packaging, and extracted-artifact validation. GUI/TCC/download checks need a logged-in Mac and are not simulated by CI.

TextEdit's tested plain-text control supports capture and direct replacement. Other applications and controls remain conditional; consult the matrix rather than assuming universal compatibility. AX validation and writing are separate IPC operations, so cross-process races cannot be eliminated. Models can be removed by the system; availability is checked on every request.

## Troubleshooting

**No selection:** Select text in an external app. Some PDF, web, and custom-rendered controls do not expose `AXSelectedText`. Use Translate Clipboard explicitly if needed.

**Access granted but capture fails:** Refresh permission status. After moving/rebuilding the app, remove and re-add its entry in Accessibility; use a stable installed path for releases. Quit duplicate instances that may occupy a shortcut.

**Shortcut conflict:** Click **Record Shortcut…** and press another key combination. The displayed active shortcut changes only after successful registration. Fn behavior follows macOS Keyboard settings.

**Replacement refused:** Leave the original selection and focused field unchanged while translation runs. Any detected change, closed source, missing reliable range, timeout, or read-only control refuses the write. Copy remains an explicit action in the result panel.

**Models or translation fail:** Open model setup for an explicit pair and prepare again. Correct ambiguous source language manually. Errors remain readable in the result window until dismissed; there are no timed error toasts.

**Diagnostics:** `log stream --predicate 'subsystem == "com.selectiontranslator.app"' --level info` shows request IDs, fixed stage names, durations, text lengths, and app-cold classification. It never logs selected/translated text, document values, or arbitrary framework error dictionaries. Do not attach screenshots containing private text when reporting a problem.

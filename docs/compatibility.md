# Accessibility compatibility

Minimum OS: macOS 26. These results are capabilities of the tested controls, not a promise that every view in an application behaves alike. Version one reads `AXSelectedText`; it never simulates Command-C. Translate Clipboard is the explicit fallback. Replacement requires writable selected text, a selected range, the same application instance, the same focused AX element (CFEqual), unchanged selected text/range, and an active request. If a full document value was exposed, it must also remain unchanged. Without a reliable range, capture may translate but replacement is refused.

Validation and the single selected-text write are separate IPC operations. Another process can change state between them; no atomic cross-process transaction is claimed. Rich-text attributes may be lost or inherited according to the source application. Version one promises plain text only. Same-language output is preserved exactly and does not perform an AX write.

## Checks performed on September 30, 2026

Reference OS: macOS 26.5.2 (25F84), Swift 6 strict concurrency. The terminal-hosted probe was Accessibility trusted; the packaged app requires its own permission and must be checked separately after installation.

| Application / control | Installed | Text / range exposed | Selected text writable | Selection changes detected | Exact replacement | Focus / closure |
|---|---|---|---|---|---|---|
| TextEdit, disposable plain-text fixture | Yes | Yes / yes | Yes | Changed range and text rejected by real adapter | `Hello` → `Ciao` changed only selected span; leading/trailing spaces and paragraph retained | Focus to Finder and fixture-window closure rejected |
| Notes | Yes | Pending (not running at probe) | Pending | Pending | Pending | Pending |
| Safari | Yes; launched local fixture | Focused control reports text/range/value attributes; fixture editor identity was not verified | Attributes reported writable; replacement unverified | Pending | Pending | Pending |
| Chrome | No | Pending / unavailable | Pending | Pending | Pending | Pending |
| VS Code | Yes | Disposable local fixture launch requested; application did not become running within bounded observation | Pending | Pending | Pending | Pending |
| Preview / PDF | Yes; running | Focused-element read returned `cannotComplete` (-25204); no text claim | Pending | Pending | Pending | Pending |

The TextEdit integration fixture ran successfully using `bash scripts/test-platform.sh`. It also verified that a superseded request is refused and that clipboard `changeCount` stays unchanged during capture/replacement. No user document was modified; the fixture is under `/tmp`. Automated core tests cover state decisions, but cannot establish compatibility of untested controls.

## Reproduce capability checks

Run `swift Tools/AXProbe.swift`. It performs only reads and reports capability/status fields; it never prints selected text or document values. It does not activate applications or request permission. Launch the relevant application, select disposable text, and run again.

For the complete opt-in TextEdit adapter integration, run `bash scripts/test-platform.sh`. This opens and modifies a disposable fixture, switches focus to Finder, returns to TextEdit, and closes the fixture without saving. The terminal must have Accessibility and Apple Events permission. Do not run concurrently with other focus-sensitive checks. The test covers source-window closure; source-process exit and same-application focus movement remain pending.

To compile the fixture tool separately:

```sh
swift build --package-path Packages/TranslationCore
swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  -I Packages/TranslationCore/.build/debug/Modules \
  App/SelectionAccess.swift Tools/AXFixtureCheck.swift \
  Packages/TranslationCore/.build/debug/TranslationCore.build/Workflow.swift.o \
  -o /tmp/SelectionTranslator-AXFixtureCheck
```

Create `/tmp/SelectionTranslator-AX-fixture.txt` containing exactly:

```text
  Hello from SelectionTranslator.  
A second paragraph for selection validation.
```

Include a final newline. Open this file in TextEdit, make its editor frontmost, then execute `/tmp/SelectionTranslator-AXFixtureCheck`. The tool refuses any other application or document value. It changes the disposable fixture; TextEdit may autosave it. Restore the fixture content before repeating. This is an opt-in interactive integration check, not a CI test.

## Manual release matrix

For each application, record version, control type, text/range availability, writable selected text, and result for: unchanged selection, changed range, changed selected text, changed surrounding text, focus moved to another field, focus moved to another application, source window closed, and source application quit. Verify replacement affects exactly the selected span and clipboard contents remain unchanged. Repeat with a paragraph, Unicode/surrogate pairs, whitespace, and rich text. Use disposable documents. Mark read-only PDF/page selections as capture-only unless the actual control exposes a writable selected-text attribute.

## Threading and responsiveness

AX objects remain owned by the main actor; no `@unchecked Sendable` wrapper is used. The chosen SDK's `AXUIElement.h` and [Apple's reference](https://developer.apple.com/documentation/applicationservices/axuielement_h) describe messaging timeouts and CF identity but do not guarantee arbitrary-thread client safety. Main-actor isolation is a conservative choice until supported threading evidence and measurements justify moving IPC off-main.

`AXUIElementSetMessagingTimeout` sets a process-wide 40 ms timeout on the system element. Capture/revalidation check an aggregate 250 ms deadline between synchronous operations, allowing at most one message's timeout overshoot. The first yield allows shortcut feedback to render. A sluggish source application can still stall the main actor during each synchronous message. The 100 ms feedback target therefore requires measurement and is not guaranteed by these bounds alone. Replacement validation/write deliberately have no suspension between the final request/focus check and write.

## Native app launch checks

The Debug app launched successfully on the reference machine. Native Accessibility inspection confirmed settings language/model controls, all three shortcut editors, permission guidance, and a scrollable privacy statement. The app's own Accessibility permission was absent, independently of the trusted terminal. Invoking Translate Selection through the native menu produced a persistent result window with the complete permission error in a scroll area, a source correction picker, retry action, and an Accessibility settings action; no Copy action was present without a result. Show Last Result reused the same result window. No permission was granted automatically.

A focused-window-only screenshot attempt failed with `could not create image from window` (window sharing state 0). Pixel-level layout verification remains pending; no whole-screen capture was taken. Posting the configured shortcut through a synthetic HID event did not produce a new request, so an actual hardware-key shortcut test remains pending. These checks establish app launch and persistent error presentation, not end-to-end selected-text translation by the packaged app.

An additional opt-in full workflow fixture is provided by `bash scripts/test-workflow.sh`. It compiles the real AX adapter, installed-session engine, and coordinator under the Xcode SDK; it checks English → Italian output, whitespace preservation, unchanged document content, and zero clipboard adapter calls without printing text. It requires installed English/Italian models. Its execution remains pending: TextEdit refused newly generated disposable files on this machine, and AppleScript open timed out at its 15-second bound. Existing independent real AX and real framework checks do not establish this complete vertical path. The script uses a canonical `/private/tmp` path for a subsequent manual retry.

A local disposable HTML fixture was opened in Safari. A read-only probe reported selected-text/range/value exposure and writability, but the focused control did not match the expected fixture textarea value; no selection write or replacement occurred. This is not evidence of page/editor compatibility. Opening the same disposable file through LaunchServices in Visual Studio Code returned success but no `com.microsoft.VSCode` running application appeared in two observations; editor checks remain pending. Notes was left pending to avoid creating or editing synced user notes. Preview's later focused-control probe returned selected-text `noValue` (-25212) and unsupported range/value attributes; no disposable PDF selection was established, so PDF capture remains pending.

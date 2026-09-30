# Architecture and platform decisions

## Verified API surface

The implementation was compiled against Xcode 26.2's macOS 26.2 SDK with `MACOSX_DEPLOYMENT_TARGET=26.0`, Swift 6, and complete strict concurrency checking. The local package and bundle/distribution metadata also require macOS 26. The installed `Translation.swiftinterface` marks `TranslationSession(installedSource:target:)`, `cancel()`, `isReady`, and `TranslationError.notInstalled` as macOS 26.0. Only the initializer, cancellation, and error are used; no later strategy APIs are assumed. SwiftUI `translationTask` and `LanguageAvailability` predate macOS 26.

Apple references: [installed-source sessions](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:)), [translation task](https://developer.apple.com/documentation/swiftui/view/translationtask(_:action:)), [messaging timeouts](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout).

## Ownership

`AppDelegate` wires a status item and reuses settings, result, and setup windows. `AppModel` owns preferences and setup presentation. `WorkflowCoordinator` in `TranslationCore` owns one request, its cancellation task, retained context, and an explicit state enum. `AXSelectionAccess` owns one bounded captured AX context. `AppleTranslationEngine` owns detection and each request's task-local direct session. Clipboard and Carbon hotkeys are narrow adapters.

UI state stays on the main actor. Non-Sendable Translation framework objects never become shared mutable session caches. The model-setup action is created in a nonisolated factory, keeping its supplied session local to the async action and sending only readiness status back to the main actor. Supported-language discovery uses the same ownership pattern. No unchecked Sendable annotations or preconcurrency suppression is used.

AX references stay on the main actor because the checked primary SDK documentation does not guarantee arbitrary-thread AX client safety. Each IPC has a 40 ms timeout; a 250 ms aggregate deadline is checked between calls, with up to one message's overshoot. This is a documented responsiveness tradeoff, not a claim that AX cannot block. Capture yields once after status feedback. Result UI appears only after capture and translation; the replacement fast path never opens a window.

## Workflow and safety

Each request captures a UUID, delivery mode, target, source preference, text, and optional selection token. Starting another request cancels the previous task. Every asynchronous return and the final write boundary check current request identity. Cancellation during framework work is cooperative; a task-local session is cancelled when its operation unwinds. The app does not share a non-Sendable session merely to call `cancel()` concurrently. A backend that delays cancellation may continue work, but cannot deliver stale UI or replace text.

The AX context includes source application instance/PID/bundle, AX element identity, exact selected text, range, editability, and full document value when available. Replacement checks current frontmost app, element identity, text, range, settable selected-text attribute, request, and any available full-value snapshot. Missing range or editability fails closed. Equal output is a validated no-op. Validation is not atomic with writing; changes in the other process between IPC calls remain possible. There is no automatic write-back undo.

Same-language output preserves original text exactly. Otherwise only the trimmed body is translated, then original leading/trailing whitespace is restored. No rich-text conversion or formatting restoration is attempted.

The clipboard adapter is read only for the explicit clipboard command and written only by Copy. Capture errors never trigger clipboard fallback. Memory retains only current request/result/context, not history; nothing persists translated content.

## Models and recovery

Automatic detection uses NaturalLanguage's top two hypotheses, requiring at least 0.65 confidence and a 0.20 margin. This conservative heuristic can reject very short valid selections; the visible source override is the intended recovery. Language choices come from `LanguageAvailability.supportedLanguages`. Identifiers preserve scripts; same-language comparison uses maximal language identifiers rather than stripping to a base language code.

Every non-same-language request checks current pair availability. Missing models route to visible SwiftUI setup; unsupported pairs, uncertain detection, empty input, framework failure, and cancellation have distinct outcomes. A previous success never overrides missing availability or `notInstalled`. Automatic retry budget is **zero**: no duplicate attempts, sleeps, hidden recovery branches, or repeated download prompts. An explicit retry starts a new request with retained input and target and revalidates replacement.

Fresh sessions are the production baseline. The benchmark compares fresh and retained task-local sessions; reuse and idle prewarming are withheld without evidence of a useful improvement. See the performance report for numbers and limits.

## Interface and diagnostics

Hotkeys use native Carbon registration and layout-independent F1–F12 with configurable modifiers. New registration must succeed before old registration is removed and settings are persisted. Conflicts remain readable in Settings. A successful registration does not prove an OS-reserved hardware/Fn combination will be delivered, so manual validation remains part of release QA.

There are no auto-dismiss notifications: progress appears in the status item and long errors remain in a reusable, selectable result view. No delayed callback can hide a newer error. Model setup uses a generation token to reject completion from an older setup view.

Structured logs accept fixed milestones, request IDs, elapsed time, text length, and app-cold classification. Framework error objects and content never enter diagnostic logs. `acknowledgement_submitted` measures the status-button display submission, not photons on screen; display latency needs interactive measurement.

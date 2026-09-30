# Verification record

2026-09-30, Apple M1 MacBook Air (8 GB), macOS 26.5.2, Xcode 26.2 / SDK 26.2.

| Check | Result |
| --- | --- |
| Swift 6 / complete strict concurrency | Debug and universal Release builds pass; no unchecked Sendable or preconcurrency suppression |
| Local package behavioral tests | 19 tests across workflow and production shortcut transaction suites pass |
| Native app launch | Verified menu, settings controls, persistent permission-error result, source correction controls, reused windows |
| Local ZIP | Built, extracted, Info.plist and every Mach-O slice's macOS 26.0 minimum validated; SHA-256 verified |
| Real Accessibility integration | Disposable TextEdit capture/exact replacement/clipboard preservation and changed text/range/focus/stale request/closed-window rejection pass |
| Real Translation framework | Installed English–Italian fresh and retained session benchmark succeeds; 30 samples per group; see performance report |
| Clipboard policy | Deterministic coordinator tests plus real TextEdit pasteboard change-count check pass |
| Hotkey registration policy | Production-used transaction tests cover conflict, old-registration removal failure, rollback, disabling, and unchanged persistence |
| Global physical shortcut | Pending: synthetic event did not produce a request; real keyboard/Fn/OS-reservation check required |
| Visible acknowledgement ≤100 ms | Pending; display-submission instrumentation is present but is not physical-display measurement |
| Models | Missing-model outcomes measured; visible download/consent/cancellation remains interactive release QA |
| Full packaged selection workflow | Requires granting the packaged app its own Accessibility permission; terminal permission is separate |
| Pixel-level visual inspection | Focused-window screenshot capture unavailable in this environment; native AX controls verified |
| Developer ID / notarization / fresh upgrade | Automation provided; credentials and interactive release validation pending |

Tests cover superseded late completions, cancellation during capture and engine work, same-language preservation, whitespace, source correction, models disappearing after success, unsupported pairs with no automatic retries, failed replacement retaining output, and selection/context policy mutations. A single engine suspension covers the workflow's cancellation boundary regardless of whether its implementation is preparing or translating; framework-internal cancellation latency is not established by these mocks.

There are no timed notifications or dismissal timers to race. Persistent errors and explicit window closing replace that entire failure mode. SwiftUI model setup uses generation checks and removes its hosting view on close to cancel the view task.

Reproduction commands are in [README](../README.md), [compatibility](compatibility.md), [performance](performance.md), and [release](release.md). AppKit's metadata extractor prints a harmless warning that no AppIntents framework dependency was found; this app does not implement App Intents.

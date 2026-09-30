// Opt-in installed-model vertical integration using a disposable TextEdit fixture.
import AppKit
import ApplicationServices
import TranslationCore

@MainActor private final class UntouchedClipboard: ClipboardAccess {
    var reads = 0
    var writes = 0
    func readText() -> String? { reads += 1; return nil }
    func writeText(_ text: String) { writes += 1 }
}

@main struct WorkflowFixtureCheck {
    @MainActor static func main() async throws {
        let fixture = "  Hello from SelectionTranslator.  \n"
        guard AXIsProcessTrusted() else { throw CheckError.fixtureNotFocused }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.04)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        var readyField: AXUIElement?
        while ContinuousClock.now < deadline {
            if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == "com.apple.TextEdit" {
                let application = AXUIElementCreateApplication(app.processIdentifier)
                var raw: CFTypeRef?
                if AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &raw) == .success,
                   let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() {
                    let candidate = unsafeDowncast(raw, to: AXUIElement.self)
                    var rawValue: CFTypeRef?
                    if AXUIElementCopyAttributeValue(candidate, kAXValueAttribute as CFString, &rawValue) == .success,
                       rawValue as? String == fixture { readyField = candidate; break }
                }
            }
            await Task.yield()
        }
        guard let field = readyField else { throw CheckError.fixtureNotFocused }
        var value: CFTypeRef?
        var range = CFRange(location: 0, length: (fixture as NSString).length)
        guard let selection = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, selection) == .success else { throw CheckError.fixtureNotFocused }
        let clipboardCount = NSPasteboard.general.changeCount
        let clipboard = UntouchedClipboard()
        let coordinator = WorkflowCoordinator(selection: AXSelectionAccess(), engine: AppleTranslationEngine(), clipboard: clipboard)
        coordinator.onMilestone = { id, stage in
            if stage == "shortcut_received" { Diagnostics.shared.begin(id) }
            else { Diagnostics.shared.mark(id, stage) }
        }
        let start = ContinuousClock.now
        let result: WorkflowResult = try await withCheckedThrowingContinuation { continuation in
            coordinator.onStateChange = { state in
                switch state {
                case .showingResult(let result):
                    coordinator.onStateChange = nil
                    continuation.resume(returning: result)
                case .failed, .awaitingModelSetup:
                    coordinator.onStateChange = nil
                    continuation.resume(throwing: CheckError.workflowFailed)
                default: break
                }
            }
            coordinator.start(mode: .selection, source: "en", target: "it")
        }
        guard result.request.text == fixture, result.translation.source == "en", result.translation.target == "it",
              !result.translation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.translation.text != fixture, result.translation.text.hasPrefix("  "),
              result.translation.text.hasSuffix("  \n"), !result.wasReplaced,
              result.replacementFailure == nil, clipboard.reads == 0, clipboard.writes == 0,
              NSPasteboard.general.changeCount == clipboardCount else { throw CheckError.unexpectedState }
        value = nil
        guard AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value) == .success,
              value as? String == fixture else { throw CheckError.unexpectedState }
        let elapsed = start.duration(to: .now)
        let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        print("Real TextEdit AX capture → installed en-it TranslationSession → coordinator result PASS")
        print("Whitespace preservation, source document unchanged, zero clipboard adapter calls PASS")
        print("samples=1 app_cold=true model_cold=unknown configuration=Debug text_utf16=\((fixture as NSString).length) total_ms=\(ms)")
        coordinator.cancel()
    }
    enum CheckError: Error { case fixtureNotFocused, workflowFailed, unexpectedState }
}

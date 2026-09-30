import AppKit
import ApplicationServices
import TranslationCore

/// AX refs never cross an isolation boundary. Public Apple documentation does not
/// promise arbitrary-thread client access, so use the main actor conservatively.
@MainActor final class AXSelectionAccess: SelectionAccess {
    private struct Capture {
        let snapshot: SelectionSnapshot
        let element: AXUIElement
        let application: NSRunningApplication
        let fullValue: String?
    }
    private var captured: Capture?
    private let system = AXUIElementCreateSystemWide()
    private let clock = ContinuousClock()
    init() { AXUIElementSetMessagingTimeout(system, 0.04) }

    func capture(requestID: UUID) async throws -> SelectionSnapshot {
        captured = nil
        // Give status-item acknowledgement a chance to render before synchronous IPC.
        await Task.yield()
        try Task.checkCancellation()
        guard AXIsProcessTrusted() else { throw SelectionAccessIssue.permission }
        let deadline = clock.now.advanced(by: .milliseconds(250))
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw SelectionAccessIssue.noSelection
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let field = element(appElement, kAXFocusedUIElementAttribute) else { throw SelectionAccessIssue.noSelection }
        try check(deadline)
        guard let text = attribute(field, kAXSelectedTextAttribute) as? String, !text.isEmpty else {
            throw SelectionAccessIssue.noSelection
        }
        try check(deadline)
        let range = selectedRange(field)
        try check(deadline)
        let fullValue = attribute(field, kAXValueAttribute) as? String
        try check(deadline)
        let editable = writable(field)
        try check(deadline)
        guard NSWorkspace.shared.frontmostApplication == app, !app.isTerminated else { throw SelectionAccessIssue.changed }
        let snapshot = SelectionSnapshot(requestID: requestID, text: text, applicationBundleID: bundle,
                                         processID: app.processIdentifier, range: range, isEditable: editable)
        captured = Capture(snapshot: snapshot, element: field, application: app, fullValue: fullValue)
        return snapshot
    }

    func replace(snapshot: SelectionSnapshot, with text: String, requestID: UUID,
                 isCurrent: @escaping @MainActor () -> Bool) async throws {
        try Task.checkCancellation()
        guard isCurrent(), snapshot.requestID == requestID,
              let original = captured, original.snapshot.token == snapshot.token,
              original.snapshot.text == snapshot.text,
              original.snapshot.range == snapshot.range,
              snapshot.isEditable, let range = snapshot.range else { throw SelectionAccessIssue.insufficientContext }
        let deadline = clock.now.advanced(by: .milliseconds(250))
        guard AXIsProcessTrusted(), !original.application.isTerminated,
              NSWorkspace.shared.frontmostApplication == original.application,
              original.application.processIdentifier == snapshot.processID,
              original.application.bundleIdentifier == snapshot.applicationBundleID else { throw SelectionAccessIssue.changed }
        let app = AXUIElementCreateApplication(snapshot.processID)
        guard let focused = element(app, kAXFocusedUIElementAttribute), CFEqual(focused, original.element) else {
            throw SelectionAccessIssue.changed
        }
        try check(deadline)
        guard selectedRange(focused) == range else { throw SelectionAccessIssue.changed }
        try check(deadline)
        guard attribute(focused, kAXSelectedTextAttribute) as? String == snapshot.text else { throw SelectionAccessIssue.changed }
        try check(deadline)
        // If a document value was available at capture, reject intervening edits anywhere.
        if let value = original.fullValue {
            guard attribute(focused, kAXValueAttribute) as? String == value else { throw SelectionAccessIssue.changed }
            try check(deadline)
        }
        guard writable(focused) else { throw SelectionAccessIssue.insufficientContext }
        try check(deadline)
        // No suspension between the final request/focus check and the single AX write.
        // Validation and writing are separate IPC operations; cross-process races remain.
        guard isCurrent(), NSWorkspace.shared.frontmostApplication == original.application,
              !original.application.isTerminated else { throw SelectionAccessIssue.changed }
        if text != snapshot.text {
            guard AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFString) == .success else {
                throw SelectionAccessIssue.writeFailed
            }
        }
        captured = nil
    }

    private func check(_ deadline: ContinuousClock.Instant) throws {
        try Task.checkCancellation()
        guard clock.now < deadline else { throw SelectionAccessIssue.timeout }
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func element(_ source: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(source, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
    private func selectedRange(_ element: AXUIElement) -> SelectionRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range), range.location >= 0, range.length > 0 else { return nil }
        return SelectionRange(location: range.location, length: range.length)
    }
    private func writable(_ element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success && settable.boolValue
    }
}

enum SelectionAccessIssue: Error, LocalizedError {
    case permission, noSelection, changed, insufficientContext, writeFailed, timeout
    var errorDescription: String? {
        switch self {
        case .permission: "Enable SelectionTranslator in System Settings → Privacy & Security → Accessibility, then retry."
        case .noSelection: "This application did not expose selected text. Select text in another application or use Translate Clipboard."
        case .changed: "The source application, focused field, document, or selection changed. The translation is available to copy."
        case .insufficientContext: "This selection does not expose a writable text attribute and a reliable range. The translation is available to copy."
        case .writeFailed: "The source application rejected replacement. The translation is available to copy."
        case .timeout: "The source application did not respond within the Accessibility deadline. Retry or use Translate Clipboard."
        }
    }
}

// Run only with the disposable /tmp/SelectionTranslator-AX-fixture.txt document
// frontmost in TextEdit. Fails closed before touching any other document.
import AppKit
import ApplicationServices
import TranslationCore

@main struct AXFixtureCheck {
    @MainActor static func main() async throws {
        let fixture = "  Hello from SelectionTranslator.  \nA second paragraph for selection validation.\n"
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.apple.TextEdit" else { throw CheckError.fixtureNotFocused }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.04)
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else { throw CheckError.fixtureNotFocused }
        let field = unsafeDowncast(raw, to: AXUIElement.self)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value) == .success,
              value as? String == fixture else { throw CheckError.fixtureNotFocused }
        let clipboardCount = NSPasteboard.general.changeCount
        let access = AXSelectionAccess()
        var range = CFRange(location: 2, length: 5)
        let axRange = AXValueCreate(.cfRange, &range)!
        guard AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, axRange) == .success else { throw CheckError.fixtureNotFocused }
        let id = UUID()
        let snapshot = try await access.capture(requestID: id)
        guard snapshot.text == "Hello", snapshot.range == .init(location: 2, length: 5), snapshot.isEditable else { throw CheckError.unexpectedState }
        try await access.replace(snapshot: snapshot, with: "Ciao", requestID: id, isCurrent: { true })
        value = nil
        guard AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value) == .success,
              value as? String == fixture.replacingOccurrences(of: "Hello", with: "Ciao"),
              NSPasteboard.general.changeCount == clipboardCount else { throw CheckError.unexpectedState }
        range = CFRange(location: 2, length: 4)
        guard let secondRange = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, secondRange) == .success else { throw CheckError.unexpectedState }
        let secondID = UUID()
        let second = try await access.capture(requestID: secondID)
        range = CFRange(location: 0, length: 2)
        guard let changedRange = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, changedRange) == .success else { throw CheckError.unexpectedState }
        do {
            try await access.replace(snapshot: second, with: "Unsafe", requestID: secondID, isCurrent: { true })
            throw CheckError.unexpectedState
        } catch SelectionAccessIssue.changed { }
        do {
            try await access.replace(snapshot: second, with: "Unsafe", requestID: secondID, isCurrent: { false })
            throw CheckError.unexpectedState
        } catch SelectionAccessIssue.insufficientContext { }
        value = nil
        guard AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value) == .success,
              value as? String == fixture.replacingOccurrences(of: "Hello", with: "Ciao"),
              NSPasteboard.general.changeCount == clipboardCount else { throw CheckError.unexpectedState }
        // A selection with changed text must fail even when its range stays identical.
        guard AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, secondRange) == .success else { throw CheckError.unexpectedState }
        let textID = UUID()
        let textSnapshot = try await access.capture(requestID: textID)
        guard AXUIElementSetAttributeValue(field, kAXSelectedTextAttribute as CFString, "Hola" as CFString) == .success,
              AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, secondRange) == .success else { throw CheckError.unexpectedState }
        do {
            try await access.replace(snapshot: textSnapshot, with: "Unsafe", requestID: textID, isCurrent: { true })
            throw CheckError.unexpectedState
        } catch SelectionAccessIssue.changed { }
        let focusID = UUID()
        let focusSnapshot = try await access.capture(requestID: focusID)
        try appleScript("tell application \"Finder\" to activate")
        do {
            try await access.replace(snapshot: focusSnapshot, with: "Unsafe", requestID: focusID, isCurrent: { true })
            throw CheckError.unexpectedState
        } catch SelectionAccessIssue.changed { }
        try appleScript("tell application \"TextEdit\" to activate")
        let closeID = UUID()
        let closeSnapshot = try await access.capture(requestID: closeID)
        try appleScript("tell application \"TextEdit\" to close document \"SelectionTranslator-AX-fixture.txt\" saving no")
        do {
            try await access.replace(snapshot: closeSnapshot, with: "Unsafe", requestID: closeID, isCurrent: { true })
            throw CheckError.unexpectedState
        } catch SelectionAccessIssue.changed { }
        guard NSPasteboard.general.changeCount == clipboardCount else { throw CheckError.unexpectedState }
        print("TextEdit disposable fixture: changed text, application focus, and source window closure rejection PASS")
        print("TextEdit disposable fixture: changed range and stale request rejection PASS")
        print("TextEdit disposable fixture: selected text/range capture, exact replacement, clipboard preservation PASS")
    }
    @MainActor private static func appleScript(_ source: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CheckError.unexpectedState }
    }
    enum CheckError: Error { case fixtureNotFocused, unexpectedState }
}

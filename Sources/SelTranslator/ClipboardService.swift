import AppKit
import Carbon.HIToolbox.Events

@MainActor
final class ClipboardService {
    @discardableResult
    func copy(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    func captureSelectedTextByCopyShortcut() async -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        guard triggerCopyShortcut() else {
            return nil
        }

        let timeoutNanoseconds: UInt64 = 450_000_000
        let pollIntervalNanoseconds: UInt64 = 25_000_000
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if pasteboard.changeCount != initialChangeCount {
                guard let text = pasteboard.string(forType: .string) else {
                    return nil
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : text
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return nil
    }

    private func triggerCopyShortcut() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
            )
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

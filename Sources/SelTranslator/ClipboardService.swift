import AppKit

final class ClipboardService {
    @discardableResult
    func copy(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

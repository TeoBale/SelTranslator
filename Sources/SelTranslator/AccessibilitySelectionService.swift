import ApplicationServices
import Foundation

struct SelectedTextSnapshot {
    let element: AXUIElement
    let selectedText: String
    let selectedRange: CFRange
    let isEditable: Bool
}

enum SelectionServiceError: LocalizedError {
    case noFocusedElement
    case noSelectedText

    var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No focused element found."
        case .noSelectedText:
            return "Select some text first."
        }
    }
}

final class AccessibilitySelectionService {
    func hasPermission(prompt: Bool) -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options = [promptKey: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func captureSelection() throws -> SelectedTextSnapshot {
        let focused = try focusedElement()

        guard
            let selectedText = copyStringAttribute(
                for: focused,
                key: kAXSelectedTextAttribute as CFString
            ),
            !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw SelectionServiceError.noSelectedText
        }

        let selectedRange = copySelectedRange(for: focused, fallbackLength: selectedText.utf16.count)
        let editable = isEditable(element: focused)
        return SelectedTextSnapshot(
            element: focused,
            selectedText: selectedText,
            selectedRange: selectedRange,
            isEditable: editable
        )
    }

    func replaceSelectedText(in snapshot: SelectedTextSnapshot, with translatedText: String) -> Bool {
        let selectedTextAttribute = kAXSelectedTextAttribute as CFString
        guard isAttributeSettable(selectedTextAttribute, for: snapshot.element) else {
            Diagnostics.info("AX selected text attribute is not settable; skipping replace.")
            return false
        }

        let result = AXUIElementSetAttributeValue(
            snapshot.element,
            selectedTextAttribute,
            translatedText as CFTypeRef
        )
        Diagnostics.info("AX replace result: \(result.rawValue)")
        return result == .success
    }

    private func focusedElement() throws -> AXUIElement {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard result == .success, let element = focusedValue else {
            throw SelectionServiceError.noFocusedElement
        }
        return element as! AXUIElement
    }

    private func copyStringAttribute(for element: AXUIElement, key: CFString) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, key, &value)
        guard error == .success else {
            return nil
        }
        return value as? String
    }

    private func copySelectedRange(for element: AXUIElement, fallbackLength: Int) -> CFRange {
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard result == .success, let value = rangeValue else {
            return CFRange(location: 0, length: fallbackLength)
        }

        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return CFRange(location: 0, length: fallbackLength)
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return CFRange(location: 0, length: fallbackLength)
        }

        var range = CFRange(location: 0, length: fallbackLength)
        if AXValueGetValue(axValue, .cfRange, &range) {
            return range
        }
        return CFRange(location: 0, length: fallbackLength)
    }

    private func isEditable(element: AXUIElement) -> Bool {
        let editableAttribute = "AXEditable" as CFString
        var editableValue: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(
            element,
            editableAttribute,
            &editableValue
        )
        if editableResult == .success, let number = editableValue as? NSNumber {
            return number.boolValue
        }

        return isAttributeSettable(kAXSelectedTextAttribute as CFString, for: element)
    }

    private func isAttributeSettable(_ attribute: CFString, for element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return result == .success && settable.boolValue
    }
}

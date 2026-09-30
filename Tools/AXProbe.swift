// Read-only capability probe. Never prints selected/document text or writes AX state.
import AppKit
import ApplicationServices

let trusted = AXIsProcessTrusted()
print("accessibilityTrusted=\(trusted)")
let system = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(system, 0.04)
let candidates = ["com.apple.TextEdit", "com.apple.Notes", "com.apple.Safari", "com.google.Chrome", "com.microsoft.VSCode", "com.apple.Preview"]
for identifier in candidates {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
    print("application=\(identifier) installed=\(NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) != nil) running=\(!apps.isEmpty)")
    guard trusted, let app = apps.first else { continue }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.04)
    var focused: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focused)
    guard status == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
        print("focusedElementStatus=\(status.rawValue)")
        continue
    }
    let field = unsafeDowncast(focused, to: AXUIElement.self)
    AXUIElementSetMessagingTimeout(field, 0.04)
    for attribute in [kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute, kAXValueAttribute] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(field, attribute as CFString, &value)
        var writable = DarwinBoolean(false)
        let writableStatus = AXUIElementIsAttributeSettable(field, attribute as CFString, &writable)
        print("attribute=\(attribute) exposed=\(result == .success && value != nil) writable=\(writableStatus == .success && writable.boolValue) status=\(result.rawValue)")
    }
}

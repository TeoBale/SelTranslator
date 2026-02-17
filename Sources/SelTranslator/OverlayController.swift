import AppKit

@MainActor
final class OverlayController {
    enum Kind {
        case success
        case error
    }

    private var window: NSPanel?
    private var messageLabel: NSTextField?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, kind: Kind) {
        ensureWindow()
        guard let window, let label = messageLabel else { return }

        label.stringValue = message
        if let layer = window.contentView?.layer {
            let color: NSColor = (kind == .success) ? .systemGreen : .systemRed
            layer.backgroundColor = color.withAlphaComponent(0.92).cgColor
        }

        if let screen = NSScreen.main {
            let size = NSSize(width: 360, height: 56)
            let origin = NSPoint(
                x: screen.visibleFrame.midX - (size.width / 2),
                y: screen.visibleFrame.maxY - size.height - 64
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }

        dismissTask?.cancel()
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            window.animator().alphaValue = 1
        }

        dismissTask = Task { [weak window] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                guard let window else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    window.animator().alphaValue = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    window.orderOut(nil)
                }
            }
        }
    }

    private func ensureWindow() {
        if window != nil {
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let content = NSView(frame: panel.contentView!.bounds)
        content.wantsLayer = true
        content.layer?.cornerRadius = 12
        content.layer?.masksToBounds = true
        panel.contentView = content

        let label = NSTextField(labelWithString: "")
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        window = panel
        messageLabel = label
    }
}

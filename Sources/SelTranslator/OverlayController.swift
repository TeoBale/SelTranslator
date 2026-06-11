import AppKit

private final class ToastShadowView: NSView {
    var cornerRadius: CGFloat = 22

    override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }
}

@MainActor
final class OverlayController {
    private enum Metrics {
        static let contentHeight: CGFloat = 64
        static let shadowMargin: CGFloat = 10
        static let cornerRadius: CGFloat = 22
    }

    enum Kind {
        case success
        case error

        var symbolName: String {
            switch self {
            case .success:
                return "translate"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }

        var accentColor: NSColor {
            switch self {
            case .success:
                return .controlAccentColor
            case .error:
                return .systemRed
            }
        }
    }

    private var window: NSPanel?
    private var iconBadgeView: NSView?
    private var iconImageView: NSImageView?
    private var messageLabel: NSTextField?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, kind: Kind) {
        ensureWindow()
        guard let window, let label = messageLabel, let iconBadgeView, let iconImageView else { return }

        label.stringValue = message
        iconBadgeView.layer?.backgroundColor = kind.accentColor.withAlphaComponent(0.16).cgColor
        iconBadgeView.layer?.borderColor = kind.accentColor.withAlphaComponent(0.24).cgColor
        iconImageView.contentTintColor = kind.accentColor
        let image = NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        iconImageView.image = image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )

        if let screen = NSScreen.main {
            let finalFrame = frame(for: message, on: screen)
            let startFrame = finalFrame.offsetBy(dx: 0, dy: 8)
            window.setFrame(startFrame, display: true)

            dismissTask?.cancel()
            window.alphaValue = 0
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
                window.animator().setFrame(finalFrame, display: true)
            }
        } else {
            dismissTask?.cancel()
            window.alphaValue = 0
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }

        dismissTask = Task { [weak window] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                guard let window else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.22
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().alphaValue = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
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
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 360 + (Metrics.shadowMargin * 2),
                height: Metrics.contentHeight + (Metrics.shadowMargin * 2)
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let root = NSView(frame: panel.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = root

        let shadowView = ToastShadowView()
        shadowView.cornerRadius = Metrics.cornerRadius
        shadowView.wantsLayer = true
        shadowView.layer?.backgroundColor = NSColor.clear.cgColor
        shadowView.layer?.shadowColor = NSColor.black.cgColor
        shadowView.layer?.shadowOpacity = 0.22
        shadowView.layer?.shadowRadius = 18
        shadowView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(shadowView)

        let content = NSVisualEffectView()
        content.material = .popover
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = Metrics.cornerRadius
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.22).cgColor
        content.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(content)

        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 16
        badge.layer?.cornerCurve = .continuous
        badge.layer?.borderWidth = 1
        badge.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(badge)

        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(icon)

        let label = NSTextField(labelWithString: "")
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)

        NSLayoutConstraint.activate([
            shadowView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: Metrics.shadowMargin),
            shadowView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -Metrics.shadowMargin),
            shadowView.topAnchor.constraint(equalTo: root.topAnchor, constant: Metrics.shadowMargin),
            shadowView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -Metrics.shadowMargin),

            content.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            content.topAnchor.constraint(equalTo: shadowView.topAnchor),
            content.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),

            badge.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            badge.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 32),
            badge.heightAnchor.constraint(equalToConstant: 32),

            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        window = panel
        iconBadgeView = badge
        iconImageView = icon
        messageLabel = label
    }

    private func frame(for message: String, on screen: NSScreen) -> NSRect {
        let maxWidth = max(240, min(screen.visibleFrame.width - 80, 560))
        let textWidth = (message as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 15, weight: .medium)]
        ).width
        let contentWidth = min(max(ceil(textWidth) + 82, 292), maxWidth)
        let size = NSSize(
            width: contentWidth + (Metrics.shadowMargin * 2),
            height: Metrics.contentHeight + (Metrics.shadowMargin * 2)
        )
        let origin = NSPoint(
            x: screen.visibleFrame.midX - (size.width / 2),
            y: screen.visibleFrame.maxY - Metrics.contentHeight - Metrics.shadowMargin - 52
        )
        return NSRect(origin: origin, size: size)
    }
}

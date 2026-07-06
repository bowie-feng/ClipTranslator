import AppKit
import SwiftUI

/// 选中文字后出现的小型浮动触发按钮，点击后才开始翻译
@MainActor
final class TranslationButton {
    static let shared = TranslationButton()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<TriggerButtonView>?
    private var dismissMonitor: Any?
    private var autoDismissTimer: Timer?

    private var onTrigger: (() -> Void)?

    var isVisible: Bool { panel != nil }

    private init() {}

    // MARK: - Show

    func show(onTrigger: @escaping () -> Void) {
        dismiss()

        self.onTrigger = onTrigger

        let view = TriggerButtonView(
            onTap: { [weak self] in
                self?.handleTrigger()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hosting = NSHostingController(rootView: view)

        let size: CGFloat = 40
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.contentViewController = hosting

        // Position near mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let screen = screenContaining(point: mouseLocation) ?? NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = screen.visibleFrame

        let offset: CGFloat = 8
        var origin = NSPoint(
            x: mouseLocation.x + offset,
            y: mouseLocation.y - offset - size
        )

        // Keep within screen bounds
        if origin.x + size > visibleFrame.maxX {
            origin.x = visibleFrame.maxX - size - 4
        }
        if origin.y < visibleFrame.minY {
            origin.y = mouseLocation.y + offset
        }
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX + 4
        }
        if origin.y + size > visibleFrame.maxY {
            origin.y = visibleFrame.maxY - size - 4
        }

        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: size, height: size), display: false)
        panel.orderFrontRegardless()

        // Click-outside / Escape to dismiss
        setupDismissMonitor(panel: panel)

        // Auto-dismiss after 5 seconds
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }

        self.panel = panel
        self.hostingController = hosting
    }

    // MARK: - Dismiss

    func dismiss() {
        if let monitor = dismissMonitor {
            NSEvent.removeMonitor(monitor)
            dismissMonitor = nil
        }
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        panel?.close()
        panel = nil
        hostingController = nil
        onTrigger = nil
        SelectionMonitor.shared.clearLastSelectedText()
    }

    // MARK: - Private

    private func handleTrigger() {
        let action = onTrigger
        dismiss()
        action?()
    }

    private func setupDismissMonitor(panel: NSPanel) {
        if let monitor = dismissMonitor {
            NSEvent.removeMonitor(monitor)
            dismissMonitor = nil
        }

        dismissMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            guard let self = self, self.panel != nil else { return event }

            // Escape key
            if event.type == .keyDown && event.keyCode == 53 {
                self.dismiss()
                return nil
            }

            // Click or scroll outside the button → dismiss
            if event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .scrollWheel {
                let clickLocation = NSEvent.mouseLocation
                // Expand the hit region slightly to account for the button shadow
                let expandedFrame = panel.frame.insetBy(dx: -8, dy: -8)
                if !NSPointInRect(clickLocation, expandedFrame) {
                    self.dismiss()
                    return event
                }
            }

            return event
        }
    }

    private func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            NSPointInRect(point, screen.frame)
        }
    }
}

// MARK: - Trigger Button View

struct TriggerButtonView: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(isHovering ? 0.95 : 0.88))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)

                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

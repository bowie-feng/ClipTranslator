import AppKit
import SwiftUI

@MainActor
final class TranslationPopup {
    static let shared = TranslationPopup()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<PopupContentView>?
    private var globalDismissMonitor: Any?
    private var localDismissMonitor: Any?

    var isVisible: Bool { panel != nil }

    private init() {}

    // MARK: - Show (loading state)

    func showLoading(originalText: String, sourceLanguage: String, targetLanguage: String) {
        dismiss()

        let contentView = PopupContentView(
            originalText: originalText,
            translatedText: "",
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isLoading: true,
            isError: false,
            onCopy: { [weak self] in
                self?.copyToClipboard("")
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        present(contentView: contentView)
    }

    // MARK: - Show (result state)

    func show(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        isError: Bool
    ) {
        // If panel already exists, update it in-place
        if panel != nil, let hosting = hostingController {
            let contentView = PopupContentView(
                originalText: originalText,
                translatedText: translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                isLoading: false,
                isError: isError,
                onCopy: { [weak self] in
                    self?.copyToClipboard(translatedText)
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                }
            )
            hosting.rootView = contentView
            return
        }

        // No existing panel — create one
        let contentView = PopupContentView(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isLoading: false,
            isError: isError,
            onCopy: { [weak self] in
                self?.copyToClipboard(translatedText)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        present(contentView: contentView)
    }

    // MARK: - Present

    private func present(contentView: PopupContentView) {
        let hosting = NSHostingController(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 250),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = true
        panel.contentMinSize = NSSize(width: 280, height: 180)
        panel.contentMaxSize = NSSize(width: 600, height: 800)
        panel.contentViewController = hosting

        // Position near mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let screen = screenContaining(point: mouseLocation) ?? NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = screen.visibleFrame

        let panelWidth: CGFloat = 360
        let panelHeight: CGFloat = min(300, hosting.view.fittingSize.height + 20)
        var origin = NSPoint(
            x: mouseLocation.x + 16,
            y: mouseLocation.y - 16 - panelHeight
        )

        // Keep within screen bounds
        if origin.x + panelWidth > visibleFrame.maxX {
            origin.x = visibleFrame.maxX - panelWidth - 8
        }
        if origin.y < visibleFrame.minY {
            origin.y = mouseLocation.y + 16
        }
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX + 8
        }
        if origin.y + panelHeight > visibleFrame.maxY {
            origin.y = visibleFrame.maxY - panelHeight - 8
        }

        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: panelWidth, height: panelHeight), display: false)
        panel.orderFrontRegardless()

        // Setup dismiss monitors
        setupDismissMonitors(panel: panel)

        self.panel = panel
        self.hostingController = hosting
    }

    // MARK: - Dismiss

    func dismiss() {
        removeMonitors()
        panel?.close()
        panel = nil
        hostingController = nil
        SelectionMonitor.shared.clearLastSelectedText()
    }

    // MARK: - Dismiss Monitors

    private func setupDismissMonitors(panel: NSPanel) {
        removeMonitors()

        // Local monitor: handles Escape key and clicks WITHIN our app that are outside the panel
        localDismissMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self, self.panel != nil else { return event }

            if event.type == .keyDown && event.keyCode == 53 {
                self.dismiss()
                return nil
            }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let clickLocation = NSEvent.mouseLocation
                if !NSPointInRect(clickLocation, panel.frame) {
                    self.dismiss()
                    return event
                }
            }

            return event
        }

        // Global monitor: handles clicks in OTHER apps to dismiss the panel
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] event in
            let clickLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                guard let self = self, let panel = self.panel else { return }
                let expandedFrame = panel.frame.insetBy(dx: -4, dy: -4)
                if !NSPointInRect(clickLocation, expandedFrame) {
                    self.dismiss()
                }
            }
        }
    }

    private func removeMonitors() {
        if let monitor = localDismissMonitor {
            NSEvent.removeMonitor(monitor)
            localDismissMonitor = nil
        }
        if let monitor = globalDismissMonitor {
            NSEvent.removeMonitor(monitor)
            globalDismissMonitor = nil
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            NSPointInRect(point, screen.frame)
        }
    }
}

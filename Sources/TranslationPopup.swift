import AppKit
import SwiftUI

@MainActor
final class TranslationPopup {
    static let shared = TranslationPopup()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<PopupContentView>?
    private var globalDismissMonitor: Any?
    private var localDismissMonitor: Any?
    private var currentOriginalText: String?
    private var onRetranslate: ((String, String) -> Void)?
    private var onToggleMode: (() -> Void)?
    private var isDictionaryMode = false

    private let maxPanelHeight: CGFloat = 600

    var isVisible: Bool { panel != nil }

    private init() {}

    // MARK: - Show (loading state)

    func showLoading(
        originalText: String,
        sourceLanguage: String,
        targetLanguage: String,
        isDictionaryMode: Bool = false,
        onRetranslate: @escaping (String, String) -> Void,
        onToggleMode: (() -> Void)? = nil
    ) {
        dismiss()

        currentOriginalText = originalText
        self.onRetranslate = onRetranslate
        self.onToggleMode = onToggleMode
        self.isDictionaryMode = isDictionaryMode

        let contentView = PopupContentView(
            originalText: originalText,
            translatedText: "",
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            isLoading: true,
            isError: false,
            isDictionaryMode: isDictionaryMode,
            onCopy: { [weak self] in
                self?.copyToClipboard("")
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            },
            onLanguageChange: { [weak self] newLanguage in
                self?.handleLanguageChange(newLanguage)
            },
            onToggleMode: onToggleMode
        )

        present(contentView: contentView)
    }

    // MARK: - Show (result state)

    func show(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        isError: Bool,
        isDictionaryMode: Bool = false
    ) {
        currentOriginalText = originalText

        // If panel already exists, update it in-place
        if panel != nil, let hosting = hostingController {
            let contentView = PopupContentView(
                originalText: originalText,
                translatedText: translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                isLoading: false,
                isError: isError,
                isDictionaryMode: isDictionaryMode,
                onCopy: { [weak self] in
                    self?.copyToClipboard(translatedText)
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                },
                onLanguageChange: { [weak self] newLanguage in
                    self?.handleLanguageChange(newLanguage)
                },
                onToggleMode: onToggleMode
            )
            hosting.rootView = contentView
            resizeToFit()
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
            isDictionaryMode: isDictionaryMode,
            onCopy: { [weak self] in
                self?.copyToClipboard(translatedText)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            },
            onLanguageChange: { [weak self] newLanguage in
                self?.handleLanguageChange(newLanguage)
            },
            onToggleMode: onToggleMode
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
        panel.contentMaxSize = NSSize(width: 600, height: maxPanelHeight)
        panel.contentViewController = hosting

        // Position near mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let screen = screenContaining(point: mouseLocation) ?? NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = screen.visibleFrame

        let panelWidth: CGFloat = 360
        // Use a reasonable initial height; resizeToFit will adjust after layout
        let panelHeight: CGFloat = 250
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

        // Let SwiftUI layout, then resize to fit content
        resizeToFit()
    }

    // MARK: - Resize

    private func resizeToFit() {
        guard let panel = panel, let hosting = hostingController else { return }

        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        let padding: CGFloat = 4
        let newHeight = min(fitting.height + padding, maxPanelHeight)
        let newWidth = max(panel.frame.width, fitting.width + padding)

        var newFrame = panel.frame
        let heightDelta = newHeight - newFrame.height

        newFrame.size = NSSize(width: newWidth, height: newHeight)
        newFrame.origin.y -= heightDelta // expand upward

        // Clamp to screen bounds
        if let screen = panel.screen {
            let visible = screen.visibleFrame
            if newFrame.maxX > visible.maxX { newFrame.origin.x = visible.maxX - newFrame.width - 8 }
            if newFrame.minY < visible.minY { newFrame.origin.y = visible.minY + 8 }
            if newFrame.minX < visible.minX { newFrame.origin.x = visible.minX + 8 }
            if newFrame.maxY > visible.maxY { newFrame.origin.y = visible.maxY - newFrame.height - 8 }
        }

        panel.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Language Change

    private func handleLanguageChange(_ newLanguage: String) {
        guard let originalText = currentOriginalText else { return }
        onRetranslate?(originalText, newLanguage)
    }

    // MARK: - Dismiss

    func dismiss() {
        removeMonitors()
        panel?.close()
        panel = nil
        hostingController = nil
        currentOriginalText = nil
        onRetranslate = nil
        onToggleMode = nil
        isDictionaryMode = false
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

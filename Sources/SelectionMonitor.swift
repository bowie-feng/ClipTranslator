import AppKit

@MainActor
final class SelectionMonitor {
    static let shared = SelectionMonitor()

    var isEnabled = true

    private var eventMonitor: Any?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastSelectedText: String?
    private let minTextLength = 2
    private let maxTextLength = 5000
    private let debounceInterval: TimeInterval = 0.4

    private init() {}

    // MARK: - Start / Stop

    func start() {
        guard eventMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = .leftMouseUp
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseUp()
            }
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    // MARK: - Debounce

    private func handleMouseUp() {
        guard isEnabled else { return }

        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.detectSelection()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + debounceInterval,
            execute: workItem
        )
    }

    // MARK: - Detect Selection

    private func detectSelection() {
        TranslationButton.shared.dismiss()

        let clipboard = ClipboardManager.shared

        let snapshot = clipboard.save()
        defer { clipboard.restore(snapshot) }

        guard let selectedText = clipboard.simulateCopyAndRead() else {
            return
        }

        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minTextLength, trimmed.count <= maxTextLength else {
            return
        }
        guard trimmed != lastSelectedText else {
            return
        }

        lastSelectedText = trimmed

        TranslationButton.shared.show { [weak self] in
            self?.translate(text: trimmed)
        }
    }

    // MARK: - Translation

    private func translate(text: String) {
        let settings = SettingsStore.shared

        // 1. Show popup immediately with loading state
        TranslationPopup.shared.showLoading(
            originalText: text,
            sourceLanguage: settings.autoDetectSource
                ? TranslationService.shared.detectSourceLanguage(text) ?? "auto"
                : "auto",
            targetLanguage: settings.targetLanguage
        )

        // 2. Call API in background
        Task {
            let result = await TranslationService.shared.translate(
                text: text,
                targetLanguage: settings.targetLanguage,
                provider: settings.provider
            )

            // 3. Update the existing popup with result
            await MainActor.run {
                TranslationPopup.shared.show(
                    originalText: text,
                    translatedText: result.translatedText,
                    sourceLanguage: result.sourceLanguage,
                    targetLanguage: result.targetLanguage,
                    isError: result.isError
                )
            }
        }
    }
}

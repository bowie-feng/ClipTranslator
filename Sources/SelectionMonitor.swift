import AppKit

@MainActor
final class SelectionMonitor {
    static let shared = SelectionMonitor()

    var isEnabled = true

    private enum TranslationMode {
        case translate
        case dictionary
    }

    private var eventMonitor: Any?
    private var debounceTask: Task<Void, Never>?
    private var lastSelectedText: String?
    private var mouseDownLocation: NSPoint?
    private var currentTranslationTask: Task<Void, Never>?
    private var retranslateDebounceTask: Task<Void, Never>?
    private var currentMode: TranslationMode = .translate
    private let minTextLength = 2
    private let maxTextLength = 5000
    private let minDragDistance: CGFloat = 5.0
    private let debounceInterval: TimeInterval = 0.6
    private let retranslateDebounceInterval: UInt64 = 300_000_000 // 300ms in nanoseconds

    private init() {}

    // MARK: - Start / Stop

    func start() {
        guard eventMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp]
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            DispatchQueue.main.async {
                switch event.type {
                case .leftMouseDown:
                    self?.mouseDownLocation = NSEvent.mouseLocation
                case .leftMouseUp:
                    self?.handleMouseUp()
                default:
                    break
                }
            }
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        debounceTask?.cancel()
        debounceTask = nil
        retranslateDebounceTask?.cancel()
        retranslateDebounceTask = nil
    }

    // MARK: - Debounce

    private func handleMouseUp() {
        guard isEnabled else { return }

        // Never start detection while our own UI is visible
        guard !TranslationButton.shared.isVisible,
              !TranslationPopup.shared.isVisible else {
            mouseDownLocation = nil
            return
        }

        // Require actual drag movement — ignore plain clicks
        if let down = mouseDownLocation {
            let up = NSEvent.mouseLocation
            let dx = up.x - down.x
            let dy = up.y - down.y
            let distance = hypot(dx, dy)
            guard distance >= minDragDistance else {
                mouseDownLocation = nil
                return
            }
        }
        mouseDownLocation = nil

        debounceTask?.cancel()

        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.debounceInterval ?? 0.6) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.detectSelection()
        }
        debounceTask = task
    }

    // MARK: - Detect Selection

    private func detectSelection() async {
        TranslationButton.shared.dismiss()

        let clipboard = ClipboardManager.shared

        let snapshot = clipboard.save()
        defer { clipboard.restore(snapshot) }

        guard let selectedText = await clipboard.simulateCopyAndRead() else {
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

    // MARK: - Last Selection Reset

    func clearLastSelectedText() {
        lastSelectedText = nil
    }

    // MARK: - Translation

    private func translate(text: String) {
        let settings = SettingsStore.shared

        // Auto-detect: single word → dictionary mode, phrase → translation mode
        currentMode = isSingleWord(text) ? .dictionary : .translate
        let isDict = currentMode == .dictionary

        // 1. Show popup immediately with loading state
        TranslationPopup.shared.showLoading(
            originalText: text,
            sourceLanguage: settings.autoDetectSource
                ? TranslationService.shared.detectSourceLanguage(text) ?? "auto"
                : "auto",
            targetLanguage: settings.targetLanguage,
            isDictionaryMode: isDict,
            onRetranslate: { [weak self] originalText, newLanguage in
                self?.retranslate(text: originalText, targetLanguage: newLanguage)
            },
            onToggleMode: isSingleWord(text) ? { [weak self] in
                self?.toggleMode()
            } : nil
        )

        // 2. Call API in background
        performTranslation(text: text, targetLanguage: settings.targetLanguage)
    }

    private func retranslate(text: String, targetLanguage: String) {
        // Cancel any pending retranslate debounce
        retranslateDebounceTask?.cancel()

        // Show loading state in-place immediately for responsiveness
        let settings = SettingsStore.shared
        let isDict = currentMode == .dictionary
        TranslationPopup.shared.showLoading(
            originalText: text,
            sourceLanguage: settings.autoDetectSource
                ? TranslationService.shared.detectSourceLanguage(text) ?? "auto"
                : "auto",
            targetLanguage: targetLanguage,
            isDictionaryMode: isDict,
            onRetranslate: { [weak self] originalText, newLanguage in
                self?.retranslate(text: originalText, targetLanguage: newLanguage)
            },
            onToggleMode: isSingleWord(text) ? { [weak self] in
                self?.toggleMode()
            } : nil
        )

        // Debounce the actual API call to avoid rapid-fire requests
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.retranslateDebounceInterval ?? 300_000_000)
            guard !Task.isCancelled else { return }
            self?.performTranslation(text: text, targetLanguage: targetLanguage)
        }
        retranslateDebounceTask = task
    }

    private func toggleMode() {
        guard let text = lastSelectedText else { return }
        currentMode = (currentMode == .dictionary) ? .translate : .dictionary

        // Show loading and re-fetch
        let settings = SettingsStore.shared
        let isDict = currentMode == .dictionary
        TranslationPopup.shared.showLoading(
            originalText: text,
            sourceLanguage: settings.autoDetectSource
                ? TranslationService.shared.detectSourceLanguage(text) ?? "auto"
                : "auto",
            targetLanguage: settings.targetLanguage,
            isDictionaryMode: isDict,
            onRetranslate: { [weak self] originalText, newLanguage in
                self?.retranslate(text: originalText, targetLanguage: newLanguage)
            },
            onToggleMode: { [weak self] in
                self?.toggleMode()
            }
        )

        performTranslation(text: text, targetLanguage: settings.targetLanguage)
    }

    private func performTranslation(text: String, targetLanguage: String) {
        // Cancel any in-flight translation
        currentTranslationTask?.cancel()

        let settings = SettingsStore.shared
        let isDict = currentMode == .dictionary

        if isDict {
            currentTranslationTask = Task {
                let result = await TranslationService.shared.lookupWord(
                    word: text,
                    targetLanguage: targetLanguage,
                    provider: settings.provider
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    TranslationPopup.shared.show(
                        originalText: text,
                        translatedText: result.translatedText,
                        sourceLanguage: result.sourceLanguage,
                        targetLanguage: result.targetLanguage,
                        isError: result.isError,
                        isDictionaryMode: true
                    )
                }
            }
        } else {
            currentTranslationTask = Task {
                let result = await TranslationService.shared.translate(
                    text: text,
                    targetLanguage: targetLanguage,
                    provider: settings.provider
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    TranslationPopup.shared.show(
                        originalText: text,
                        translatedText: result.translatedText,
                        sourceLanguage: result.sourceLanguage,
                        targetLanguage: result.targetLanguage,
                        isError: result.isError,
                        isDictionaryMode: false
                    )
                }
            }
        }
    }
}

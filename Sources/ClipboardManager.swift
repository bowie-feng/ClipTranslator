import AppKit

@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()
    private init() {}

    // MARK: - Snapshot

    struct ClipboardSnapshot {
        let items: [NSPasteboardItem]
        let changeCount: Int
        let explicitString: String?
    }

    func save() -> ClipboardSnapshot {
        let pb = NSPasteboard.general
        let explicitString = pb.string(forType: .string)
        let items = (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
        return ClipboardSnapshot(items: items, changeCount: pb.changeCount, explicitString: explicitString)
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if !snapshot.items.isEmpty {
            pb.writeObjects(snapshot.items)
        }
        // Restore string representation if items didn't carry it themselves
        if let string = snapshot.explicitString, pb.string(forType: .string) == nil {
            pb.setString(string, forType: .string)
        }
    }

    // MARK: - Copy Simulation

    /// Simulates Cmd+C and returns whatever text landed on the pasteboard.
    /// Returns nil if the pasteboard didn't change (nothing was selected).
    func simulateCopyAndRead(delayMilliseconds: Int = 50) -> String? {
        let pb = NSPasteboard.general
        let beforeChangeCount = pb.changeCount

        // Simulate Cmd+C via CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Let the run loop process the Cmd+C event we just posted
        RunLoop.current.run(until: Date(timeIntervalSinceNow: Double(delayMilliseconds) / 1000.0))

        // Check if pasteboard actually changed (confirms something was selected)
        guard pb.changeCount != beforeChangeCount else {
            return nil
        }

        return pb.string(forType: .string)
    }
}

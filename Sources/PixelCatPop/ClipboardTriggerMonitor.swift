import AppKit

@MainActor
final class ClipboardTriggerMonitor {
    var onDoubleCopy: (() -> Void)?

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var lastCopyAt: Date?
    private var lastCopiedText: String?
    private var lastTriggerAt: Date?
    private var lastPasteboardChangeCount = NSPasteboard.general.changeCount
    private var pollTimer: Timer?
    private let triggerInterval: TimeInterval = 0.8
    private let triggerCooldown: TimeInterval = 0.45

    func start() {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        globalMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              event.charactersIgnoringModifiers?.lowercased() == "c" else {
            return
        }

        let now = Date()
        if let lastCopyAt, now.timeIntervalSince(lastCopyAt) <= triggerInterval {
            self.lastCopyAt = nil
            triggerAfterPasteboardUpdate()
        } else {
            lastCopyAt = now
        }
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount

        guard let text = comparableClipboardText(from: pasteboard) else {
            return
        }

        let now = Date()
        if text == lastCopiedText,
           let lastCopyAt,
           now.timeIntervalSince(lastCopyAt) <= triggerInterval {
            self.lastCopyAt = nil
            lastCopiedText = nil
            trigger()
        } else {
            lastCopiedText = text
            lastCopyAt = now
        }
    }

    private func triggerAfterPasteboardUpdate() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            trigger()
        }
    }

    private func trigger() {
        let now = Date()
        if let lastTriggerAt, now.timeIntervalSince(lastTriggerAt) < triggerCooldown {
            return
        }
        lastTriggerAt = now
        onDoubleCopy?()
    }

    private func comparableClipboardText(from pasteboard: NSPasteboard) -> String? {
        if let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        if let fileURL = pasteboard.string(forType: .fileURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fileURL.isEmpty {
            return fileURL
        }

        return nil
    }
}

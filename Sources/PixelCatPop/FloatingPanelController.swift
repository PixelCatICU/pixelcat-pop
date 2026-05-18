import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject {
    private let panelSize = NSSize(width: FloatingPanelView.panelWidth, height: 210)
    private let viewModel: TranslationViewModel
    private let settings: SettingsStore
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var frameObserver: NSKeyValueObservation?

    init(viewModel: TranslationViewModel, settings: SettingsStore) {
        self.viewModel = viewModel
        self.settings = settings
    }

    func showInput() {
        ensurePanel()
        viewModel.isPinned = false
        viewModel.resetForManualInput()
        positionPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitor()
    }

    func show(text: String) {
        ensurePanel()
        viewModel.isPinned = false
        viewModel.loadAndTranslate(text)
        positionPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitor()
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let content = FloatingPanelView(viewModel: viewModel, settings: settings) { [weak self] height in
            self?.resizePanel(to: NSSize(width: FloatingPanelView.panelWidth, height: height))
        }
        let hosting = NSHostingView(rootView: content)
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "PixelCat Pop"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        frameObserver = hosting.observe(\.fittingSize, options: [.new]) { [weak self] hosting, _ in
            Task { @MainActor in
                self?.resizePanel(to: hosting.fittingSize)
            }
        }
        self.panel = panel
    }

    private func resizePanel(to fittingSize: NSSize) {
        guard let panel else { return }
        let newSize = NSSize(
            width: FloatingPanelView.panelWidth,
            height: min(430, max(180, fittingSize.height))
        )
        guard abs(panel.frame.height - newSize.height) > 1 else { return }

        let oldFrame = panel.frame
        let newOrigin = NSPoint(
            x: oldFrame.origin.x,
            y: oldFrame.maxY - newSize.height
        )
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: false)
        keepPanelOnScreen()
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let origin: NSPoint

        switch settings.panelPlacement {
        case .center:
            origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
        case .mouse:
            let mouse = NSEvent.mouseLocation
            origin = NSPoint(
                x: min(max(mouse.x + 14, visible.minX + 12), visible.maxX - size.width - 12),
                y: min(max(mouse.y - size.height - 14, visible.minY + 12), visible.maxY - size.height - 12)
            )
        }

        panel.setFrameOrigin(origin)
    }

    private func keepPanelOnScreen() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = min(max(frame.origin.x, visible.minX + 12), visible.maxX - frame.width - 12)
        frame.origin.y = min(max(frame.origin.y, visible.minY + 12), visible.maxY - frame.height - 12)
        panel.setFrameOrigin(frame.origin)
    }

    private func installOutsideClickMonitor() {
        if eventMonitor != nil { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.viewModel.isPinned else { return }
                self.panel?.orderOut(nil)
                self.removeOutsideClickMonitor()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

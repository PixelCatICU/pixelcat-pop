import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var history = HistoryStore()
    private lazy var viewModel = TranslationViewModel(settings: settings, history: history)
    private lazy var panelController = FloatingPanelController(viewModel: viewModel, settings: settings)
    private lazy var screenshotController = ScreenshotAnnotationController(settings: settings)
    private lazy var recordingController = RecordingController(settings: settings)
    private let systemMonitor = SystemMonitor()
    private let clipboardReader = ClipboardReader()
    private let triggerMonitor = ClipboardTriggerMonitor()

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var settingsCancellable: AnyCancellable?
    private var avatarMetricCancellable: AnyCancellable?
    private var systemMonitorTimer: Timer?
    private var systemSnapshot: SystemSnapshot?
    private weak var cpuMenuItem: NSMenuItem?
    private weak var memoryMenuItem: NSMenuItem?
    private weak var diskMenuItem: NSMenuItem?
    private weak var networkMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("PixelCat Pop runs as a menu bar utility.")
        NSApp.setActivationPolicy(.accessory)
        installStatusMenu()
        settingsCancellable = settings.$interfaceLanguage.dropFirst().sink { [weak self] _ in
            Task { @MainActor in
                self?.refreshLocalizedChrome()
            }
        }
        avatarMetricCancellable = settings.$avatarColorMetric.dropFirst().sink { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatusBarImage()
            }
        }
        startSystemMonitoring()

        triggerMonitor.onDoubleCopy = { [weak self] in
            self?.handleDoubleCopy()
        }
        triggerMonitor.start()

        if ProcessInfo.processInfo.environment["PIXELCAT_SCREENSHOT_EDITOR_TEST"] == "1" {
            screenshotController.openTestEditor(snapshotPath: ProcessInfo.processInfo.environment["PIXELCAT_SCREENSHOT_EDITOR_SNAPSHOT"])
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        triggerMonitor.stop()
        systemMonitorTimer?.invalidate()
    }

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusBarImage()
        item.button?.imagePosition = .imageOnly

        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let language = settings.interfaceLanguage
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.text(.inputTranslation, language: language), action: #selector(openInputTranslation), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.text(.translateClipboard, language: language), action: #selector(translateClipboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.text(.annotateScreenshot, language: language), action: #selector(annotateScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: recordingMenuTitle(language: language), action: #selector(toggleScreenRecording), keyEquivalent: ""))
        menu.addItem(.separator())
        let cpu = disabledMenuItem("")
        let memory = disabledMenuItem("")
        let disk = disabledMenuItem("")
        let network = disabledMenuItem("")
        menu.addItem(cpu)
        menu.addItem(memory)
        menu.addItem(disk)
        menu.addItem(network)
        cpuMenuItem = cpu
        memoryMenuItem = memory
        diskMenuItem = disk
        networkMenuItem = network
        updateSystemMenuItems(language: language)
        menu.addItem(NSMenuItem(title: L10n.text(.settings, language: language), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text(.quit, language: language), action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func refreshLocalizedChrome() {
        statusItem?.menu = makeStatusMenu()
        settingsWindow?.title = L10n.text(.settingsWindowTitle, language: settings.interfaceLanguage)
        refreshStatusBarImage()
    }

    private func refreshRecordingMenuTitle() {
        statusItem?.menu = makeStatusMenu()
    }

    private func recordingMenuTitle(language: AppLanguage) -> String {
        L10n.text(recordingController.isRecording ? .stopScreenRecording : .startScreenRecording, language: language)
    }

    private func disabledMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func startSystemMonitoring() {
        updateSystemSnapshot()
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemSnapshot()
            }
        }
    }

    private func updateSystemSnapshot() {
        systemSnapshot = systemMonitor.sample()
        updateSystemMenuItems(language: settings.interfaceLanguage)
        refreshStatusBarImage()
    }

    private func updateSystemMenuItems(language: AppLanguage) {
        guard let snapshot = systemSnapshot else {
            cpuMenuItem?.title = "\(L10n.text(.cpuUsage, language: language)): --"
            memoryMenuItem?.title = "\(L10n.text(.memoryUsage, language: language)): --"
            diskMenuItem?.title = "\(L10n.text(.diskUsage, language: language)): --"
            networkMenuItem?.title = "\(L10n.text(.networkUsage, language: language)): --"
            return
        }

        cpuMenuItem?.title = "\(L10n.text(.cpuUsage, language: language)): \(formatPercent(snapshot.cpuUsage))"
        memoryMenuItem?.title = "\(L10n.text(.memoryUsage, language: language)): \(formatPercent(snapshot.memoryUsage))"
        diskMenuItem?.title = "\(L10n.text(.diskUsage, language: language)): \(formatPercent(snapshot.diskUsage))"
        networkMenuItem?.title = "\(L10n.text(.networkUsage, language: language)): ↓ \(formatBytesPerSecond(snapshot.networkDownloadRate))  ↑ \(formatBytesPerSecond(snapshot.networkUploadRate))"
    }

    private func refreshStatusBarImage() {
        statusItem?.button?.image = statusBarImage()
    }

    private func statusBarImage() -> NSImage {
        guard let snapshot = systemSnapshot else {
            return BrandAssets.statusBarImage(tintColor: CatppuccinPalette.blue)
        }

        let ratio: Double
        switch settings.avatarColorMetric {
        case .cpu:
            ratio = snapshot.cpuUsage
        case .memory:
            ratio = snapshot.memoryUsage
        }

        return BrandAssets.statusBarImage(tintColor: CatppuccinPalette.loadColor(for: ratio))
    }

    private func formatPercent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private func formatBytesPerSecond(_ bytesPerSecond: UInt64) -> String {
        let value = Double(bytesPerSecond)
        if value >= 1_048_576 {
            return String(format: "%.1f MB/s", value / 1_048_576)
        }
        if value >= 1_024 {
            return String(format: "%.0f KB/s", value / 1_024)
        }
        return "\(bytesPerSecond) B/s"
    }

    private func handleDoubleCopy() {
        guard let text = clipboardReader.latestText() else { return }
        panelController.show(text: text)
    }

    @objc private func translateClipboard() {
        handleDoubleCopy()
    }

    @objc private func openInputTranslation() {
        panelController.showInput()
    }

    @objc private func annotateScreenshot() {
        screenshotController.start()
    }

    @objc private func toggleScreenRecording() {
        recordingController.toggleRecording()
        refreshRecordingMenuTitle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, history: history)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.text(.settingsWindowTitle, language: settings.interfaceLanguage)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.center()
            window.contentView = makeGlassContentView(rootView: view, material: .sidebar, blendingMode: .withinWindow)
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeGlassContentView<Content: View>(
        rootView: Content,
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode
    ) -> NSView {
        let glassView = GlassEffectView(material: material, blendingMode: blendingMode)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        glassView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: glassView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
        ])

        return glassView
    }
}

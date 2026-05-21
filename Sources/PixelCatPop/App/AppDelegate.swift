import AppKit
import Combine
import SwiftUI

private struct StatusBarColumn {
    let top: String
    let bottom: String
    let width: CGFloat
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var history = HistoryStore()
    private lazy var viewModel = TranslationViewModel(settings: settings, history: history)
    private lazy var panelController = FloatingPanelController(viewModel: viewModel, settings: settings)
    private lazy var screenshotController = ScreenshotAnnotationController(settings: settings)
    private var recordingController: RecordingController?
    private lazy var systemMonitor = SystemMonitor()
    private let clipboardReader = ClipboardReader()
    private let triggerMonitor = ClipboardTriggerMonitor()

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var appCleanerWindow: NSWindow?
    private var settingsCancellable: AnyCancellable?
    private var avatarMetricCancellable: AnyCancellable?
    private var systemMonitorRefreshCancellable: AnyCancellable?
    private var systemMenuVisibilityCancellables: [AnyCancellable] = []
    private var systemMonitorTimer: Timer?
    private var systemSnapshot: SystemSnapshot?

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
        systemMonitorRefreshCancellable = settings.$systemMonitorRefreshInterval.dropFirst().sink { [weak self] _ in
            Task { @MainActor in
                self?.startSystemMonitoring()
            }
        }
        systemMenuVisibilityCancellables = [
            settings.$showsCPUInMenu.dropFirst().sink { [weak self] _ in
                Task { @MainActor in self?.refreshSystemMonitorState() }
            },
            settings.$showsMemoryInMenu.dropFirst().sink { [weak self] _ in
                Task { @MainActor in self?.refreshSystemMonitorState() }
            },
            settings.$showsDiskInMenu.dropFirst().sink { [weak self] _ in
                Task { @MainActor in self?.refreshSystemMonitorState() }
            },
            settings.$showsNetworkInMenu.dropFirst().sink { [weak self] _ in
                Task { @MainActor in self?.refreshSystemMonitorState() }
            }
        ]
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
        updateStatusBarButton(item.button)

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
        menu.addItem(NSMenuItem(title: L10n.text(.appCleaner, language: language), action: #selector(openAppCleaner), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text(.settings, language: language), action: #selector(openSettings), keyEquivalent: ","))
#if DEBUG
        menu.addItem(NSMenuItem(title: L10n.text(.restart, language: language), action: #selector(restart), keyEquivalent: "r"))
#endif
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text(.quit, language: language), action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func refreshLocalizedChrome() {
        statusItem?.menu = makeStatusMenu()
        settingsWindow?.title = L10n.text(.settingsWindowTitle, language: settings.interfaceLanguage)
        appCleanerWindow?.title = L10n.text(.appCleanerWindowTitle, language: settings.interfaceLanguage)
        refreshStatusBarImage()
    }

    private func refreshRecordingMenuTitle() {
        statusItem?.menu = makeStatusMenu()
    }

    private func refreshSystemMonitorState() {
        startSystemMonitoring()
    }

    private func recordingMenuTitle(language: AppLanguage) -> String {
        L10n.text(recordingController?.isRecording == true ? .stopScreenRecording : .startScreenRecording, language: language)
    }

    private func startSystemMonitoring() {
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        guard shouldSampleSystemMonitor else {
            systemSnapshot = nil
            refreshStatusBarButton()
            return
        }

        updateSystemSnapshot()
        let interval = settings.systemMonitorRefreshInterval.seconds
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemSnapshot()
            }
        }
        timer.tolerance = settings.systemMonitorRefreshInterval == .realtime ? 0.1 : min(5, interval * 0.2)
        RunLoop.main.add(timer, forMode: .common)
        systemMonitorTimer = timer
    }

    private func updateSystemSnapshot() {
        guard shouldSampleSystemMonitor else {
            systemSnapshot = nil
            refreshStatusBarButton()
            return
        }
        systemSnapshot = systemMonitor.sample()
        refreshStatusBarButton()
    }

    private var shouldSampleSystemMonitor: Bool {
        settings.showsCPUInMenu
            || settings.showsMemoryInMenu
            || settings.showsDiskInMenu
            || settings.showsNetworkInMenu
    }

    private func refreshStatusBarImage() {
        refreshStatusBarButton()
    }

    private func refreshStatusBarButton() {
        updateStatusBarButton(statusItem?.button)
    }

    private func updateStatusBarButton(_ button: NSStatusBarButton?) {
        guard let button else { return }
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = renderedStatusBarImage()
        button.imagePosition = .imageOnly
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

    private func renderedStatusBarImage() -> NSImage {
        let icon = statusBarImage()
        let columns = statusBarColumns()
        guard !columns.isEmpty else { return icon }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let iconSize = NSSize(width: 18, height: 18)
        let spacing: CGFloat = 4
        let columnSpacing: CGFloat = 4
        let canvasHeight: CGFloat = 22
        let lineHeight: CGFloat = 8.5
        let textHeight = lineHeight * 2
        let textWidth = columns.reduce(CGFloat(0)) { $0 + $1.width }
            + columnSpacing * CGFloat(max(0, columns.count - 1))
        let canvasWidth = iconSize.width + spacing + textWidth
        let image = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))

        image.lockFocus()
        icon.draw(
            in: NSRect(
                x: 0,
                y: (canvasHeight - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        let textX = iconSize.width + spacing
        let textBottomY = (canvasHeight - textHeight) / 2
        var columnX = textX
        for column in columns {
            (column.top as NSString).draw(
                with: NSRect(x: columnX, y: textBottomY + lineHeight, width: column.width, height: lineHeight),
                options: [.usesLineFragmentOrigin],
                attributes: attributes
            )
            (column.bottom as NSString).draw(
                with: NSRect(x: columnX, y: textBottomY, width: column.width, height: lineHeight),
                options: [.usesLineFragmentOrigin],
                attributes: attributes
            )
            columnX += column.width + columnSpacing
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func statusBarColumns() -> [StatusBarColumn] {
        guard let snapshot = systemSnapshot else { return [] }

        var columns: [StatusBarColumn] = []
        if settings.showsCPUInMenu || settings.showsMemoryInMenu {
            columns.append(.init(
                top: settings.showsCPUInMenu ? "CPU \(formatPercent(snapshot.cpuUsage))" : "",
                bottom: settings.showsMemoryInMenu ? "MEM \(formatPercent(snapshot.memoryUsage))" : "",
                width: 48
            ))
        }
        if settings.showsNetworkInMenu {
            columns.append(.init(
                top: "\(formatCompactBytesPerSecond(snapshot.networkUploadRate)) ↑",
                bottom: "\(formatCompactBytesPerSecond(snapshot.networkDownloadRate)) ↓",
                width: 48
            ))
        }
        if settings.showsDiskInMenu {
            columns.append(.init(
                top: "DSK",
                bottom: formatPercent(snapshot.diskUsage),
                width: 24
            ))
        }
        return columns
    }

    private func formatCompactBytesPerSecond(_ bytesPerSecond: UInt64) -> String {
        let value = Double(bytesPerSecond)
        if value >= 1_048_576 {
            return String(format: "%.1fM/s", value / 1_048_576)
        }
        if value >= 1_024 {
            let kilobytes = value / 1_024
            if kilobytes >= 1_024 {
                return String(format: "%.1fM/s", kilobytes / 1_024)
            }
            return String(format: "%.1fK/s", kilobytes)
        }
        return "\(bytesPerSecond)B/s"
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
        if recordingController == nil {
            recordingController = RecordingController(settings: settings)
        }
        recordingController?.toggleRecording()
        refreshRecordingMenuTitle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, history: history)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.text(.settingsWindowTitle, language: settings.interfaceLanguage)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = makeGlassContentView(rootView: view, material: .sidebar, blendingMode: .withinWindow)
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAppCleaner() {
        if appCleanerWindow == nil {
            let view = AppCleanerView(settings: settings)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.text(.appCleanerWindowTitle, language: settings.interfaceLanguage)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = makeGlassContentView(rootView: view, material: .sidebar, blendingMode: .withinWindow)
            appCleanerWindow = window
        }

        appCleanerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

#if DEBUG
    @objc private func restart() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if error == nil {
                Task { @MainActor in
                    NSApp.terminate(nil)
                }
            }
        }
    }
#endif

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

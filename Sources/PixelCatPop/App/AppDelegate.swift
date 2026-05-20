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
    private let clipboardReader = ClipboardReader()
    private let triggerMonitor = ClipboardTriggerMonitor()

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var settingsCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("PixelCat Pop runs as a menu bar utility.")
        NSApp.setActivationPolicy(.accessory)
        installStatusMenu()
        settingsCancellable = settings.$interfaceLanguage.dropFirst().sink { [weak self] _ in
            Task { @MainActor in
                self?.refreshLocalizedChrome()
            }
        }

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
    }

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = BrandAssets.statusBarImage()
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
        menu.addItem(NSMenuItem(title: L10n.text(.settings, language: language), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text(.quit, language: language), action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func refreshLocalizedChrome() {
        statusItem?.menu = makeStatusMenu()
        settingsWindow?.title = L10n.text(.settingsWindowTitle, language: settings.interfaceLanguage)
    }

    private func refreshRecordingMenuTitle() {
        statusItem?.menu = makeStatusMenu()
    }

    private func recordingMenuTitle(language: AppLanguage) -> String {
        L10n.text(recordingController.isRecording ? .stopScreenRecording : .startScreenRecording, language: language)
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

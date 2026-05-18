import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var history = HistoryStore()
    private lazy var viewModel = TranslationViewModel(settings: settings, history: history)
    private lazy var panelController = FloatingPanelController(viewModel: viewModel, settings: settings)
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
        menu.addItem(NSMenuItem(title: L10n.text(.checkTranslationLanguages, language: language), action: #selector(checkTranslationLanguages), keyEquivalent: ""))
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

    @objc private func checkTranslationLanguages() {
        let translateAppURL = URL(fileURLWithPath: "/System/Applications/Translate.app")
        NSWorkspace.shared.open(translateAppURL)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, history: history)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 330),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.text(.settingsWindowTitle, language: settings.interfaceLanguage)
            window.center()
            window.contentView = NSHostingView(rootView: view)
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

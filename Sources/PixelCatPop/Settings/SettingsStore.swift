import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var interfaceLanguage: AppLanguage {
        didSet { defaults.set(interfaceLanguage.rawValue, forKey: Keys.interfaceLanguage) }
    }

    @Published var targetLanguageMode: TargetLanguageMode {
        didSet { defaults.set(targetLanguageMode.rawValue, forKey: Keys.targetLanguageMode) }
    }

    @Published var fixedTargetLanguageCode: String {
        didSet { defaults.set(fixedTargetLanguageCode, forKey: Keys.fixedTargetLanguageCode) }
    }

    @Published var panelPlacement: PanelPlacement {
        didSet { defaults.set(panelPlacement.rawValue, forKey: Keys.panelPlacement) }
    }

    @Published var savesTranslationHistory: Bool {
        didSet { defaults.set(savesTranslationHistory, forKey: Keys.savesTranslationHistory) }
    }

    @Published var opensAtLogin: Bool {
        didSet { defaults.set(opensAtLogin, forKey: Keys.opensAtLogin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let interfaceLanguageValue = defaults.string(forKey: Keys.interfaceLanguage) ?? AppLanguage.system.rawValue
        interfaceLanguage = AppLanguage(rawValue: interfaceLanguageValue) ?? .system
        let modeValue = defaults.string(forKey: Keys.targetLanguageMode) ?? TargetLanguageMode.smart.rawValue
        targetLanguageMode = TargetLanguageMode(rawValue: modeValue) ?? .smart
        fixedTargetLanguageCode = defaults.string(forKey: Keys.fixedTargetLanguageCode) ?? LanguageRouter.defaultChineseCode
        let placementValue = defaults.string(forKey: Keys.panelPlacement) ?? PanelPlacement.center.rawValue
        panelPlacement = PanelPlacement(rawValue: placementValue) ?? .center
        savesTranslationHistory = defaults.object(forKey: Keys.savesTranslationHistory) as? Bool ?? true
        opensAtLogin = defaults.object(forKey: Keys.opensAtLogin) as? Bool ?? false
    }

    var router: LanguageRouter {
        LanguageRouter(
            mode: targetLanguageMode,
            fixedTargetLanguageCode: fixedTargetLanguageCode
        )
    }

    enum PanelPlacement: String, CaseIterable, Identifiable {
        case mouse
        case center

        var id: String { rawValue }
    }

    private enum Keys {
        static let interfaceLanguage = "interfaceLanguage"
        static let targetLanguageMode = "targetLanguageMode"
        static let fixedTargetLanguageCode = "fixedTargetLanguageCode"
        static let panelPlacement = "panelPlacement"
        static let savesTranslationHistory = "savesTranslationHistory"
        static let opensAtLogin = "opensAtLogin"
    }
}

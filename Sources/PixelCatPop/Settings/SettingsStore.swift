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

    @Published var avatarColorMetric: AvatarColorMetric {
        didSet { defaults.set(avatarColorMetric.rawValue, forKey: Keys.avatarColorMetric) }
    }

    @Published var systemMonitorRefreshInterval: SystemMonitorRefreshInterval {
        didSet { defaults.set(systemMonitorRefreshInterval.rawValue, forKey: Keys.systemMonitorRefreshInterval) }
    }

    @Published var showsCPUInMenu: Bool {
        didSet { defaults.set(showsCPUInMenu, forKey: Keys.showsCPUInMenu) }
    }

    @Published var showsMemoryInMenu: Bool {
        didSet { defaults.set(showsMemoryInMenu, forKey: Keys.showsMemoryInMenu) }
    }

    @Published var showsDiskInMenu: Bool {
        didSet { defaults.set(showsDiskInMenu, forKey: Keys.showsDiskInMenu) }
    }

    @Published var showsNetworkInMenu: Bool {
        didSet { defaults.set(showsNetworkInMenu, forKey: Keys.showsNetworkInMenu) }
    }

    @Published var screenshotAnnotationColor: ScreenshotAnnotationColor {
        didSet { defaults.set(screenshotAnnotationColor.rawValue, forKey: Keys.screenshotAnnotationColor) }
    }

    @Published var recordsSystemAudio: Bool {
        didSet { defaults.set(recordsSystemAudio, forKey: Keys.recordsSystemAudio) }
    }

    @Published var recordsMicrophoneAudio: Bool {
        didSet { defaults.set(recordsMicrophoneAudio, forKey: Keys.recordsMicrophoneAudio) }
    }

    @Published var playsMouseClickSound: Bool {
        didSet { defaults.set(playsMouseClickSound, forKey: Keys.playsMouseClickSound) }
    }

    @Published var playsKeyboardInputSound: Bool {
        didSet { defaults.set(playsKeyboardInputSound, forKey: Keys.playsKeyboardInputSound) }
    }

    @Published var showsClickRipple: Bool {
        didSet { defaults.set(showsClickRipple, forKey: Keys.showsClickRipple) }
    }

    @Published var showsTypingZoom: Bool {
        didSet { defaults.set(showsTypingZoom, forKey: Keys.showsTypingZoom) }
    }

    @Published var appCleanerSelectsPreferences: Bool {
        didSet { defaults.set(appCleanerSelectsPreferences, forKey: Keys.appCleanerSelectsPreferences) }
    }

    @Published var appCleanerSelectsCaches: Bool {
        didSet { defaults.set(appCleanerSelectsCaches, forKey: Keys.appCleanerSelectsCaches) }
    }

    @Published var appCleanerSelectsSupportFiles: Bool {
        didSet { defaults.set(appCleanerSelectsSupportFiles, forKey: Keys.appCleanerSelectsSupportFiles) }
    }

    @Published var appCleanerSelectsContainers: Bool {
        didSet { defaults.set(appCleanerSelectsContainers, forKey: Keys.appCleanerSelectsContainers) }
    }

    @Published var appCleanerSelectsLogs: Bool {
        didSet { defaults.set(appCleanerSelectsLogs, forKey: Keys.appCleanerSelectsLogs) }
    }

    @Published var appCleanerSelectsSavedState: Bool {
        didSet { defaults.set(appCleanerSelectsSavedState, forKey: Keys.appCleanerSelectsSavedState) }
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
        let metricValue = defaults.string(forKey: Keys.avatarColorMetric) ?? AvatarColorMetric.cpu.rawValue
        avatarColorMetric = AvatarColorMetric(rawValue: metricValue) ?? .cpu
        let refreshValue = defaults.string(forKey: Keys.systemMonitorRefreshInterval) ?? SystemMonitorRefreshInterval.realtime.rawValue
        systemMonitorRefreshInterval = SystemMonitorRefreshInterval(rawValue: refreshValue) ?? .realtime
        showsCPUInMenu = defaults.object(forKey: Keys.showsCPUInMenu) as? Bool ?? false
        showsMemoryInMenu = defaults.object(forKey: Keys.showsMemoryInMenu) as? Bool ?? false
        showsDiskInMenu = defaults.object(forKey: Keys.showsDiskInMenu) as? Bool ?? false
        showsNetworkInMenu = defaults.object(forKey: Keys.showsNetworkInMenu) as? Bool ?? false
        let colorValue = defaults.string(forKey: Keys.screenshotAnnotationColor) ?? ScreenshotAnnotationColor.red.rawValue
        screenshotAnnotationColor = ScreenshotAnnotationColor(rawValue: colorValue) ?? .red
        recordsSystemAudio = defaults.object(forKey: Keys.recordsSystemAudio) as? Bool ?? true
        recordsMicrophoneAudio = defaults.object(forKey: Keys.recordsMicrophoneAudio) as? Bool ?? true
        playsMouseClickSound = defaults.object(forKey: Keys.playsMouseClickSound) as? Bool ?? true
        playsKeyboardInputSound = defaults.object(forKey: Keys.playsKeyboardInputSound) as? Bool ?? true
        showsClickRipple = defaults.object(forKey: Keys.showsClickRipple) as? Bool ?? true
        showsTypingZoom = defaults.object(forKey: Keys.showsTypingZoom) as? Bool ?? true
        appCleanerSelectsPreferences = defaults.object(forKey: Keys.appCleanerSelectsPreferences) as? Bool ?? true
        appCleanerSelectsCaches = defaults.object(forKey: Keys.appCleanerSelectsCaches) as? Bool ?? true
        appCleanerSelectsSupportFiles = defaults.object(forKey: Keys.appCleanerSelectsSupportFiles) as? Bool ?? true
        appCleanerSelectsContainers = defaults.object(forKey: Keys.appCleanerSelectsContainers) as? Bool ?? true
        appCleanerSelectsLogs = defaults.object(forKey: Keys.appCleanerSelectsLogs) as? Bool ?? true
        appCleanerSelectsSavedState = defaults.object(forKey: Keys.appCleanerSelectsSavedState) as? Bool ?? true
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

    enum AvatarColorMetric: String, CaseIterable, Identifiable {
        case cpu
        case memory

        var id: String { rawValue }
    }

    enum SystemMonitorRefreshInterval: String, CaseIterable, Identifiable {
        case realtime
        case fiveSeconds
        case tenSeconds
        case thirtySeconds
        case oneMinute

        var id: String { rawValue }

        var seconds: TimeInterval {
            switch self {
            case .realtime:
                1
            case .fiveSeconds:
                5
            case .tenSeconds:
                10
            case .thirtySeconds:
                30
            case .oneMinute:
                60
            }
        }
    }

    enum ScreenshotAnnotationColor: String, CaseIterable, Identifiable {
        case red
        case peach
        case yellow
        case green
        case teal
        case blue
        case mauve

        var id: String { rawValue }
    }

    private enum Keys {
        static let interfaceLanguage = "interfaceLanguage"
        static let targetLanguageMode = "targetLanguageMode"
        static let fixedTargetLanguageCode = "fixedTargetLanguageCode"
        static let panelPlacement = "panelPlacement"
        static let savesTranslationHistory = "savesTranslationHistory"
        static let opensAtLogin = "opensAtLogin"
        static let avatarColorMetric = "avatarColorMetric"
        static let systemMonitorRefreshInterval = "systemMonitorRefreshInterval"
        static let showsCPUInMenu = "showsCPUInMenu"
        static let showsMemoryInMenu = "showsMemoryInMenu"
        static let showsDiskInMenu = "showsDiskInMenu"
        static let showsNetworkInMenu = "showsNetworkInMenu"
        static let screenshotAnnotationColor = "screenshotAnnotationColor"
        static let recordsSystemAudio = "recordsSystemAudio"
        static let recordsMicrophoneAudio = "recordsMicrophoneAudio"
        static let playsMouseClickSound = "playsMouseClickSound"
        static let playsKeyboardInputSound = "playsKeyboardInputSound"
        static let showsClickRipple = "showsClickRipple"
        static let showsTypingZoom = "showsTypingZoom"
        static let appCleanerSelectsPreferences = "appCleanerSelectsPreferences"
        static let appCleanerSelectsCaches = "appCleanerSelectsCaches"
        static let appCleanerSelectsSupportFiles = "appCleanerSelectsSupportFiles"
        static let appCleanerSelectsContainers = "appCleanerSelectsContainers"
        static let appCleanerSelectsLogs = "appCleanerSelectsLogs"
        static let appCleanerSelectsSavedState = "appCleanerSelectsSavedState"
    }
}

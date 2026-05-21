import Foundation

enum L10n {
    enum Key {
        case appSubtitle
        case generalSettings
        case translationSettings
        case screenshotAnnotationSettings
        case recordingSettings
        case interactionEffectSettings
        case appCleanerSettings
        case menuBarMonitorSettings
        case interfaceLanguage
        case systemLanguage
        case chineseInterface
        case englishInterface
        case targetLanguage
        case smartTargetMode
        case fixedTargetMode
        case defaultTarget
        case panelPosition
        case nearMouse
        case screenCenter
        case defaultAnnotationColor
        case colorRed
        case colorPeach
        case colorYellow
        case colorGreen
        case colorTeal
        case colorBlue
        case colorMauve
        case recordSystemAudio
        case recordMicrophoneAudio
        case mouseClickSound
        case keyboardInputSound
        case clickRipple
        case typingZoom
        case selectPreferencesByDefault
        case selectCachesByDefault
        case selectSupportFilesByDefault
        case selectContainersByDefault
        case selectLogsByDefault
        case selectSavedStateByDefault
        case avatarColorMetric
        case systemInfoRefreshInterval
        case refreshRealtime
        case refreshEveryFiveSeconds
        case refreshEveryTenSeconds
        case refreshEveryThirtySeconds
        case refreshEveryOneMinute
        case showCPUInMenu
        case showMemoryInMenu
        case showDiskInMenu
        case showNetworkInMenu
        case cpuUsage
        case memoryUsage
        case diskUsage
        case networkUsage
        case saveTranslationHistory
        case historyEntries
        case clear
        case startAtLogin
        case loginItemReserved
        case inputTranslation
        case translateClipboard
        case annotateScreenshot
        case startScreenRecording
        case stopScreenRecording
        case appCleaner
        case appCleanerWindowTitle
        case appCleanerHint
        case chooseApplication
        case noApplicationSelected
        case appCleanerEmptyHint
        case appCleanerScanComplete
        case moveToTrash
        case confirmMoveToTrash
        case cancel
        case appCleanerTrashComplete
        case appCleanerTrashFailed
        case screenRecordingSaved
        case screenRecordingFailed
        case checkTranslationLanguages
        case settings
#if DEBUG
        case restart
#endif
        case quit
        case settingsWindowTitle
        case pinPanel
        case unpinPanel
        case doubleCopyHint
        case translating
        case translationLanguagesNotInstalled
        case preparingTranslationLanguages
        case translationTimeout
        case copyTranslation
        case readText
        case stopReading
        case autoLanguage
        case manualInputHint
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        text(key, languageCode: language.resolvedCode)
    }

    static func text(_ key: Key, languageCode: String = Locale.preferredLanguages.first ?? "en") -> String {
        if isChinese(languageCode) {
            return zhText(key)
        }
        return enText(key)
    }

    static func languageName(code: String, fallback: String, languageCode: String = Locale.preferredLanguages.first ?? "en") -> String {
        if isChinese(languageCode) {
            return [
                "zh-Hans": "中文",
                "en-US": "英语（美国）",
                "en": "英语",
                "ja": "日语",
                "ko": "韩语",
                "fr": "法语",
                "de": "德语",
                "es": "西班牙语"
            ][code] ?? fallback
        }

        return [
            "zh-Hans": "Chinese",
            "en-US": "English (US)",
            "en": "English",
            "ja": "Japanese",
            "ko": "Korean",
            "fr": "French",
            "de": "German",
            "es": "Spanish"
        ][code] ?? fallback
    }

    private static func isChinese(_ languageCode: String) -> Bool {
        languageCode.lowercased().hasPrefix("zh")
    }

    private static func zhText(_ key: Key) -> String {
        switch key {
        case .appSubtitle: "Mac 工具箱"
        case .generalSettings: "通用"
        case .translationSettings: "翻译"
        case .screenshotAnnotationSettings: "截图标注"
        case .recordingSettings: "录屏"
        case .interactionEffectSettings: "交互效果"
        case .appCleanerSettings: "应用清理"
        case .menuBarMonitorSettings: "菜单栏监控"
        case .interfaceLanguage: "界面语言"
        case .systemLanguage: "跟随系统"
        case .chineseInterface: "中文"
        case .englishInterface: "English"
        case .targetLanguage: "目标语言"
        case .smartTargetMode: "智能：中文和英文互译，其他语言译为默认目标"
        case .fixedTargetMode: "始终翻译为所选语言"
        case .defaultTarget: "默认目标"
        case .panelPosition: "弹窗位置"
        case .nearMouse: "鼠标附近"
        case .screenCenter: "屏幕中央"
        case .defaultAnnotationColor: "默认标注颜色"
        case .colorRed: "红色"
        case .colorPeach: "蜜桃"
        case .colorYellow: "黄色"
        case .colorGreen: "绿色"
        case .colorTeal: "青色"
        case .colorBlue: "蓝色"
        case .colorMauve: "紫色"
        case .recordSystemAudio: "录制系统声音"
        case .recordMicrophoneAudio: "录制麦克风声音"
        case .mouseClickSound: "鼠标点击声音"
        case .keyboardInputSound: "键盘输入声音"
        case .clickRipple: "鼠标点击波纹"
        case .typingZoom: "键盘输入区域 Zoom"
        case .selectPreferencesByDefault: "默认选中偏好设置"
        case .selectCachesByDefault: "默认选中缓存"
        case .selectSupportFilesByDefault: "默认选中支持文件"
        case .selectContainersByDefault: "默认选中容器"
        case .selectLogsByDefault: "默认选中日志"
        case .selectSavedStateByDefault: "默认选中保存状态"
        case .avatarColorMetric: "头像颜色依据"
        case .systemInfoRefreshInterval: "系统信息刷新"
        case .refreshRealtime: "实时（每 1 秒）"
        case .refreshEveryFiveSeconds: "每 5 秒"
        case .refreshEveryTenSeconds: "每 10 秒"
        case .refreshEveryThirtySeconds: "每 30 秒"
        case .refreshEveryOneMinute: "每 1 分钟"
        case .showCPUInMenu: "在菜单中显示 CPU"
        case .showMemoryInMenu: "在菜单中显示内存"
        case .showDiskInMenu: "在菜单中显示硬盘"
        case .showNetworkInMenu: "在菜单中显示网络"
        case .cpuUsage: "CPU"
        case .memoryUsage: "内存"
        case .diskUsage: "硬盘"
        case .networkUsage: "网络"
        case .saveTranslationHistory: "保存翻译历史"
        case .historyEntries: "历史条数"
        case .clear: "清除"
        case .startAtLogin: "开机启动"
        case .loginItemReserved: "登录项会在签名后的应用包阶段接入。"
        case .inputTranslation: "输入翻译"
        case .translateClipboard: "翻译剪贴板"
        case .annotateScreenshot: "截图标注"
        case .startScreenRecording: "开始录屏"
        case .stopScreenRecording: "停止录屏"
        case .appCleaner: "应用清理"
        case .appCleanerWindowTitle: "PixelCat Pop 应用清理"
        case .appCleanerHint: "选择或拖入一个 App，扫描相关缓存、偏好设置、容器和日志。"
        case .chooseApplication: "选择应用"
        case .noApplicationSelected: "未选择应用"
        case .appCleanerEmptyHint: "选择或拖入 /Applications 里的 .app 后再确认要移到废纸篓的项目。"
        case .appCleanerScanComplete: "扫描完成，请确认要清理的项目。"
        case .moveToTrash: "移到废纸篓"
        case .confirmMoveToTrash: "确认将选中项目移到废纸篓？"
        case .cancel: "取消"
        case .appCleanerTrashComplete: "已移到废纸篓。"
        case .appCleanerTrashFailed: "部分项目移动失败"
        case .screenRecordingSaved: "录屏已保存"
        case .screenRecordingFailed: "录屏失败"
        case .checkTranslationLanguages: "检查语言包"
        case .settings: "设置..."
#if DEBUG
        case .restart: "重启"
#endif
        case .quit: "退出"
        case .settingsWindowTitle: "PixelCat Pop 设置"
        case .pinPanel: "固定弹窗"
        case .unpinPanel: "取消固定"
        case .doubleCopyHint: "连续按两次 Command-C 复制文本后翻译。"
        case .translating: "正在翻译..."
        case .translationLanguagesNotInstalled: "语言包未安装。请先打开系统翻译应用或系统语言设置安装对应语言包。"
        case .preparingTranslationLanguages: "正在准备翻译语言..."
        case .translationTimeout: "翻译超时。请先在系统翻译或语言设置中安装对应语言包。"
        case .copyTranslation: "复制译文"
        case .readText: "朗读"
        case .stopReading: "停止朗读"
        case .autoLanguage: "自动"
        case .manualInputHint: "输入文字后会自动翻译。"
        }
    }

    private static func enText(_ key: Key) -> String {
        switch key {
        case .appSubtitle: "Mac toolbox"
        case .generalSettings: "General"
        case .translationSettings: "Translation"
        case .screenshotAnnotationSettings: "Screenshot Annotation"
        case .recordingSettings: "Recording"
        case .interactionEffectSettings: "Interaction Effects"
        case .appCleanerSettings: "App Cleaner"
        case .menuBarMonitorSettings: "Menu Bar Monitor"
        case .interfaceLanguage: "Interface language"
        case .systemLanguage: "System"
        case .chineseInterface: "Chinese"
        case .englishInterface: "English"
        case .targetLanguage: "Target language"
        case .smartTargetMode: "Smart: Chinese <-> English, other -> default target"
        case .fixedTargetMode: "Always translate to selected language"
        case .defaultTarget: "Default target"
        case .panelPosition: "Panel position"
        case .nearMouse: "Near mouse"
        case .screenCenter: "Screen center"
        case .defaultAnnotationColor: "Default annotation color"
        case .colorRed: "Red"
        case .colorPeach: "Peach"
        case .colorYellow: "Yellow"
        case .colorGreen: "Green"
        case .colorTeal: "Teal"
        case .colorBlue: "Blue"
        case .colorMauve: "Mauve"
        case .recordSystemAudio: "Record system audio"
        case .recordMicrophoneAudio: "Record microphone audio"
        case .mouseClickSound: "Mouse click sound"
        case .keyboardInputSound: "Keyboard input sound"
        case .clickRipple: "Mouse click ripple"
        case .typingZoom: "Keyboard input area zoom"
        case .selectPreferencesByDefault: "Select preferences by default"
        case .selectCachesByDefault: "Select caches by default"
        case .selectSupportFilesByDefault: "Select support files by default"
        case .selectContainersByDefault: "Select containers by default"
        case .selectLogsByDefault: "Select logs by default"
        case .selectSavedStateByDefault: "Select saved state by default"
        case .avatarColorMetric: "Avatar color metric"
        case .systemInfoRefreshInterval: "System info refresh"
        case .refreshRealtime: "Realtime (every 1 second)"
        case .refreshEveryFiveSeconds: "Every 5 seconds"
        case .refreshEveryTenSeconds: "Every 10 seconds"
        case .refreshEveryThirtySeconds: "Every 30 seconds"
        case .refreshEveryOneMinute: "Every 1 minute"
        case .showCPUInMenu: "Show CPU in menu"
        case .showMemoryInMenu: "Show memory in menu"
        case .showDiskInMenu: "Show disk in menu"
        case .showNetworkInMenu: "Show network in menu"
        case .cpuUsage: "CPU"
        case .memoryUsage: "Memory"
        case .diskUsage: "Disk"
        case .networkUsage: "Network"
        case .saveTranslationHistory: "Save translation history"
        case .historyEntries: "History entries"
        case .clear: "Clear"
        case .startAtLogin: "Start at login"
        case .loginItemReserved: "Login item wiring is reserved for the signed app bundle stage."
        case .inputTranslation: "Input Translation"
        case .translateClipboard: "Translate Clipboard"
        case .annotateScreenshot: "Annotate Screenshot"
        case .startScreenRecording: "Start Screen Recording"
        case .stopScreenRecording: "Stop Screen Recording"
        case .appCleaner: "App Cleaner"
        case .appCleanerWindowTitle: "PixelCat Pop App Cleaner"
        case .appCleanerHint: "Choose or drop an app to scan related caches, preferences, containers, and logs."
        case .chooseApplication: "Choose App"
        case .noApplicationSelected: "No app selected"
        case .appCleanerEmptyHint: "Choose or drop a .app from /Applications, then confirm which items should move to Trash."
        case .appCleanerScanComplete: "Scan complete. Review the items before cleaning."
        case .moveToTrash: "Move to Trash"
        case .confirmMoveToTrash: "Move the selected items to Trash?"
        case .cancel: "Cancel"
        case .appCleanerTrashComplete: "Moved to Trash."
        case .appCleanerTrashFailed: "Some items failed"
        case .screenRecordingSaved: "Screen recording saved"
        case .screenRecordingFailed: "Screen recording failed"
        case .checkTranslationLanguages: "Check Languages"
        case .settings: "Settings..."
#if DEBUG
        case .restart: "Restart"
#endif
        case .quit: "Quit"
        case .settingsWindowTitle: "PixelCat Pop Settings"
        case .pinPanel: "Pin panel"
        case .unpinPanel: "Unpin panel"
        case .doubleCopyHint: "Copy text twice with Command-C to translate."
        case .translating: "Translating..."
        case .translationLanguagesNotInstalled: "Language package is not installed. Open the system Translate app or language settings and install it first."
        case .preparingTranslationLanguages: "Preparing translation languages..."
        case .translationTimeout: "Translation timed out. Install the required languages in system translation settings first."
        case .copyTranslation: "Copy translation"
        case .readText: "Read text"
        case .stopReading: "Stop reading"
        case .autoLanguage: "auto"
        case .manualInputHint: "Type text to translate automatically."
        }
    }
}

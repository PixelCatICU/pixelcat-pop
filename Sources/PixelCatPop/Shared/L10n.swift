import Foundation

enum L10n {
    enum Key {
        case appSubtitle
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
        case avatarColorMetric
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
        case screenRecordingSaved
        case screenRecordingFailed
        case checkTranslationLanguages
        case settings
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
        case .avatarColorMetric: "头像颜色依据"
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
        case .screenRecordingSaved: "录屏已保存"
        case .screenRecordingFailed: "录屏失败"
        case .checkTranslationLanguages: "检查语言包"
        case .settings: "设置..."
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
        case .avatarColorMetric: "Avatar color metric"
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
        case .screenRecordingSaved: "Screen recording saved"
        case .screenRecordingFailed: "Screen recording failed"
        case .checkTranslationLanguages: "Check Languages"
        case .settings: "Settings..."
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

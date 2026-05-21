import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore

    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        let language = settings.interfaceLanguage

        HStack(spacing: 0) {
            sidebar(language: language)

            Divider()

            detailPane(language: language)
        }
        .frame(width: 760, height: 560)
        .background(.clear)
    }

    private func sidebar(language: AppLanguage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                BrandLogoView(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PixelCat Pop")
                        .font(.headline)
                    Text(L10n.text(.appSubtitle, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 4)

            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.title(language: language), systemImage: category.systemImage)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 230)
    }

    private func detailPane(language: AppLanguage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(selectedCategory.title(language: language), systemImage: selectedCategory.systemImage)
                .font(.title2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    selectedCategoryContent(language: language)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func selectedCategoryContent(language: AppLanguage) -> some View {
        switch selectedCategory {
        case .general:
            settingsGroup {
                Picker(L10n.text(.interfaceLanguage, language: language), selection: $settings.interfaceLanguage) {
                    Text(L10n.text(.systemLanguage, language: language)).tag(AppLanguage.system)
                    Text(L10n.text(.chineseInterface, language: language)).tag(AppLanguage.zhHans)
                    Text(L10n.text(.englishInterface, language: language)).tag(AppLanguage.en)
                }
                settingsDivider()
                Toggle(L10n.text(.startAtLogin, language: language), isOn: $settings.opensAtLogin)
                    .disabled(true)
                Text(L10n.text(.loginItemReserved, language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .translation:
            settingsGroup {
                Picker(L10n.text(.targetLanguage, language: language), selection: $settings.targetLanguageMode) {
                    Text(L10n.text(.smartTargetMode, language: language)).tag(TargetLanguageMode.smart)
                    Text(L10n.text(.fixedTargetMode, language: language)).tag(TargetLanguageMode.fixed)
                }
                .pickerStyle(.radioGroup)
                settingsDivider()
                Picker(L10n.text(.defaultTarget, language: language), selection: $settings.fixedTargetLanguageCode) {
                    ForEach(LanguageOption.supported) { language in
                        Text(language.localizedName(language: settings.interfaceLanguage)).tag(language.code)
                    }
                }
                Picker(L10n.text(.panelPosition, language: language), selection: $settings.panelPlacement) {
                    Text(L10n.text(.nearMouse, language: language)).tag(SettingsStore.PanelPlacement.mouse)
                    Text(L10n.text(.screenCenter, language: language)).tag(SettingsStore.PanelPlacement.center)
                }
                settingsDivider()
                Button {
                    openTranslationLanguages()
                } label: {
                    Label(L10n.text(.checkTranslationLanguages, language: language), systemImage: "globe")
                }
                settingsDivider()
                Toggle(L10n.text(.saveTranslationHistory, language: language), isOn: $settings.savesTranslationHistory)
                HStack {
                    Text(L10n.text(.historyEntries, language: language))
                    Spacer()
                    Text("\(history.entries.count)")
                        .foregroundStyle(.secondary)
                    Button(L10n.text(.clear, language: language)) {
                        history.clear()
                    }
                    .disabled(history.entries.isEmpty)
                }
            }
        case .screenshot:
            settingsGroup {
                Picker(L10n.text(.defaultAnnotationColor, language: language), selection: $settings.screenshotAnnotationColor) {
                    ForEach(SettingsStore.ScreenshotAnnotationColor.allCases) { color in
                        HStack {
                            Circle()
                                .fill(Color(nsColor: color.nsColor))
                                .frame(width: 12, height: 12)
                            Text(color.localizedName(language: language))
                        }
                        .tag(color)
                    }
                }
            }
        case .recording:
            settingsGroup {
                Toggle(L10n.text(.recordSystemAudio, language: language), isOn: $settings.recordsSystemAudio)
                settingsDivider()
                Toggle(L10n.text(.recordMicrophoneAudio, language: language), isOn: $settings.recordsMicrophoneAudio)
            }
        case .effects:
            settingsGroup {
                Toggle(L10n.text(.mouseClickSound, language: language), isOn: $settings.playsMouseClickSound)
                settingsDivider()
                Toggle(L10n.text(.keyboardInputSound, language: language), isOn: $settings.playsKeyboardInputSound)
                settingsDivider()
                Toggle(L10n.text(.clickRipple, language: language), isOn: $settings.showsClickRipple)
                settingsDivider()
                Toggle(L10n.text(.typingZoom, language: language), isOn: $settings.showsTypingZoom)
            }
        case .appCleaner:
            settingsGroup {
                Toggle(L10n.text(.selectPreferencesByDefault, language: language), isOn: $settings.appCleanerSelectsPreferences)
                settingsDivider()
                Toggle(L10n.text(.selectCachesByDefault, language: language), isOn: $settings.appCleanerSelectsCaches)
                settingsDivider()
                Toggle(L10n.text(.selectSupportFilesByDefault, language: language), isOn: $settings.appCleanerSelectsSupportFiles)
                settingsDivider()
                Toggle(L10n.text(.selectContainersByDefault, language: language), isOn: $settings.appCleanerSelectsContainers)
                settingsDivider()
                Toggle(L10n.text(.selectLogsByDefault, language: language), isOn: $settings.appCleanerSelectsLogs)
                settingsDivider()
                Toggle(L10n.text(.selectSavedStateByDefault, language: language), isOn: $settings.appCleanerSelectsSavedState)
            }
        case .menuBar:
            settingsGroup {
                Picker(L10n.text(.avatarColorMetric, language: language), selection: $settings.avatarColorMetric) {
                    Text(L10n.text(.cpuUsage, language: language)).tag(SettingsStore.AvatarColorMetric.cpu)
                    Text(L10n.text(.memoryUsage, language: language)).tag(SettingsStore.AvatarColorMetric.memory)
                }
                settingsDivider()
                Picker(L10n.text(.systemInfoRefreshInterval, language: language), selection: $settings.systemMonitorRefreshInterval) {
                    ForEach(SettingsStore.SystemMonitorRefreshInterval.allCases) { interval in
                        Text(interval.localizedName(language: language)).tag(interval)
                    }
                }
                settingsDivider()
                Toggle(L10n.text(.showCPUInMenu, language: language), isOn: $settings.showsCPUInMenu)
                settingsDivider()
                Toggle(L10n.text(.showMemoryInMenu, language: language), isOn: $settings.showsMemoryInMenu)
                settingsDivider()
                Toggle(L10n.text(.showDiskInMenu, language: language), isOn: $settings.showsDiskInMenu)
                settingsDivider()
                Toggle(L10n.text(.showNetworkInMenu, language: language), isOn: $settings.showsNetworkInMenu)
            }
        }
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func settingsDivider() -> some View {
        Divider()
            .padding(.leading, 2)
    }

    private func openTranslationLanguages() {
        let translateAppURL = URL(fileURLWithPath: "/System/Applications/Translate.app")
        NSWorkspace.shared.open(translateAppURL)
    }
}

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case translation
    case screenshot
    case recording
    case effects
    case appCleaner
    case menuBar

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .translation:
            "text.bubble"
        case .screenshot:
            "rectangle.dashed"
        case .recording:
            "record.circle"
        case .effects:
            "cursorarrow.click"
        case .appCleaner:
            "trash"
        case .menuBar:
            "menubar.rectangle"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general:
            L10n.text(.generalSettings, language: language)
        case .translation:
            L10n.text(.translationSettings, language: language)
        case .screenshot:
            L10n.text(.screenshotAnnotationSettings, language: language)
        case .recording:
            L10n.text(.recordingSettings, language: language)
        case .effects:
            L10n.text(.interactionEffectSettings, language: language)
        case .appCleaner:
            L10n.text(.appCleanerSettings, language: language)
        case .menuBar:
            L10n.text(.menuBarMonitorSettings, language: language)
        }
    }
}

private extension SettingsStore.ScreenshotAnnotationColor {
    var nsColor: NSColor {
        switch self {
        case .red:
            CatppuccinPalette.red
        case .peach:
            CatppuccinPalette.peach
        case .yellow:
            CatppuccinPalette.yellow
        case .green:
            CatppuccinPalette.green
        case .teal:
            CatppuccinPalette.teal
        case .blue:
            CatppuccinPalette.blue
        case .mauve:
            CatppuccinPalette.mauve
        }
    }

    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .red:
            L10n.text(.colorRed, language: language)
        case .peach:
            L10n.text(.colorPeach, language: language)
        case .yellow:
            L10n.text(.colorYellow, language: language)
        case .green:
            L10n.text(.colorGreen, language: language)
        case .teal:
            L10n.text(.colorTeal, language: language)
        case .blue:
            L10n.text(.colorBlue, language: language)
        case .mauve:
            L10n.text(.colorMauve, language: language)
        }
    }
}

private extension SettingsStore.SystemMonitorRefreshInterval {
    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .realtime:
            L10n.text(.refreshRealtime, language: language)
        case .fiveSeconds:
            L10n.text(.refreshEveryFiveSeconds, language: language)
        case .tenSeconds:
            L10n.text(.refreshEveryTenSeconds, language: language)
        case .thirtySeconds:
            L10n.text(.refreshEveryThirtySeconds, language: language)
        case .oneMinute:
            L10n.text(.refreshEveryOneMinute, language: language)
        }
    }
}

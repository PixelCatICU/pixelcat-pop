import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore

    var body: some View {
        let language = settings.interfaceLanguage

        Form {
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
            .padding(.bottom, 8)

            Picker(L10n.text(.interfaceLanguage, language: language), selection: $settings.interfaceLanguage) {
                Text(L10n.text(.systemLanguage, language: language)).tag(AppLanguage.system)
                Text(L10n.text(.chineseInterface, language: language)).tag(AppLanguage.zhHans)
                Text(L10n.text(.englishInterface, language: language)).tag(AppLanguage.en)
            }

            Picker(L10n.text(.targetLanguage, language: language), selection: $settings.targetLanguageMode) {
                Text(L10n.text(.smartTargetMode, language: language)).tag(TargetLanguageMode.smart)
                Text(L10n.text(.fixedTargetMode, language: language)).tag(TargetLanguageMode.fixed)
            }
            .pickerStyle(.radioGroup)

            Picker(L10n.text(.defaultTarget, language: language), selection: $settings.fixedTargetLanguageCode) {
                ForEach(LanguageOption.supported) { language in
                    Text(language.localizedName(language: settings.interfaceLanguage)).tag(language.code)
                }
            }

            Picker(L10n.text(.panelPosition, language: language), selection: $settings.panelPlacement) {
                Text(L10n.text(.nearMouse, language: language)).tag(SettingsStore.PanelPlacement.mouse)
                Text(L10n.text(.screenCenter, language: language)).tag(SettingsStore.PanelPlacement.center)
            }

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

            Toggle(L10n.text(.startAtLogin, language: language), isOn: $settings.opensAtLogin)
                .disabled(true)
            Text(L10n.text(.loginItemReserved, language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
    }
}

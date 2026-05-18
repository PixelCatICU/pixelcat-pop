import Testing
@testable import PixelCatPop

struct L10nTests {
    @Test func localizesSettingsTextToChinese() {
        #expect(L10n.text(.interfaceLanguage, languageCode: "zh-Hans") == "界面语言")
        #expect(L10n.languageName(code: "ja", fallback: "Japanese", languageCode: "zh-Hans") == "日语")
    }

    @Test func fallsBackToEnglishForNonChineseLocales() {
        #expect(L10n.text(.interfaceLanguage, languageCode: "en-US") == "Interface language")
        #expect(L10n.languageName(code: "zh-Hans", fallback: "Chinese", languageCode: "en-US") == "Chinese")
    }
}

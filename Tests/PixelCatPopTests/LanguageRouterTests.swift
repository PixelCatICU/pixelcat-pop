import Testing
@testable import PixelCatPop

struct LanguageRouterTests {
    @Test func smartModeRoutesChineseToEnglish() {
        let router = LanguageRouter(mode: .smart, fixedTargetLanguageCode: "ja")

        let request = router.request(for: "你好，世界")

        #expect(request.targetLanguageCode == "en-US")
    }

    @Test func smartModeRoutesEnglishToChinese() {
        let router = LanguageRouter(mode: .smart, fixedTargetLanguageCode: "ja")

        let request = router.request(for: "Hello world")

        #expect(request.targetLanguageCode == "zh-Hans")
    }

    @Test func smartModeRoutesOtherLanguagesToConfiguredTarget() {
        let router = LanguageRouter(mode: .smart, fixedTargetLanguageCode: "en-US")

        let request = router.request(for: "こんにちは世界")

        #expect(request.targetLanguageCode == "en-US")
    }

    @Test func fixedModeUsesConfiguredDefaultTargetLanguage() {
        let router = LanguageRouter(mode: .fixed, fixedTargetLanguageCode: "ja")

        let request = router.request(for: "Hello world")

        #expect(request.targetLanguageCode == "ja")
    }

    @Test func fixedModeKeepsDetectedSourceEvenWhenItMatchesTarget() {
        let router = LanguageRouter(mode: .fixed, fixedTargetLanguageCode: "en-US")

        let request = router.request(for: "Hello world")

        #expect(request.sourceLanguageCode == "en")
        #expect(request.targetLanguageCode == "en-US")
    }
}

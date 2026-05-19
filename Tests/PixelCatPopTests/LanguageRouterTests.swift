import XCTest
@testable import PixelCatPop

final class LanguageRouterTests: XCTestCase {
    func testSmartModeRoutesChineseToEnglish() {
        let router = LanguageRouter(mode: .smart, fixedTargetLanguageCode: "ja")

        let request = router.request(for: "你好，世界")

        XCTAssertEqual(request.targetLanguageCode, "en-US")
    }

    func testSmartModeRoutesEnglishToChinese() {
        let router = LanguageRouter(mode: .smart, fixedTargetLanguageCode: "ja")

        let request = router.request(for: "Hello world")

        XCTAssertEqual(request.targetLanguageCode, "zh-Hans")
    }

    func testSmartModeRoutesOtherLanguagesToConfiguredTarget() {
        let router = LanguageRouter(mode: .smart, fixedTargetLanguageCode: "en-US")

        let request = router.request(for: "こんにちは世界")

        XCTAssertEqual(request.targetLanguageCode, "en-US")
    }

    func testFixedModeUsesConfiguredDefaultTargetLanguage() {
        let router = LanguageRouter(mode: .fixed, fixedTargetLanguageCode: "ja")

        let request = router.request(for: "Hello world")

        XCTAssertEqual(request.targetLanguageCode, "ja")
    }

    func testFixedModeKeepsDetectedSourceEvenWhenItMatchesTarget() {
        let router = LanguageRouter(mode: .fixed, fixedTargetLanguageCode: "en-US")

        let request = router.request(for: "Hello world")

        XCTAssertEqual(request.sourceLanguageCode, "en")
        XCTAssertEqual(request.targetLanguageCode, "en-US")
    }
}

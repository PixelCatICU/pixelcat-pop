import XCTest
@testable import PixelCatPop

final class L10nTests: XCTestCase {
    func testLocalizesSettingsTextToChinese() {
        XCTAssertEqual(L10n.text(.interfaceLanguage, languageCode: "zh-Hans"), "界面语言")
        XCTAssertEqual(L10n.text(.appSubtitle, languageCode: "zh-Hans"), "Mac 工具箱")
        XCTAssertEqual(L10n.languageName(code: "ja", fallback: "Japanese", languageCode: "zh-Hans"), "日语")
    }

    func testFallsBackToEnglishForNonChineseLocales() {
        XCTAssertEqual(L10n.text(.interfaceLanguage, languageCode: "en-US"), "Interface language")
        XCTAssertEqual(L10n.languageName(code: "zh-Hans", fallback: "Chinese", languageCode: "en-US"), "Chinese")
    }

    func testLocalizesRecordingMenuItems() {
        XCTAssertEqual(L10n.text(.startScreenRecording, languageCode: "zh-Hans"), "开始录屏")
        XCTAssertEqual(L10n.text(.stopScreenRecording, languageCode: "en-US"), "Stop Screen Recording")
    }

    func testLocalizesSystemMonitorLabels() {
        XCTAssertEqual(L10n.text(.avatarColorMetric, languageCode: "zh-Hans"), "头像颜色依据")
        XCTAssertEqual(L10n.text(.memoryUsage, languageCode: "en-US"), "Memory")
    }
}

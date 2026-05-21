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
        XCTAssertEqual(L10n.text(.restart, languageCode: "zh-Hans"), "重启")
        XCTAssertEqual(L10n.text(.restart, languageCode: "en-US"), "Restart")
    }

    func testLocalizesSystemMonitorLabels() {
        XCTAssertEqual(L10n.text(.avatarColorMetric, languageCode: "zh-Hans"), "头像颜色依据")
        XCTAssertEqual(L10n.text(.memoryUsage, languageCode: "en-US"), "Memory")
        XCTAssertEqual(L10n.text(.systemInfoRefreshInterval, languageCode: "zh-Hans"), "系统信息刷新")
        XCTAssertEqual(L10n.text(.refreshRealtime, languageCode: "en-US"), "Realtime (every 1 second)")
        XCTAssertEqual(L10n.text(.showNetworkInMenu, languageCode: "zh-Hans"), "在菜单中显示网络")
    }

    func testLocalizesToolboxSettingsLabels() {
        XCTAssertEqual(L10n.text(.recordingSettings, languageCode: "zh-Hans"), "录屏")
        XCTAssertEqual(L10n.text(.typingZoom, languageCode: "en-US"), "Keyboard input area zoom")
        XCTAssertEqual(L10n.text(.defaultAnnotationColor, languageCode: "zh-Hans"), "默认标注颜色")
        XCTAssertEqual(L10n.text(.appCleanerSettings, languageCode: "en-US"), "App Cleaner")
    }
}

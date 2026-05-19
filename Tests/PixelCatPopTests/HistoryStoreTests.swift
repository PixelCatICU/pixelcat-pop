import Foundation
import XCTest
@testable import PixelCatPop

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testKeepsLatestTwentyEntries() {
        let defaults = UserDefaults(suiteName: "PixelCatPopTests-\(UUID().uuidString)")!
        let history = HistoryStore(defaults: defaults)

        for index in 0..<25 {
            history.add(
                TranslationResult(
                    sourceText: "source \(index)",
                    translatedText: "target \(index)",
                    sourceLanguageCode: "en",
                    targetLanguageCode: "zh-Hans"
                ),
                enabled: true
            )
        }

        XCTAssertEqual(history.entries.count, 20)
        XCTAssertEqual(history.entries.first?.sourceText, "source 24")
        XCTAssertEqual(history.entries.last?.sourceText, "source 5")
    }

    func testIgnoresEntriesWhenDisabled() {
        let defaults = UserDefaults(suiteName: "PixelCatPopTests-\(UUID().uuidString)")!
        let history = HistoryStore(defaults: defaults)

        history.add(
            TranslationResult(
                sourceText: "source",
                translatedText: "target",
                sourceLanguageCode: "en",
                targetLanguageCode: "zh-Hans"
            ),
            enabled: false
        )

        XCTAssertTrue(history.entries.isEmpty)
    }
}

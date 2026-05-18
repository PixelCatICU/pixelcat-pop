import Foundation
import Testing
@testable import PixelCatPop

@MainActor
struct HistoryStoreTests {
    @Test func keepsLatestTwentyEntries() {
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

        #expect(history.entries.count == 20)
        #expect(history.entries.first?.sourceText == "source 24")
        #expect(history.entries.last?.sourceText == "source 5")
    }

    @Test func ignoresEntriesWhenDisabled() {
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

        #expect(history.entries.isEmpty)
    }
}

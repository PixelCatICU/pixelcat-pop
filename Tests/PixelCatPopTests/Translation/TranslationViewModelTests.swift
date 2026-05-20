import Foundation
import XCTest
@testable import PixelCatPop

@MainActor
final class TranslationViewModelTests: XCTestCase {
    func testPreservesStandaloneTermWhenSystemCannotTranslateIt() async throws {
        let viewModel = makeViewModel(translator: FailingTranslator())

        viewModel.translateNow("PixelCat")
        try await Task.sleep(for: .milliseconds(100))

        guard case .completed(let result) = viewModel.state else {
            XCTFail("Expected completed state")
            return
        }

        XCTAssertEqual(result.translatedText, "PixelCat")
    }

    func testKeepsSentenceTranslationFailuresVisible() async throws {
        let viewModel = makeViewModel(translator: FailingTranslator())

        viewModel.translateNow("PixelCat is a menu bar translator")
        try await Task.sleep(for: .milliseconds(100))

        guard case .failed(let message) = viewModel.state else {
            XCTFail("Expected failed state")
            return
        }

        XCTAssertEqual(message, "Unable to Translate")
    }

    private func makeViewModel(translator: Translating) -> TranslationViewModel {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let history = HistoryStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        return TranslationViewModel(settings: settings, history: history, translator: translator)
    }
}

private struct FailingTranslator: Translating {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        throw TestTranslationError.unableToTranslate
    }
}

private enum TestTranslationError: LocalizedError {
    case unableToTranslate

    var errorDescription: String? {
        "Unable to Translate"
    }
}

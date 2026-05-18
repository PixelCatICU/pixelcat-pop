import Foundation

#if canImport(Translation)
@preconcurrency import Translation
#endif

protocol Translating: Sendable {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
}

enum PixelCatTranslationError: LocalizedError {
    case emptyText
    case frameworkUnavailable
    case translationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "Nothing to translate."
        case .frameworkUnavailable:
            "The current SDK cannot import Apple's Translation framework. Build with full Xcode 16+."
        case .translationUnavailable(let message):
            message
        }
    }
}

struct SystemTranslationService: Translating, Sendable {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        let trimmed = request.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PixelCatTranslationError.emptyText
        }

        #if canImport(Translation)
        if #available(macOS 26.0, *) {
            let sourceCode = request.sourceLanguageCode ?? fallbackSourceLanguageCode(forTarget: request.targetLanguageCode)
            if isSameLanguageFamily(sourceCode, request.targetLanguageCode) {
                return TranslationResult(
                    sourceText: trimmed,
                    translatedText: trimmed,
                    sourceLanguageCode: sourceCode,
                    targetLanguageCode: request.targetLanguageCode
                )
            }

            let source = Locale.Language(identifier: sourceCode)
            let target = Locale.Language(identifier: request.targetLanguageCode)

            do {
                let session = TranslationSession(installedSource: source, target: target)
                try await session.prepareTranslation()
                let response = try await session.translate(trimmed)
                return TranslationResult(
                    sourceText: response.sourceText,
                    translatedText: response.targetText,
                    sourceLanguageCode: response.sourceLanguage.minimalIdentifier,
                    targetLanguageCode: response.targetLanguage.minimalIdentifier
                )
            } catch {
                throw PixelCatTranslationError.translationUnavailable(error.localizedDescription)
            }
        }
        #endif

        throw PixelCatTranslationError.frameworkUnavailable
    }

    private func fallbackSourceLanguageCode(forTarget target: String) -> String {
        target.hasPrefix("zh") ? LanguageRouter.defaultEnglishCode : LanguageRouter.defaultChineseCode
    }

    private func isSameLanguageFamily(_ source: String, _ target: String) -> Bool {
        if source == target { return true }
        return source.hasPrefix("zh") && target.hasPrefix("zh")
    }
}

extension Locale.Language {
    var minimalIdentifier: String {
        if let languageCode {
            return languageCode.identifier
        }
        return "\(self)"
    }
}

import Foundation
import NaturalLanguage

struct LanguageRouter {
    static let defaultEnglishCode = "en-US"
    static let defaultChineseCode = "zh-Hans"

    var mode: TargetLanguageMode
    var fixedTargetLanguageCode: String

    func request(for text: String) -> TranslationRequest {
        let source = detectedLanguageCode(for: text)
        let target: String

        switch mode {
        case .smart:
            if isChinesePrimary(text: text, detectedCode: source) {
                target = Self.defaultEnglishCode
            } else if source?.hasPrefix("en") == true {
                target = Self.defaultChineseCode
            } else {
                target = fixedTargetLanguageCode
            }
        case .fixed:
            target = fixedTargetLanguageCode
        }

        return TranslationRequest(
            sourceText: text,
            sourceLanguageCode: normalizedSourceCode(source, avoidingTarget: target),
            targetLanguageCode: target
        )
    }

    func isChinesePrimary(text: String, detectedCode: String?) -> Bool {
        let scalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else {
            return detectedCode?.hasPrefix("zh") == true
        }

        let chineseCount = scalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count

        if Double(chineseCount) / Double(scalars.count) >= 0.25 {
            return true
        }

        return detectedCode?.hasPrefix("zh") == true
    }

    private func detectedLanguageCode(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage, language != .undetermined else {
            return nil
        }

        return language.rawValue
    }

    private func normalizedSourceCode(_ source: String?, avoidingTarget target: String) -> String? {
        guard let source else { return nil }
        return source
    }
}

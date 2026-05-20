import Foundation

enum TargetLanguageMode: String, CaseIterable, Identifiable {
    case smart
    case fixed

    var id: String { rawValue }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case en

    var id: String { rawValue }

    var resolvedCode: String {
        switch self {
        case .system:
            Locale.preferredLanguages.first ?? "en"
        case .zhHans:
            "zh-Hans"
        case .en:
            "en"
        }
    }
}

struct LanguageOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    func localizedName(language: AppLanguage) -> String {
        L10n.languageName(code: code, fallback: name, languageCode: language.resolvedCode)
    }

    static let supported: [LanguageOption] = [
        .init(code: "zh-Hans", name: "Chinese"),
        .init(code: "en-US", name: "English"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "es", name: "Spanish")
    ]

    static func option(for code: String) -> LanguageOption {
        if code == "en" {
            return .init(code: "en-US", name: "English")
        }
        return supported.first { $0.code == code } ?? .init(code: code, name: code)
    }
}

struct TranslationRequest: Equatable {
    let sourceText: String
    let sourceLanguageCode: String?
    let targetLanguageCode: String
}

struct TranslationResult: Equatable, Identifiable, Codable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguageCode: String?
    let targetLanguageCode: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguageCode: String?,
        targetLanguageCode: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguageCode = sourceLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.createdAt = createdAt
    }
}

enum TranslationState: Equatable {
    case idle
    case translating
    case completed(TranslationResult)
    case failed(String)
}

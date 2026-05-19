import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var state: TranslationState = .idle
    @Published var isPinned: Bool = false
    @Published var focusRequestID = UUID()

    private let settings: SettingsStore
    private let history: HistoryStore
    private let translator: Translating
    private var translationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var activeRequest: TranslationRequest?

    init(
        settings: SettingsStore,
        history: HistoryStore,
        translator: Translating = SystemTranslationService()
    ) {
        self.settings = settings
        self.history = history
        self.translator = translator
    }

    var interfaceLanguage: AppLanguage {
        settings.interfaceLanguage
    }

    func loadAndTranslate(_ text: String) {
        inputText = text
        translateNow(text)
    }

    func resetForManualInput() {
        translationTask?.cancel()
        timeoutTask?.cancel()
        inputText = ""
        state = .idle
        activeRequest = nil
        focusRequestID = UUID()
    }

    func scheduleTranslation() {
        let text = inputText
        translationTask?.cancel()
        translationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.translateNow(text)
        }
    }

    func translateNow(_ text: String? = nil) {
        let textToTranslate = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToTranslate.isEmpty else {
            state = .idle
            activeRequest = nil
            return
        }

        translationTask?.cancel()
        timeoutTask?.cancel()
        state = .translating

        let request = settings.router.request(for: textToTranslate)
        activeRequest = request
        if let sourceLanguageCode = request.sourceLanguageCode,
           isSameLanguageFamily(sourceLanguageCode, request.targetLanguageCode) {
            complete(
                TranslationResult(
                    sourceText: textToTranslate,
                    translatedText: textToTranslate,
                    sourceLanguageCode: sourceLanguageCode,
                    targetLanguageCode: request.targetLanguageCode
                )
            )
            return
        }

        startTranslationTimeout(for: request)
        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await translator.translate(request)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.activeRequest == request else { return }
                    self.complete(result)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.activeRequest == request else { return }
                    if let fallbackResult = self.fallbackResult(for: request, error: error) {
                        self.complete(fallbackResult)
                        return
                    }

                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    func complete(_ result: TranslationResult) {
        timeoutTask?.cancel()
        activeRequest = nil
        state = .completed(result)
        history.add(result, enabled: settings.savesTranslationHistory)
    }

    func fail(_ message: String) {
        timeoutTask?.cancel()
        activeRequest = nil
        state = .failed(message)
    }

    private func startTranslationTimeout(for request: TranslationRequest) {
        timeoutTask = Task { [weak self] in
            let timeoutSeconds = max(20, min(180, request.sourceText.count / 500 + 15))
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self,
                      self.activeRequest == request,
                      self.state == .translating else {
                    return
                }

                self.fail(L10n.text(.translationTimeout, language: self.settings.interfaceLanguage))
            }
        }
    }

    private func isSameLanguageFamily(_ source: String, _ target: String) -> Bool {
        if source == target { return true }
        return source.hasPrefix("zh") && target.hasPrefix("zh")
    }

    private func fallbackResult(for request: TranslationRequest, error: Error) -> TranslationResult? {
        guard error.localizedDescription.localizedCaseInsensitiveContains("unable to translate"),
              shouldPreserveOriginalText(request.sourceText) else {
            return nil
        }

        return TranslationResult(
            sourceText: request.sourceText,
            translatedText: request.sourceText,
            sourceLanguageCode: request.sourceLanguageCode,
            targetLanguageCode: request.targetLanguageCode
        )
    }

    private func shouldPreserveOriginalText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else {
            return false
        }

        if trimmed.contains(where: { $0.isWhitespace || $0.isNewline }) {
            return false
        }

        if trimmed.contains("://") || trimmed.contains("@") {
            return true
        }

        let letters = trimmed.filter(\.isLetter)
        guard !letters.isEmpty else {
            return true
        }

        let uppercaseCount = letters.filter(\.isUppercase).count
        let lowercaseCount = letters.filter(\.isLowercase).count
        let hasDigit = trimmed.contains(where: \.isNumber)
        let hasIdentifierSeparator = trimmed.contains { "_-./#".contains($0) }

        return hasDigit || hasIdentifierSeparator || (uppercaseCount > 0 && lowercaseCount > 0)
    }
}

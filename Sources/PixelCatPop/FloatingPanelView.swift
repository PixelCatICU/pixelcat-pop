import AppKit
import AVFoundation
import SwiftUI

struct FloatingPanelView: View {
    static let panelWidth: CGFloat = 360
    private static let maxPanelHeight: CGFloat = 430
    private static let toolbarHeight: CGFloat = 24
    private static let footerHeight: CGFloat = 18
    private static let inlineToolSpacing: CGFloat = 3
    private static let inlineToolButtonSize: CGFloat = 22
    private static let inlineToolTrailingPadding: CGFloat = 7
    private static let inlineToolWidth = Self.inlineToolButtonSize * 2 + Self.inlineToolSpacing

    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var settings: SettingsStore
    let onPreferredHeightChange: (CGFloat) -> Void
    @FocusState private var isInputFocused: Bool
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var spokenText: String?

    private var inputHeight: CGFloat {
        let text = viewModel.inputText
        let explicitLines = max(1, text.components(separatedBy: .newlines).count)
        let wrappedLines = max(1, Int(ceil(Double(text.count) / 34.0)))
        let lineCount = max(explicitLines, wrappedLines)
        return min(150, max(48, CGFloat(lineCount) * 19 + 22))
    }

    private var resultHeight: CGFloat {
        switch viewModel.state {
        case .completed(let result):
            let lineCount = max(1, Int(ceil(Double(result.translatedText.count) / 32.0)))
            return min(150, max(54, CGFloat(lineCount) * 19 + 14))
        case .failed:
            return 42
        case .idle, .translating:
            return 30
        }
    }

    private var panelHeight: CGFloat {
        let verticalChrome: CGFloat = 24 + Self.toolbarHeight + 8 + 8 + 1 + 8 + Self.footerHeight
        return min(Self.maxPanelHeight, max(180, verticalChrome + inputHeight + resultHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Spacer()

                pinButton
            }
            .frame(height: Self.toolbarHeight)

            inputEditor

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)

            resultView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: Self.panelWidth, height: panelHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: viewModel.focusRequestID) {
            isInputFocused = true
        }
        .onChange(of: panelHeight) {
            onPreferredHeightChange(panelHeight)
        }
        .onAppear {
            isInputFocused = true
            onPreferredHeightChange(panelHeight)
        }
    }

    private var inputEditor: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $viewModel.inputText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .frame(height: inputHeight)
                .padding(7)
                .padding(.trailing, Self.inlineToolWidth + Self.inlineToolTrailingPadding + 7)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
                .onChange(of: viewModel.inputText) {
                    viewModel.scheduleTranslation()
                }

            HStack(spacing: Self.inlineToolSpacing) {
                readButton(text: viewModel.inputText)

                clearInputButton
            }
            .padding(.top, 7)
            .padding(.trailing, Self.inlineToolTrailingPadding)
        }
    }

    private var pinButton: some View {
        Button {
            viewModel.isPinned.toggle()
        } label: {
            Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.plain)
        .help(viewModel.isPinned ? L10n.text(.unpinPanel, language: settings.interfaceLanguage) : L10n.text(.pinPanel, language: settings.interfaceLanguage))
    }

    private var clearInputButton: some View {
        Button {
            stopSpeaking()
            viewModel.inputText = ""
            viewModel.translateNow("")
            isInputFocused = true
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .frame(width: Self.inlineToolButtonSize, height: Self.inlineToolButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.inputText.isEmpty ? .tertiary : .secondary)
        .disabled(viewModel.inputText.isEmpty)
        .help(L10n.text(.clear, language: settings.interfaceLanguage))
    }

    @ViewBuilder
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 5) {
            resultContent
                .frame(height: resultHeight)

            resultFooter
                .frame(height: Self.footerHeight)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch viewModel.state {
        case .idle:
            Text(viewModel.inputText.isEmpty ? L10n.text(.manualInputHint, language: settings.interfaceLanguage) : L10n.text(.doubleCopyHint, language: settings.interfaceLanguage))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .translating:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.text(.translating, language: settings.interfaceLanguage))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .completed(let result):
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    Text(result.translatedText)
                        .font(.system(size: 15, weight: .medium))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, Self.inlineToolWidth + Self.inlineToolTrailingPadding + 7)
                }

                HStack(spacing: Self.inlineToolSpacing) {
                    readButton(text: result.translatedText)
                    copyButton(text: result.translatedText)
                }
                .padding(.top, 1)
                .padding(.trailing, Self.inlineToolTrailingPadding)
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var resultFooter: some View {
        if case .completed(let result) = viewModel.state {
            HStack(alignment: .center, spacing: 8) {
                Text("\(result.sourceLanguageCode ?? L10n.text(.autoLanguage, language: settings.interfaceLanguage)) -> \(LanguageOption.option(for: result.targetLanguageCode).localizedName(language: settings.interfaceLanguage))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
        } else {
            Spacer(minLength: 0)
        }
    }

    private func copyButton(text: String) -> some View {
        Button {
            copyToPasteboard(text)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
                .frame(width: Self.inlineToolButtonSize, height: Self.inlineToolButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.text(.copyTranslation, language: settings.interfaceLanguage))
    }

    private func readButton(text: String) -> some View {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReadingThisText = speechSynthesizer.isSpeaking && spokenText == trimmedText

        return Button {
            if isReadingThisText {
                stopSpeaking()
            } else {
                speak(trimmedText)
            }
        } label: {
            Image(systemName: isReadingThisText ? "speaker.slash.fill" : "speaker.wave.2")
                .font(.system(size: 12, weight: .medium))
                .frame(width: Self.inlineToolButtonSize, height: Self.inlineToolButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(trimmedText.isEmpty ? .tertiary : .secondary)
        .disabled(trimmedText.isEmpty)
        .help(L10n.text(isReadingThisText ? .stopReading : .readText, language: settings.interfaceLanguage))
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        spokenText = text
        speechSynthesizer.speak(AVSpeechUtterance(string: text))
    }

    private func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        spokenText = nil
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

}

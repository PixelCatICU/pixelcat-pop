import AppKit
import AVFoundation
import CoreGraphics
import Foundation

@MainActor
final class RecordingController {
    private let settings: SettingsStore
    private let recorder = ScreenRecorder()
    private let interactionEffects = InteractionEffectsController()

    private(set) var isRecording = false
    private var currentOutputURL: URL?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            openScreenCapturePrivacy()
            return
        }

        Task {
            let hasMicrophoneAccess = settings.recordsMicrophoneAudio ? await requestMicrophoneAccess() : true
            guard hasMicrophoneAccess else {
                showError(RecordingPermissionError.microphoneDenied)
                return
            }

            let outputURL = makeOutputURL()
            currentOutputURL = outputURL
            isRecording = true
            interactionEffects.start(options: InteractionEffectsController.Options(
                playsMouseClickSound: settings.playsMouseClickSound,
                playsKeyboardInputSound: settings.playsKeyboardInputSound,
                showsClickRipple: settings.showsClickRipple,
                showsTypingZoom: settings.showsTypingZoom
            ))

            do {
                try await recorder.start(
                    to: outputURL,
                    includesSystemAudio: settings.recordsSystemAudio,
                    includesMicrophone: settings.recordsMicrophoneAudio
                )
            } catch {
                isRecording = false
                currentOutputURL = nil
                interactionEffects.stop()
                showError(error)
            }
        }
    }

    private func stopRecording() {
        Task {
            do {
                let url = try await recorder.stop()
                isRecording = false
                currentOutputURL = nil
                interactionEffects.stop()
                showSaved(url)
            } catch {
                isRecording = false
                currentOutputURL = nil
                interactionEffects.stop()
                showError(error)
            }
        }
    }

    private func makeOutputURL() -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "PixelCatPop-Recording-\(formatter.string(from: Date())).mp4"
        return desktop.appendingPathComponent(fileName)
    }

    private func openScreenCapturePrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func showSaved(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = L10n.text(.screenRecordingSaved, language: settings.interfaceLanguage)
        alert.informativeText = url.path
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = L10n.text(.screenRecordingFailed, language: settings.interfaceLanguage)
        alert.runModal()
    }

    private enum RecordingPermissionError: LocalizedError {
        case microphoneDenied

        var errorDescription: String? {
            "Microphone access is required to record microphone audio."
        }
    }
}

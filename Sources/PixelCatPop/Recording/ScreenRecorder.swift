@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

final class ScreenRecorder: NSObject, @unchecked Sendable {
    enum RecorderError: LocalizedError {
        case displayUnavailable
        case cannotAddVideoInput
        case cannotAddAudioInput
        case writerFailed

        var errorDescription: String? {
            switch self {
            case .displayUnavailable:
                "No display is available for recording."
            case .cannotAddVideoInput:
                "Cannot prepare video input for screen recording."
            case .cannotAddAudioInput:
                "Cannot prepare audio input for screen recording."
            case .writerFailed:
                "Screen recording writer failed."
            }
        }
    }

    private struct StoppedRecording: @unchecked Sendable {
        let stream: SCStream
        let writer: AVAssetWriter
        let input: AVAssetWriterInput
        let systemAudioInput: AVAssetWriterInput?
        let microphoneInput: AVAssetWriterInput?
        let url: URL
    }

    private let sampleQueue = DispatchQueue(label: "icu.pixelcat.pop.recording.samples")

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var firstSampleTime: CMTime?
    private var outputURL: URL?
    private var isStopping = false

    func start(to url: URL, includesSystemAudio: Bool = true, includesMicrophone: Bool = true) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
            throw RecorderError.displayUnavailable
        }

        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 6
        configuration.showsCursor = true
        configuration.capturesAudio = includesSystemAudio
        configuration.excludesCurrentProcessAudio = false
        configuration.captureMicrophone = includesMicrophone
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: display.width,
                AVVideoHeightKey: display.height
            ]
        )
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw RecorderError.cannotAddVideoInput
        }
        writer.add(input)

        let systemAudio = try makeAudioInput(for: writer, enabled: includesSystemAudio)
        let microphone = try makeAudioInput(for: writer, enabled: includesMicrophone)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        if includesSystemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        }
        if includesMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: sampleQueue)
        }

        sampleQueue.sync {
            self.stream = stream
            assetWriter = writer
            videoInput = input
            systemAudioInput = systemAudio
            microphoneInput = microphone
            firstSampleTime = nil
            outputURL = url
            isStopping = false
        }

        try await stream.startCapture()
    }

    func stop() async throws -> URL {
        let state = try sampleQueue.sync {
            guard let stream, let writer = assetWriter, let input = videoInput, let url = outputURL else {
                throw RecorderError.writerFailed
            }
            isStopping = true
            return StoppedRecording(
                stream: stream,
                writer: writer,
                input: input,
                systemAudioInput: systemAudioInput,
                microphoneInput: microphoneInput,
                url: url
            )
        }

        try await state.stream.stopCapture()
        try state.stream.removeStreamOutput(self, type: .screen)
        if state.systemAudioInput != nil {
            try state.stream.removeStreamOutput(self, type: .audio)
        }
        if state.microphoneInput != nil {
            try state.stream.removeStreamOutput(self, type: .microphone)
        }

        sampleQueue.sync {
            stream = nil
            assetWriter = nil
            videoInput = nil
            systemAudioInput = nil
            microphoneInput = nil
            firstSampleTime = nil
            outputURL = nil
            isStopping = false
        }

        return try await withCheckedThrowingContinuation { continuation in
            state.input.markAsFinished()
            state.systemAudioInput?.markAsFinished()
            state.microphoneInput?.markAsFinished()
            state.writer.finishWriting {
                if state.writer.status == .completed {
                    continuation.resume(returning: state.url)
                } else {
                    continuation.resume(throwing: state.writer.error ?? RecorderError.writerFailed)
                }
            }
        }
    }

    private func makeAudioInput(for writer: AVAssetWriter, enabled: Bool) throws -> AVAssetWriterInput? {
        guard enabled else { return nil }
        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 48_000,
                AVEncoderBitRateKey: 128_000
            ]
        )
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw RecorderError.cannotAddAudioInput
        }
        writer.add(input)
        return input
    }
}

extension ScreenRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferDataIsReady(sampleBuffer),
              !isStopping,
              let writer = assetWriter
        else {
            return
        }

        switch type {
        case .screen:
            appendScreenSample(sampleBuffer, writer: writer)
        case .audio:
            appendAudioSample(sampleBuffer, writer: writer, input: systemAudioInput)
        case .microphone:
            appendAudioSample(sampleBuffer, writer: writer, input: microphoneInput)
        @unknown default:
            break
        }
    }

    private func appendScreenSample(_ sampleBuffer: CMSampleBuffer, writer: AVAssetWriter) {
        guard isCompleteFrame(sampleBuffer), let input = videoInput else { return }
        guard startWriterIfNeeded(writer, sampleBuffer: sampleBuffer) else { return }
        guard input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    private func appendAudioSample(_ sampleBuffer: CMSampleBuffer, writer: AVAssetWriter, input: AVAssetWriterInput?) {
        guard let input else { return }
        guard startWriterIfNeeded(writer, sampleBuffer: sampleBuffer) else { return }
        guard input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    private func startWriterIfNeeded(_ writer: AVAssetWriter, sampleBuffer: CMSampleBuffer) -> Bool {
        if firstSampleTime == nil {
            let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard writer.startWriting() else { return false }
            writer.startSession(atSourceTime: sampleTime)
            firstSampleTime = sampleTime
        }
        return true
    }

    private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int
        else {
            return false
        }

        return status == SCFrameStatus.complete.rawValue
    }
}

extension ScreenRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        isStopping = true
    }
}

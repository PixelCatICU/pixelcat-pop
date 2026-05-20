import AppKit
import ApplicationServices
import AVFoundation
import QuartzCore

@MainActor
final class InteractionEffectsController {
    private let soundPlayer = InteractionSoundPlayer()
    private let rippleOverlay = ClickRippleOverlay()
    private let typingZoomOverlay = TypingZoomOverlay()
    private var mouseMonitor: Any?
    private var keyboardMonitor: Any?

    func start() {
        guard mouseMonitor == nil, keyboardMonitor == nil else { return }
        soundPlayer.prepare()

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.soundPlayer.playMouseClick()
                self?.rippleOverlay.show(at: NSEvent.mouseLocation)
            }
        }

        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                guard Self.isTypingEvent(event) else { return }
                self?.soundPlayer.playKeyPress()
                self?.typingZoomOverlay.show(fallbackPoint: NSEvent.mouseLocation)
            }
        }
    }

    func stop() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil

        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
        keyboardMonitor = nil
    }

    private static func isTypingEvent(_ event: NSEvent) -> Bool {
        guard !event.isARepeat,
              let characters = event.charactersIgnoringModifiers,
              !characters.isEmpty
        else {
            return false
        }

        let shortcutFlags: NSEvent.ModifierFlags = [.command, .control, .option]
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.intersection(shortcutFlags).isEmpty
    }
}

@MainActor
private final class TypingZoomOverlay {
    private var windows: [NSWindow] = []

    func show(fallbackPoint: NSPoint) {
        let targetFrame = focusedElementFrame() ?? NSRect(
            x: fallbackPoint.x - 110,
            y: fallbackPoint.y - 28,
            width: 220,
            height: 56
        )
        let frame = targetFrame.insetBy(dx: -10, dy: -8)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = TypingZoomView(frame: NSRect(origin: .zero, size: frame.size))
        window.orderFrontRegardless()
        windows.append(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self, weak window] in
            guard let self, let window else { return }
            window.orderOut(nil)
            windows.removeAll { $0 === window }
        }
    }

    private func focusedElementFrame() -> NSRect? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedElement = focusedValue
        else {
            return nil
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
              size.width > 8,
              size.height > 8
        else {
            return nil
        }

        return NSRect(origin: position, size: size)
    }
}

private final class TypingZoomView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        installZoomPulse()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func installZoomPulse() {
        guard let layer else { return }
        let roundedRect = bounds.insetBy(dx: 3, dy: 3)
        let highlight = CAShapeLayer()
        highlight.path = CGPath(roundedRect: roundedRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        highlight.fillColor = NSColor.systemBlue.withAlphaComponent(0.10).cgColor
        highlight.strokeColor = NSColor.systemBlue.withAlphaComponent(0.70).cgColor
        highlight.lineWidth = 3
        highlight.opacity = 0
        layer.addSublayer(highlight)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.94
        scale.toValue = 1.04

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.88
        opacity.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 0.32
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        highlight.add(group, forKey: "typingZoom")
    }
}

@MainActor
private final class ClickRippleOverlay {
    private var windows: [NSWindow] = []

    func show(at point: NSPoint) {
        let size = NSSize(width: 112, height: 112)
        let origin = NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = ClickRippleView(frame: NSRect(origin: .zero, size: size))
        window.orderFrontRegardless()
        windows.append(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { [weak self, weak window] in
            guard let self, let window else { return }
            window.orderOut(nil)
            windows.removeAll { $0 === window }
        }
    }
}

private final class ClickRippleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        installRipple()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func installRipple() {
        guard let layer else { return }
        let ring = CAShapeLayer()
        let inset: CGFloat = 28
        ring.path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.systemBlue.withAlphaComponent(0.88).cgColor
        ring.lineWidth = 4
        ring.opacity = 0
        layer.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.45
        scale.toValue = 1.75

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.95
        opacity.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 0.46
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        ring.add(group, forKey: "clickRipple")
    }
}

@MainActor
private final class InteractionSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var clickBuffer: AVAudioPCMBuffer?
    private var keyBuffer: AVAudioPCMBuffer?
    private var isPrepared = false

    func prepare() {
        guard !isPrepared else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else { return }

        clickBuffer = makeBuffer(format: format, duration: 0.045, frequency: 1_650, volume: 0.35, decay: 40)
        keyBuffer = makeBuffer(format: format, duration: 0.032, frequency: 920, volume: 0.22, decay: 55)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.play()
        isPrepared = true
    }

    func playMouseClick() {
        play(clickBuffer)
    }

    func playKeyPress() {
        play(keyBuffer)
    }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        if !engine.isRunning {
            try? engine.start()
            player.play()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interruptsAtLoop, completionHandler: nil)
    }

    private func makeBuffer(
        format: AVAudioFormat,
        duration: TimeInterval,
        frequency: Double,
        volume: Float,
        decay: Double
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let envelope = Float(exp(-decay * time))
            channel[frame] = sin(Float(2 * Double.pi * frequency * time)) * envelope * volume
        }

        return buffer
    }
}

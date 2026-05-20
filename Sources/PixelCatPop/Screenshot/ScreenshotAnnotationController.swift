import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ScreenshotAnnotationController: NSObject {
    private let settings: SettingsStore
    private var selectionSession: ScreenshotSelectionSession?
    private var editorWindows: [NSWindow] = []

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            openScreenCapturePrivacy()
            return
        }

        let session = ScreenshotSelectionSession { [weak self] rect, screen in
            self?.selectionSession = nil
            guard let rect, let screen else { return }
            self?.capture(rect: rect, on: screen)
        }
        selectionSession = session
        session.start()
    }

    func openTestEditor(snapshotPath: String? = nil) {
        openEditor(image: Self.testImage())
        guard let snapshotPath else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            renderFrontEditor(to: URL(fileURLWithPath: snapshotPath))
            NSApp.terminate(nil)
        }
    }

    private func capture(rect: NSRect, on screen: NSScreen) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard let image = await Self.captureImage(rect: rect, on: screen) else {
                NSSound.beep()
                return
            }
            openEditor(image: image)
        }
    }

    private func openEditor(image: NSImage) {
        let controller = ScreenshotEditorViewController(image: image)
        let windowSize = Self.editorWindowSize(for: image)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text(.annotateScreenshot, language: settings.interfaceLanguage)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentViewController = controller
        controller.preferredContentSize = windowSize
        window.minSize = ScreenshotEditorLayout.minimumWindowSize
        window.maxSize = ScreenshotEditorLayout.maximumWindowSize(for: NSScreen.main)
        window.setContentSize(windowSize)
        window.setFrameAutosaveName("PixelCatPopScreenshotEditor")
        window.level = .floating
        if !window.setFrameUsingName("PixelCatPopScreenshotEditor") {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        editorWindows.append(window)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func renderFrontEditor(to url: URL) {
        guard let window = editorWindows.last,
              let contentView = window.contentView,
              let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds)
        else {
            return
        }

        contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }

    private func openScreenCapturePrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func editorWindowSize(for image: NSImage) -> NSSize {
        let minimumSize = ScreenshotEditorLayout.minimumWindowSize
        let maximumSize = ScreenshotEditorLayout.maximumWindowSize(for: NSScreen.main)
        let naturalSize = NSSize(
            width: image.size.width + ScreenshotEditorLayout.canvasPadding * 2,
            height: image.size.height + ScreenshotEditorLayout.canvasPadding * 2 + ScreenshotEditorLayout.toolbarAreaHeight
        )

        return NSSize(
            width: min(maximumSize.width, max(minimumSize.width, naturalSize.width)),
            height: min(maximumSize.height, max(minimumSize.height, naturalSize.height))
        )
    }

    private static func captureImage(rect: NSRect, on screen: NSScreen) async -> NSImage? {
        guard #available(macOS 15.2, *) else {
            return nil
        }

        let captureRect = screenCaptureRect(for: rect, on: screen)
        return await withCheckedContinuation { continuation in
            SCScreenshotManager.captureImage(in: captureRect) { image, _ in
                guard let image else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: NSImage(cgImage: image, size: rect.size))
            }
        }
    }

    private static func screenCaptureRect(for appKitRect: NSRect, on screen: NSScreen) -> CGRect {
        CGRect(
            x: appKitRect.minX,
            y: screen.frame.maxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    private static func testImage() -> NSImage {
        let size = NSSize(width: 520, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        CatppuccinPalette.base.setFill()
        NSRect(origin: .zero, size: size).fill()

        CatppuccinPalette.blue.setFill()
        NSBezierPath(roundedRect: NSRect(x: 32, y: 184, width: 456, height: 72), xRadius: 8, yRadius: 8).fill()

        CatppuccinPalette.green.setFill()
        NSBezierPath(roundedRect: NSRect(x: 32, y: 52, width: 210, height: 94), xRadius: 8, yRadius: 8).fill()

        CatppuccinPalette.yellow.setFill()
        NSBezierPath(roundedRect: NSRect(x: 278, y: 52, width: 210, height: 94), xRadius: 8, yRadius: 8).fill()

        let title = "PixelCat Pop Screenshot Editor"
        title.draw(
            at: NSPoint(x: 52, y: 207),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 28),
                .foregroundColor: CatppuccinPalette.crust
            ]
        )
        image.unlockFocus()
        return image
    }
}

@MainActor
private final class ScreenshotSelectionSession {
    private var windows: [ScreenshotSelectionWindow] = []
    private let onFinish: (NSRect?, NSScreen?) -> Void

    init(onFinish: @escaping (NSRect?, NSScreen?) -> Void) {
        self.onFinish = onFinish
    }

    func start() {
        windows = NSScreen.screens.map { screen in
            let window = ScreenshotSelectionWindow(targetScreen: screen)
            window.selectionView.onFinish = { [weak self, weak window] rect in
                self?.finish(rect: rect, screen: window?.targetScreen)
            }
            window.makeKeyAndOrderFront(nil)
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(rect: NSRect?, screen: NSScreen?) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onFinish(rect, screen)
    }
}

private final class ScreenshotSelectionWindow: NSWindow {
    let targetScreen: NSScreen
    let selectionView = ScreenshotSelectionView()

    init(targetScreen: NSScreen) {
        self.targetScreen = targetScreen
        super.init(
            contentRect: targetScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
}

private final class ScreenshotSelectionView: NSView {
    var onFinish: ((NSRect?) -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        CatppuccinPalette.crust.withAlphaComponent(0.48).setFill()
        bounds.fill()

        guard currentRect.width > 1, currentRect.height > 1 else { return }
        NSColor.clear.setFill()
        currentRect.fill(using: .clear)
        CatppuccinPalette.blue.setStroke()
        let path = NSBezierPath(rect: currentRect)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(startPoint.x, point.x),
            y: min(startPoint.y, point.y),
            width: abs(startPoint.x - point.x),
            height: abs(startPoint.y - point.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width >= 8, currentRect.height >= 8 else {
            onFinish?(nil)
            return
        }
        let screenRect = window?.convertToScreen(currentRect) ?? currentRect
        onFinish?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onFinish?(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

private enum AnnotationTool: String, CaseIterable {
    case rectangle
    case arrow
    case text
    case mosaic

    var title: String {
        switch self {
        case .rectangle: "Rectangle"
        case .arrow: "Arrow"
        case .text: "Text"
        case .mosaic: "Mosaic"
        }
    }

    var systemImageName: String {
        switch self {
        case .rectangle: "rectangle"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .mosaic: "square.grid.3x3.fill"
        }
    }

    var defaultColor: NSColor {
        switch self {
        case .rectangle, .arrow, .text: CatppuccinPalette.red
        case .mosaic: CatppuccinPalette.overlay0
        }
    }
}

private enum AnnotationItem {
    case rectangle(CGRect, NSColor)
    case arrow(CGPoint, CGPoint, NSColor)
    case text(String, CGPoint, NSColor, CGFloat)
    case mosaic(CGRect, CGFloat)

    var bounds: CGRect {
        switch self {
        case .rectangle(let rect, _), .mosaic(let rect, _):
            return rect
        case .arrow(let start, let end, _):
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(start.x - end.x),
                height: abs(start.y - end.y)
            ).insetBy(dx: -12, dy: -12)
        case .text(let text, let origin, _, let fontSize):
            let size = (text as NSString).size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: fontSize)])
            return CGRect(origin: origin, size: size).insetBy(dx: -6, dy: -5)
        }
    }

    mutating func move(by delta: CGPoint) {
        switch self {
        case .rectangle(let rect, let color):
            self = .rectangle(rect.offsetBy(dx: delta.x, dy: delta.y), color)
        case .arrow(let start, let end, let color):
            self = .arrow(
                CGPoint(x: start.x + delta.x, y: start.y + delta.y),
                CGPoint(x: end.x + delta.x, y: end.y + delta.y),
                color
            )
        case .text(let text, let origin, let color, let fontSize):
            self = .text(text, CGPoint(x: origin.x + delta.x, y: origin.y + delta.y), color, fontSize)
        case .mosaic(let rect, let strength):
            self = .mosaic(rect.offsetBy(dx: delta.x, dy: delta.y), strength)
        }
    }

    mutating func resize(to point: CGPoint) {
        switch self {
        case .rectangle(let rect, let color):
            self = .rectangle(resizedRect(from: rect, to: point), color)
        case .arrow(let start, _, let color):
            self = .arrow(start, point, color)
        case .text:
            break
        case .mosaic(let rect, let strength):
            self = .mosaic(resizedRect(from: rect, to: point), strength)
        }
    }

    mutating func recolor(_ color: NSColor) {
        switch self {
        case .rectangle(let rect, _):
            self = .rectangle(rect, color)
        case .arrow(let start, let end, _):
            self = .arrow(start, end, color)
        case .text(let text, let origin, _, let fontSize):
            self = .text(text, origin, color, fontSize)
        case .mosaic:
            break
        }
    }

    mutating func updateText(_ text: String) {
        if case .text(_, let origin, let color, let fontSize) = self {
            self = .text(text, origin, color, fontSize)
        }
    }

    mutating func updateFontSize(_ fontSize: CGFloat) {
        if case .text(let text, let origin, let color, _) = self {
            self = .text(text, origin, color, fontSize)
        }
    }

    private func resizedRect(from rect: CGRect, to point: CGPoint) -> CGRect {
        CGRect(
            x: rect.minX,
            y: rect.minY,
            width: max(6, point.x - rect.minX),
            height: max(6, point.y - rect.minY)
        )
    }
}

private enum CanvasDragMode {
    case create
    case move(index: Int)
    case resize(index: Int)
}

private struct CanvasSnapshot {
    let items: [AnnotationItem]
    let selectedIndex: Int?
}

private final class ScreenshotEditorViewController: NSViewController {
    private let image: NSImage
    private let canvasView: ScreenshotAnnotationCanvasView
    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private var colorButton: ColorSwatchButton?
    private var colorPopover: NSPopover?
    private var mosaicStrengthSlider: NSSlider?
    private var textSizeSlider: NSSlider?
    private var paddedDocumentView: PaddedCanvasDocumentView?
    private var zoomLabel: NSTextField?

    init(image: NSImage) {
        self.image = image
        self.canvasView = ScreenshotAnnotationCanvasView(image: image)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = GlassEffectView(material: .hudWindow, blendingMode: .withinWindow)
        root.frame = NSRect(
            x: 0,
            y: 0,
            width: image.size.width + ScreenshotEditorLayout.canvasPadding * 2,
            height: image.size.height + ScreenshotEditorLayout.canvasPadding * 2 + ScreenshotEditorLayout.toolbarAreaHeight
        )

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = CatppuccinPalette.mantle.withAlphaComponent(0.72).cgColor
        toolbar.layer?.cornerRadius = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

        for tool in AnnotationTool.allCases {
            let button = NSButton(
                image: Self.symbolImage(tool.systemImageName, tool.title, color: CatppuccinPalette.subtext1),
                target: self,
                action: #selector(selectTool(_:))
            )
            button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
            button.setButtonType(.toggle)
            button.bezelStyle = .texturedRounded
            button.toolTip = tool.title
            button.state = tool == canvasView.tool ? .on : .off
            updateToolButtonAppearance(button)
            toolButtons[tool] = button
            toolbar.addArrangedSubview(button)
        }

        toolbar.addArrangedSubview(separator())
        toolbar.addArrangedSubview(colorSwatchButton())
        toolbar.addArrangedSubview(mosaicStrengthControl())
        toolbar.addArrangedSubview(textSizeControl())
        toolbar.addArrangedSubview(separator())
        toolbar.addArrangedSubview(toolbarButton("arrow.uturn.backward", "Undo", #selector(undo), keyEquivalent: "z"))
        toolbar.addArrangedSubview(toolbarButton("trash", "Clear", #selector(clear)))
        toolbar.addArrangedSubview(toolbarButton("minus.magnifyingglass", "Zoom Out", #selector(zoomOut)))
        toolbar.addArrangedSubview(zoomText())
        toolbar.addArrangedSubview(toolbarButton("plus.magnifyingglass", "Zoom In", #selector(zoomIn)))
        toolbar.addArrangedSubview(toolbarButton("arrow.up.left.and.arrow.down.right", "Fit", #selector(fitZoom)))
        toolbar.addArrangedSubview(NSView())
        toolbar.addArrangedSubview(toolbarButton("doc.on.doc", "Copy", #selector(copyImage), keyEquivalent: "c"))
        toolbar.addArrangedSubview(toolbarButton("square.and.arrow.down", "Save", #selector(saveImage), keyEquivalent: "s"))

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView = CenteringClipView()
        canvasView.frame = NSRect(origin: .zero, size: image.size)
        canvasView.autoresizingMask = []
        let paddedDocumentView = PaddedCanvasDocumentView(canvasView: canvasView, padding: ScreenshotEditorLayout.canvasPadding)
        self.paddedDocumentView = paddedDocumentView
        scrollView.documentView = paddedDocumentView

        root.addSubview(toolbar)
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            toolbar.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            toolbar.heightAnchor.constraint(equalToConstant: 34),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])

        view = root
        canvasView.onZoomChange = { [weak self] scale in
            self?.paddedDocumentView?.updateCanvasScale(scale)
            self?.zoomLabel?.stringValue = "\(Int(scale * 100))%"
        }
        canvasView.onToolChange = { [weak self] _ in
            self?.updateToolSelection()
        }
        canvasView.onTextSizeChange = { [weak self] fontSize in
            self?.textSizeSlider?.doubleValue = Double(fontSize)
        }
    }

    private func separator() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func toolbarButton(_ symbol: String, _ help: String, _ action: Selector, keyEquivalent: String = "") -> NSButton {
        let button = NSButton(image: Self.symbolImage(symbol, help, color: CatppuccinPalette.subtext1), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = help
        button.keyEquivalent = keyEquivalent
        button.keyEquivalentModifierMask = keyEquivalent.isEmpty ? [] : .command
        return button
    }

    private static func symbolImage(_ symbol: String, _ description: String, color: NSColor) -> NSImage {
        guard let source = NSImage(systemSymbolName: symbol, accessibilityDescription: description) else {
            return NSImage()
        }

        let image = NSImage(size: source.size)
        image.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: source.size), from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        NSRect(origin: .zero, size: source.size).fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func colorSwatchButton() -> NSButton {
        let button = ColorSwatchButton(color: canvasView.annotationColor)
        button.target = self
        button.action = #selector(showColorPopover(_:))
        button.toolTip = "Color"
        colorButton = button
        return button
    }

    private func mosaicStrengthControl() -> NSSlider {
        let slider = NSSlider(value: Double(canvasView.mosaicBlockSize), minValue: 6, maxValue: 28, target: self, action: #selector(changeMosaicStrength(_:)))
        slider.toolTip = "Mosaic Strength: larger blocks hide more detail"
        slider.controlSize = .small
        slider.frame = NSRect(x: 0, y: 0, width: 82, height: 24)
        slider.isHidden = canvasView.tool != .mosaic
        mosaicStrengthSlider = slider
        return slider
    }

    private func textSizeControl() -> NSSlider {
        let slider = NSSlider(value: Double(canvasView.annotationTextSize), minValue: 12, maxValue: 64, target: self, action: #selector(changeTextSize(_:)))
        slider.toolTip = "Text Size"
        slider.controlSize = .small
        slider.frame = NSRect(x: 0, y: 0, width: 82, height: 24)
        slider.isHidden = canvasView.tool != .text
        textSizeSlider = slider
        return slider
    }

    private func zoomText() -> NSTextField {
        let label = NSTextField(labelWithString: "100%")
        label.alignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textColor = CatppuccinPalette.subtext1
        label.widthAnchor.constraint(equalToConstant: 44).isActive = true
        zoomLabel = label
        return label
    }

    @objc private func selectTool(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue, let tool = AnnotationTool(rawValue: rawValue) else { return }
        canvasView.tool = tool
        updateToolSelection()
        view.window?.makeFirstResponder(canvasView)
    }

    @objc private func showColorPopover(_ sender: NSButton) {
        colorPopover?.close()
        let controller = ColorPaletteViewController(selectedColor: canvasView.annotationColor) { [weak self] color in
            self?.canvasView.annotationColor = color
            self?.colorButton?.color = color
            self?.updateToolSelection()
            self?.view.window?.makeFirstResponder(self?.canvasView)
        }
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        colorPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    @objc private func changeMosaicStrength(_ sender: NSSlider) {
        canvasView.mosaicBlockSize = CGFloat(sender.doubleValue)
        view.window?.makeFirstResponder(canvasView)
    }

    @objc private func changeTextSize(_ sender: NSSlider) {
        canvasView.annotationTextSize = CGFloat(sender.doubleValue)
        view.window?.makeFirstResponder(canvasView)
    }

    @objc private func undo() {
        canvasView.undo()
    }

    @objc private func zoomIn() {
        canvasView.zoom(by: 1.2)
    }

    @objc private func zoomOut() {
        canvasView.zoom(by: 1 / 1.2)
    }

    @objc private func fitZoom() {
        canvasView.fitZoom(in: view.bounds.size)
    }

    private func updateToolSelection() {
        mosaicStrengthSlider?.isHidden = canvasView.tool != .mosaic
        textSizeSlider?.isHidden = canvasView.tool != .text
        for (tool, button) in toolButtons {
            button.state = tool == canvasView.tool ? .on : .off
            updateToolButtonAppearance(button)
        }
    }

    private func updateToolButtonAppearance(_ button: NSButton) {
        let tool = button.identifier.flatMap { AnnotationTool(rawValue: $0.rawValue) }
        if button.state == .on {
            let tint = tool == .mosaic ? CatppuccinPalette.mauve : canvasView.annotationColor
            if let tool {
                button.image = Self.symbolImage(tool.systemImageName, tool.title, color: tint)
            }
            button.bezelColor = tint.withAlphaComponent(0.22)
        } else {
            if let tool {
                button.image = Self.symbolImage(tool.systemImageName, tool.title, color: CatppuccinPalette.subtext1)
            }
            button.bezelColor = nil
        }
    }

    @objc private func clear() {
        canvasView.clear()
    }

    @objc private func copyImage() {
        let image = canvasView.renderedImage()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    @objc private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "PixelCat-Screenshot.png"
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url, let image = self?.canvasView.renderedImage(), let data = image.pngData else { return }
            try? data.write(to: url)
        }
    }
}

private enum ScreenshotEditorLayout {
    static let canvasPadding: CGFloat = 24
    static let toolbarAreaHeight: CGFloat = 78
    static let minimumWindowSize = NSSize(width: 700, height: 420)
    static let maximumContentSize = NSSize(width: 1200, height: 820)

    static func maximumWindowSize(for screen: NSScreen?) -> NSSize {
        let visibleFrame = screen?.visibleFrame ?? NSRect(origin: .zero, size: maximumContentSize)
        return NSSize(
            width: min(maximumContentSize.width, max(minimumWindowSize.width, visibleFrame.width - 80)),
            height: min(maximumContentSize.height, max(minimumWindowSize.height, visibleFrame.height - 80))
        )
    }
}

private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return rect }

        if documentView.frame.width < bounds.width {
            rect.origin.x = (documentView.frame.width - bounds.width) / 2
        }
        if documentView.frame.height < bounds.height {
            rect.origin.y = (documentView.frame.height - bounds.height) / 2
        }

        return rect
    }
}

private final class PaddedCanvasDocumentView: NSView {
    private let canvasView: ScreenshotAnnotationCanvasView
    private let padding: CGFloat
    private var canvasScale: CGFloat = 1

    init(canvasView: ScreenshotAnnotationCanvasView, padding: CGFloat) {
        self.canvasView = canvasView
        self.padding = padding
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: canvasView.frame.width + padding * 2,
            height: canvasView.frame.height + padding * 2
        ))
        addSubview(canvasView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        CatppuccinPalette.crust.setFill()
        bounds.fill()
    }

    override func layout() {
        super.layout()
        let canvasSize = NSSize(
            width: canvasView.imageSize.width * canvasScale,
            height: canvasView.imageSize.height * canvasScale
        )
        canvasView.frame = NSRect(
            x: max(padding, (bounds.width - canvasSize.width) / 2),
            y: max(padding, (bounds.height - canvasSize.height) / 2),
            width: canvasSize.width,
            height: canvasSize.height
        )
        canvasView.setBoundsSize(canvasView.imageSize)
    }

    func updateCanvasScale(_ scale: CGFloat) {
        canvasScale = scale
        setFrameSize(NSSize(
            width: canvasView.imageSize.width * scale + padding * 2,
            height: canvasView.imageSize.height * scale + padding * 2
        ))
        needsLayout = true
    }
}

private final class ColorSwatchButton: NSButton {
    var color: NSColor {
        didSet { needsDisplay = true }
    }

    init(color: NSColor) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 34, height: 28))
        bezelStyle = .texturedRounded
        setButtonType(.momentaryPushIn)
        imagePosition = .noImage
        title = ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 34, height: 28)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let swatchRect = bounds.insetBy(dx: 9, dy: 6)
        CatppuccinPalette.surface1.setStroke()
        let path = NSBezierPath(ovalIn: swatchRect)
        path.lineWidth = 1
        color.setFill()
        path.fill()
        path.stroke()
    }
}

private final class ColorPaletteViewController: NSViewController {
    private let selectedColor: NSColor
    private let onSelect: (NSColor) -> Void
    private var colorButtons: [ColorChoiceButton] = []
    private let colors: [NSColor] = [
        CatppuccinPalette.red,
        CatppuccinPalette.peach,
        CatppuccinPalette.yellow,
        CatppuccinPalette.green,
        CatppuccinPalette.teal,
        CatppuccinPalette.blue,
        CatppuccinPalette.mauve,
        CatppuccinPalette.text
    ]

    init(selectedColor: NSColor, onSelect: @escaping (NSColor) -> Void) {
        self.selectedColor = selectedColor
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSStackView()
        root.orientation = .horizontal
        root.alignment = .centerY
        root.spacing = 8
        root.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        root.wantsLayer = true
        root.layer?.backgroundColor = CatppuccinPalette.base.cgColor

        for color in colors {
            let button = ColorChoiceButton(color: color)
            button.state = color.isVisuallyEqual(to: selectedColor) ? .on : .off
            button.target = self
            button.action = #selector(selectColor(_:))
            colorButtons.append(button)
            root.addArrangedSubview(button)
        }

        let customColor = NSColorWell(frame: NSRect(x: 0, y: 0, width: 42, height: 28))
        customColor.color = selectedColor
        customColor.target = self
        customColor.action = #selector(selectCustomColor(_:))
        root.addArrangedSubview(customColor)
        view = root
        preferredContentSize = NSSize(width: 360, height: 48)
    }

    @objc private func selectColor(_ sender: ColorChoiceButton) {
        colorButtons.forEach { $0.state = $0 === sender ? .on : .off }
        onSelect(sender.color)
    }

    @objc private func selectCustomColor(_ sender: NSColorWell) {
        colorButtons.forEach { $0.state = .off }
        onSelect(sender.color)
    }
}

private final class ColorChoiceButton: NSButton {
    let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        setButtonType(.toggle)
        bezelStyle = .regularSquare
        title = ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 26, height: 26)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
        let outer = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        (state == .on ? CatppuccinPalette.mauve : CatppuccinPalette.surface1).setStroke()
        outer.lineWidth = state == .on ? 2 : 1
        outer.stroke()

        let inner = NSBezierPath(ovalIn: bounds.insetBy(dx: 6, dy: 6))
        color.setFill()
        inner.fill()
    }
}

private final class ScreenshotAnnotationCanvasView: NSView {
    var tool: AnnotationTool = .rectangle {
        didSet {
            onToolChange?(tool)
        }
    }
    var annotationColor: NSColor = CatppuccinPalette.red {
        didSet {
            applyColorToSelectedItem()
        }
    }
    var annotationTextSize: CGFloat = 24 {
        didSet {
            applyTextSizeToSelectedItem()
        }
    }
    var mosaicBlockSize: CGFloat = 12
    var onZoomChange: ((CGFloat) -> Void)?
    var onToolChange: ((AnnotationTool) -> Void)?
    var onTextSizeChange: ((CGFloat) -> Void)?
    var imageSize: NSSize { image.size }

    private let image: NSImage
    private var items: [AnnotationItem] = []
    private var undoStack: [CanvasSnapshot] = []
    private var draftItem: AnnotationItem?
    private var dragStart: NSPoint?
    private var lastDragPoint: NSPoint?
    private var dragSnapshot: CanvasSnapshot?
    private var selectedIndex: Int?
    private var dragMode: CanvasDragMode?
    private var editingTextIndex: Int?
    private var zoomScale: CGFloat = 1

    init(image: NSImage) {
        self.image = image
        super.init(frame: NSRect(origin: .zero, size: image.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "z":
                undo()
                return
            case "c":
                copyRenderedImage()
                return
            case "s":
                saveRenderedImage()
                return
            default:
                break
            }
        } else if let key = event.charactersIgnoringModifiers {
            switch key {
            case "1":
                tool = .rectangle
                return
            case "2":
                tool = .arrow
                return
            case "3":
                tool = .text
                return
            case "4":
                tool = .mosaic
                return
            default:
                break
            }
        }

        switch event.keyCode {
        case 51, 117:
            deleteSelectedItem()
        case 53:
            cancelCurrentInteraction()
        default:
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        for item in items {
            draw(item)
        }
        if let draftItem {
            draw(draftItem)
        }
        if let selectedIndex, items.indices.contains(selectedIndex) {
            drawSelection(for: items[selectedIndex])
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        lastDragPoint = point
        draftItem = nil

        if let index = hitItem(at: point) {
            selectedIndex = index
            if event.clickCount == 2, case .text = items[index] {
                beginEditingText(at: index)
                return
            }
            dragSnapshot = snapshot()
            dragMode = isResizeHandleHit(point, item: items[index]) ? .resize(index: index) : .move(index: index)
            needsDisplay = true
            return
        }

        selectedIndex = nil
        dragMode = .create
        dragStart = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch dragMode {
        case .create:
            guard let dragStart else { return }
            draftItem = makeItem(from: dragStart, to: point)
        case .move(let index):
            guard items.indices.contains(index), let lastDragPoint else { return }
            items[index].move(by: CGPoint(x: point.x - lastDragPoint.x, y: point.y - lastDragPoint.y))
            self.lastDragPoint = point
        case .resize(let index):
            guard items.indices.contains(index) else { return }
            items[index].resize(to: point)
        case nil:
            return
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if case .create = dragMode, tool == .text {
            let input = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 180, height: 26))
            input.placeholderString = "Text"
            input.stringValue = ""
            input.target = self
            input.action = #selector(commitText(_:))
            input.bezelStyle = .roundedBezel
            addSubview(input)
            window?.makeFirstResponder(input)
        } else if case .create = dragMode, let dragStart, let item = makeItem(from: dragStart, to: point) {
            pushUndo()
            items.append(item)
            selectedIndex = items.indices.last
        }

        switch dragMode {
        case .move, .resize:
            commitDragSnapshotIfNeeded()
        case .create, nil:
            break
        }
        self.dragStart = nil
        lastDragPoint = nil
        dragSnapshot = nil
        dragMode = nil
        draftItem = nil
        needsDisplay = true
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        items = snapshot.items
        selectedIndex = snapshot.selectedIndex
        subviews.compactMap { $0 as? NSTextField }.forEach { $0.removeFromSuperview() }
        needsDisplay = true
    }

    func clear() {
        guard !items.isEmpty else { return }
        pushUndo()
        items.removeAll()
        selectedIndex = nil
        subviews.compactMap { $0 as? NSTextField }.forEach { $0.removeFromSuperview() }
        needsDisplay = true
    }

    func deleteSelectedItem() {
        guard let selectedIndex, items.indices.contains(selectedIndex) else { return }
        pushUndo()
        items.remove(at: selectedIndex)
        self.selectedIndex = nil
        needsDisplay = true
    }

    func zoom(by factor: CGFloat) {
        setZoom(zoomScale * factor)
    }

    func fitZoom(in size: NSSize) {
        let availableWidth = max(1, size.width - ScreenshotEditorLayout.canvasPadding * 2 - 24)
        let availableHeight = max(1, size.height - ScreenshotEditorLayout.toolbarAreaHeight - ScreenshotEditorLayout.canvasPadding * 2 - 24)
        setZoom(min(1, availableWidth / image.size.width, availableHeight / image.size.height))
    }

    func setZoom(_ scale: CGFloat) {
        zoomScale = min(3, max(0.2, scale))
        onZoomChange?(zoomScale)
    }

    func renderedImage() -> NSImage {
        let output = NSImage(size: bounds.size)
        output.lockFocus()
        image.draw(in: bounds)
        for item in items {
            draw(item)
        }
        output.unlockFocus()
        return output
    }

    private func makeItem(from start: NSPoint, to end: NSPoint) -> AnnotationItem? {
        let rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )

        switch tool {
        case .rectangle:
            return rect.width > 3 && rect.height > 3 ? .rectangle(rect, annotationColor) : nil
        case .arrow:
            return distance(start, end) > 6 ? .arrow(start, end, annotationColor) : nil
        case .text:
            return nil
        case .mosaic:
            return rect.width > 6 && rect.height > 6 ? .mosaic(rect, mosaicBlockSize) : nil
        }
    }

    @objc private func commitText(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            pushUndo()
            if let editingTextIndex, items.indices.contains(editingTextIndex) {
                items[editingTextIndex].updateText(text)
                selectedIndex = editingTextIndex
            } else {
                items.append(.text(text, sender.frame.origin, annotationColor, annotationTextSize))
                selectedIndex = items.indices.last
            }
        }
        editingTextIndex = nil
        sender.removeFromSuperview()
        needsDisplay = true
    }

    private func applyColorToSelectedItem() {
        guard let selectedIndex, items.indices.contains(selectedIndex) else { return }
        pushUndo()
        items[selectedIndex].recolor(annotationColor)
        needsDisplay = true
    }

    private func applyTextSizeToSelectedItem() {
        guard let selectedIndex, items.indices.contains(selectedIndex),
              case .text = items[selectedIndex]
        else { return }
        pushUndo()
        items[selectedIndex].updateFontSize(annotationTextSize)
        needsDisplay = true
    }

    private func pushUndo() {
        undoStack.append(snapshot())
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    private func snapshot() -> CanvasSnapshot {
        CanvasSnapshot(items: items, selectedIndex: selectedIndex)
    }

    private func commitDragSnapshotIfNeeded() {
        guard let dragSnapshot else { return }
        undoStack.append(dragSnapshot)
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    private func cancelCurrentInteraction() {
        draftItem = nil
        dragStart = nil
        dragMode = nil
        selectedIndex = nil
        subviews.compactMap { $0 as? NSTextField }.forEach { $0.removeFromSuperview() }
        needsDisplay = true
    }

    private func beginEditingText(at index: Int) {
        guard items.indices.contains(index),
              case .text(let text, let origin, _, let fontSize) = items[index]
        else { return }

        annotationTextSize = fontSize
        onTextSizeChange?(fontSize)
        let input = NSTextField(frame: NSRect(x: origin.x, y: origin.y, width: max(180, items[index].bounds.width + 16), height: 28))
        input.stringValue = text
        input.target = self
        input.action = #selector(commitText(_:))
        input.bezelStyle = .roundedBezel
        editingTextIndex = index
        addSubview(input)
        window?.makeFirstResponder(input)
    }

    private func copyRenderedImage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([renderedImage()])
    }

    private func saveRenderedImage() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "PixelCat-Screenshot.png"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK,
                  let url = panel.url,
                  let data = self?.renderedImage().pngData
            else { return }
            try? data.write(to: url)
        }
    }

    private func hitItem(at point: CGPoint) -> Int? {
        items.indices.reversed().first { index in
            items[index].bounds.insetBy(dx: -6, dy: -6).contains(point)
        }
    }

    private func isResizeHandleHit(_ point: CGPoint, item: AnnotationItem) -> Bool {
        handleRect(for: item).contains(point)
    }

    private func handleRect(for item: AnnotationItem) -> CGRect {
        let bounds = item.bounds
        return CGRect(x: bounds.maxX - 5, y: bounds.maxY - 5, width: 10, height: 10)
    }

    private func drawSelection(for item: AnnotationItem) {
        CatppuccinPalette.mauve.setStroke()
        let path = NSBezierPath(rect: item.bounds)
        path.lineWidth = 1.5
        path.setLineDash([4, 3], count: 2, phase: 0)
        path.stroke()

        CatppuccinPalette.mauve.setFill()
        handleRect(for: item).fill()
    }

    private func draw(_ item: AnnotationItem) {
        switch item {
        case .rectangle(let rect, let color):
            color.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 4
            path.stroke()
        case .arrow(let start, let end, let color):
            color.setStroke()
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = 4
            path.stroke()
            drawArrowHead(from: start, to: end, color: color)
        case .text(let text, let origin, let color, let fontSize):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: color
            ]
            text.draw(at: origin, withAttributes: attributes)
        case .mosaic(let rect, let strength):
            drawMosaic(in: rect, strength: strength)
        }
    }

    private func drawArrowHead(from start: CGPoint, to end: CGPoint, color: NSColor) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 17
        let spread: CGFloat = .pi / 7
        let points = [
            CGPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread)),
            CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread))
        ]

        color.setFill()
        let path = NSBezierPath()
        path.move(to: end)
        path.line(to: points[0])
        path.line(to: points[1])
        path.close()
        path.fill()
    }

    private func drawMosaic(in rect: CGRect, strength: CGFloat) {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let crop = source.cropping(to: cgRect(from: rect, in: source))
        else {
            CatppuccinPalette.surface0.withAlphaComponent(0.58).setFill()
            rect.fill()
            return
        }

        let blockSize = max(4, strength)
        let pixelatedSize = NSSize(
            width: max(1, floor(rect.width / blockSize)),
            height: max(1, floor(rect.height / blockSize))
        )
        let cropImage = NSImage(cgImage: crop, size: rect.size)
        let pixelatedImage = NSImage(size: pixelatedSize)

        pixelatedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        cropImage.draw(in: NSRect(origin: .zero, size: pixelatedSize))
        pixelatedImage.unlockFocus()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.imageInterpolation = .none
        pixelatedImage.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func cgRect(from rect: CGRect, in source: CGImage) -> CGRect {
        let scaleX = CGFloat(source.width) / image.size.width
        let scaleY = CGFloat(source.height) / image.size.height
        let scaled = CGRect(
            x: rect.minX * scaleX,
            y: CGFloat(source.height) - rect.maxY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral
        return scaled.intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

private extension NSColor {
    func isVisuallyEqual(to other: NSColor) -> Bool {
        guard let lhs = usingColorSpace(.deviceRGB),
              let rhs = other.usingColorSpace(.deviceRGB)
        else { return false }

        return abs(lhs.redComponent - rhs.redComponent) < 0.01
            && abs(lhs.greenComponent - rhs.greenComponent) < 0.01
            && abs(lhs.blueComponent - rhs.blueComponent) < 0.01
            && abs(lhs.alphaComponent - rhs.alphaComponent) < 0.01
    }
}

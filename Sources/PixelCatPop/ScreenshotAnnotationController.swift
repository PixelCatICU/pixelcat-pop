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
        let windowSize = NSSize(
            width: min(980, max(640, image.size.width + 2)),
            height: min(760, max(420, image.size.height + 74))
        )
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
        window.minSize = NSSize(width: 520, height: 360)
        window.setContentSize(windowSize)
        window.level = .floating
        window.center()
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
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.16, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()

        NSColor(calibratedRed: 0.22, green: 0.60, blue: 1.0, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 32, y: 184, width: 456, height: 72), xRadius: 8, yRadius: 8).fill()

        NSColor(calibratedRed: 0.12, green: 0.84, blue: 0.46, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 32, y: 52, width: 210, height: 94), xRadius: 8, yRadius: 8).fill()

        NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 278, y: 52, width: 210, height: 94), xRadius: 8, yRadius: 8).fill()

        let title = "PixelCat Pop Screenshot Editor"
        title.draw(
            at: NSPoint(x: 52, y: 207),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 28),
                .foregroundColor: NSColor.white
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
        NSColor.black.withAlphaComponent(0.34).setFill()
        bounds.fill()

        guard currentRect.width > 1, currentRect.height > 1 else { return }
        NSColor.clear.setFill()
        currentRect.fill(using: .clear)
        NSColor.systemBlue.setStroke()
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
        case .mosaic: "checkerboard.rectangle"
        }
    }
}

private enum AnnotationItem {
    case rectangle(CGRect, NSColor)
    case arrow(CGPoint, CGPoint, NSColor)
    case text(String, CGPoint, NSColor)
    case mosaic(CGRect)

    var bounds: CGRect {
        switch self {
        case .rectangle(let rect, _), .mosaic(let rect):
            return rect
        case .arrow(let start, let end, _):
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(start.x - end.x),
                height: abs(start.y - end.y)
            ).insetBy(dx: -12, dy: -12)
        case .text(let text, let origin, _):
            let size = (text as NSString).size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: 24)])
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
        case .text(let text, let origin, let color):
            self = .text(text, CGPoint(x: origin.x + delta.x, y: origin.y + delta.y), color)
        case .mosaic(let rect):
            self = .mosaic(rect.offsetBy(dx: delta.x, dy: delta.y))
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
        case .mosaic(let rect):
            self = .mosaic(resizedRect(from: rect, to: point))
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

private final class ScreenshotEditorViewController: NSViewController {
    private let image: NSImage
    private let canvasView: ScreenshotAnnotationCanvasView

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
        root.frame = NSRect(x: 0, y: 0, width: max(640, image.size.width + 2), height: max(420, image.size.height + 74))

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        for tool in AnnotationTool.allCases {
            let button = NSButton(image: NSImage(systemSymbolName: tool.systemImageName, accessibilityDescription: tool.title) ?? NSImage(), target: self, action: #selector(selectTool(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
            button.bezelStyle = .texturedRounded
            button.toolTip = tool.title
            toolbar.addArrangedSubview(button)
        }

        toolbar.addArrangedSubview(separator())
        toolbar.addArrangedSubview(toolbarButton("arrow.uturn.backward", "Undo", #selector(undo)))
        toolbar.addArrangedSubview(toolbarButton("trash", "Clear", #selector(clear)))
        toolbar.addArrangedSubview(NSView())
        toolbar.addArrangedSubview(toolbarButton("doc.on.doc", "Copy", #selector(copyImage)))
        toolbar.addArrangedSubview(toolbarButton("square.and.arrow.down", "Save", #selector(saveImage)))

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        canvasView.frame = NSRect(origin: .zero, size: image.size)
        canvasView.autoresizingMask = []
        scrollView.documentView = canvasView

        root.addSubview(toolbar)
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            toolbar.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            toolbar.heightAnchor.constraint(equalToConstant: 34),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        view = root
    }

    private func separator() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func toolbarButton(_ symbol: String, _ help: String, _ action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help) ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = help
        return button
    }

    @objc private func selectTool(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue, let tool = AnnotationTool(rawValue: rawValue) else { return }
        canvasView.tool = tool
    }

    @objc private func undo() {
        canvasView.undo()
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

private final class ScreenshotAnnotationCanvasView: NSView {
    var tool: AnnotationTool = .rectangle

    private let image: NSImage
    private var items: [AnnotationItem] = []
    private var draftItem: AnnotationItem?
    private var dragStart: NSPoint?
    private var lastDragPoint: NSPoint?
    private var selectedIndex: Int?
    private var dragMode: CanvasDragMode?

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
            items.append(item)
            selectedIndex = items.indices.last
        }

        self.dragStart = nil
        lastDragPoint = nil
        dragMode = nil
        draftItem = nil
        needsDisplay = true
    }

    func undo() {
        if !items.isEmpty {
            items.removeLast()
            selectedIndex = nil
            needsDisplay = true
        }
    }

    func clear() {
        items.removeAll()
        selectedIndex = nil
        subviews.compactMap { $0 as? NSTextField }.forEach { $0.removeFromSuperview() }
        needsDisplay = true
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
            return rect.width > 3 && rect.height > 3 ? .rectangle(rect, .systemRed) : nil
        case .arrow:
            return distance(start, end) > 6 ? .arrow(start, end, .systemRed) : nil
        case .text:
            return nil
        case .mosaic:
            return rect.width > 6 && rect.height > 6 ? .mosaic(rect) : nil
        }
    }

    @objc private func commitText(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            items.append(.text(text, sender.frame.origin, .systemRed))
            selectedIndex = items.indices.last
        }
        sender.removeFromSuperview()
        needsDisplay = true
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
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: item.bounds)
        path.lineWidth = 1.5
        path.setLineDash([4, 3], count: 2, phase: 0)
        path.stroke()

        NSColor.systemBlue.setFill()
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
        case .text(let text, let origin, let color):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 24),
                .foregroundColor: color
            ]
            text.draw(at: origin, withAttributes: attributes)
        case .mosaic(let rect):
            drawMosaic(in: rect)
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

    private func drawMosaic(in rect: CGRect) {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let crop = source.cropping(to: cgRect(from: rect, imageHeight: CGFloat(source.height)))
        else {
            NSColor.black.withAlphaComponent(0.35).setFill()
            rect.fill()
            return
        }

        let smallSize = NSSize(width: max(1, rect.width / 12), height: max(1, rect.height / 12))
        let mosaic = NSImage(size: rect.size)
        mosaic.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: crop, size: rect.size).draw(in: NSRect(origin: .zero, size: smallSize))
        NSImage(cgImage: crop, size: smallSize).draw(in: NSRect(origin: .zero, size: rect.size))
        mosaic.unlockFocus()
        mosaic.draw(in: rect)
    }

    private func cgRect(from rect: CGRect, imageHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: imageHeight - rect.maxY, width: rect.width, height: rect.height)
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

import AppKit

final class GlassEffectView: NSVisualEffectView {
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        super.init(frame: .zero)
        self.blendingMode = blendingMode
        state = .active
        self.material = material
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        blendingMode = .behindWindow
        state = .active
        material = .hudWindow
        wantsLayer = true
    }
}

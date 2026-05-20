import AppKit
import SwiftUI

enum BrandAssets {
    static let logoName = "pixel-cat"
    static let menuBarLogoName = "pixel-cat-menubar"

    static var logoImage: NSImage? {
        guard let url = Bundle.module.url(forResource: logoName, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = false
        return image
    }

    static func statusBarImage(tintColor: NSColor? = nil) -> NSImage {
        let image: NSImage
        if let url = Bundle.module.url(forResource: menuBarLogoName, withExtension: "svg"),
           let loadedImage = NSImage(contentsOf: url) {
            image = loadedImage
        } else {
            image = NSImage(
                systemSymbolName: "translate",
                accessibilityDescription: "PixelCat Pop"
            ) ?? NSImage()
        }
        image.size = NSSize(width: 18, height: 18)

        guard let tintColor else {
            image.isTemplate = true
            return image
        }

        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)
        tintColor.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        tintedImage.unlockFocus()
        tintedImage.isTemplate = false
        return tintedImage
    }
}

struct BrandLogoView: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let logo = BrandAssets.logoImage {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.none)
            } else {
                Image(systemName: "text.bubble")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("PixelCat Pop")
    }
}

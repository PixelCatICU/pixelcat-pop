import AppKit

enum CatppuccinPalette {
    static let base = NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
    static let mantle = NSColor(red: 0.09, green: 0.09, blue: 0.14, alpha: 1.0)
    static let crust = NSColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1.0)
    static let surface0 = NSColor(red: 0.19, green: 0.19, blue: 0.29, alpha: 1.0)
    static let surface1 = NSColor(red: 0.27, green: 0.28, blue: 0.40, alpha: 1.0)
    static let overlay0 = NSColor(red: 0.42, green: 0.44, blue: 0.53, alpha: 1.0)
    static let subtext1 = NSColor(red: 0.73, green: 0.76, blue: 0.87, alpha: 1.0)
    static let text = NSColor(red: 0.80, green: 0.84, blue: 0.96, alpha: 1.0)
    static let red = NSColor(red: 0.95, green: 0.55, blue: 0.66, alpha: 1.0)
    static let peach = NSColor(red: 0.98, green: 0.70, blue: 0.53, alpha: 1.0)
    static let yellow = NSColor(red: 0.98, green: 0.89, blue: 0.69, alpha: 1.0)
    static let green = NSColor(red: 0.65, green: 0.89, blue: 0.63, alpha: 1.0)
    static let teal = NSColor(red: 0.58, green: 0.89, blue: 0.84, alpha: 1.0)
    static let blue = NSColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1.0)
    static let mauve = NSColor(red: 0.80, green: 0.65, blue: 0.97, alpha: 1.0)

    static func loadColor(for ratio: Double) -> NSColor {
        switch ratio {
        case ..<0.50:
            green
        case ..<0.75:
            yellow
        case ..<0.90:
            peach
        default:
            red
        }
    }
}

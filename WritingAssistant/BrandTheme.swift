import AppKit
import SwiftUI

/// "Ink & Craft" brand palette — warm, editorial identity.
/// All colors adapt between light and dark appearance.
enum Brand {

    // MARK: - SwiftUI Colors

    static var accentColor: Color { Color(nsColor: accent) }
    static var accentHoverColor: Color { Color(nsColor: accentHover) }
    static var successColor: Color { Color(nsColor: success) }
    static var errorColor: Color { Color(nsColor: error) }
    static var surfaceColor: Color { Color(nsColor: surface) }
    static var subtleColor: Color { Color(nsColor: subtle) }
    static var midGrayColor: Color { Color(nsColor: midGray) }

    // MARK: - Typography

    enum Typography {
        static let serifTitle = Font.system(size: 28, weight: .bold, design: .serif)
        static let serifHeading = Font.system(size: 22, weight: .bold, design: .serif)
        static let sectionHeader = Font.system(size: 10, weight: .semibold, design: .default).smallCaps()
        static let body = Font.system(size: 13)
        static let bodyMedium = Font.system(size: 13, weight: .medium)
        static let caption = Font.system(size: 12)
        static let captionSecondary = Font.system(size: 11)
        static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
        static let badge = Font.system(size: 13, weight: .semibold)
        static let stats = Font.system(size: 10, weight: .regular, design: .monospaced)
        static let pill = Font.system(size: 10, weight: .medium)
    }

    // MARK: - Layout

    enum Layout {
        static let cornerRadius: CGFloat = 10
        static let smallCornerRadius: CGFloat = 6
        static let pillCornerRadius: CGFloat = 4
        static let margin: CGFloat = 20
        static let padding: CGFloat = 12
        static let smallPadding: CGFloat = 8
        static let rowHeight: CGFloat = 32
        static let sectionHeaderHeight: CGFloat = 24
    }
    // MARK: - Accent (warm teal)

    static let accent = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.455, green: 0.678, blue: 0.659, alpha: 1.0) // #74ADA8 soft teal
        }
        return NSColor(srgbRed: 0.318, green: 0.525, blue: 0.506, alpha: 1.0) // #518681 muted teal
    }

    static let accentHover = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.380, green: 0.600, blue: 0.580, alpha: 1.0) // #619994
        }
        return NSColor(srgbRed: 0.255, green: 0.435, blue: 0.416, alpha: 1.0) // #416F6A
    }

    // MARK: - Semantic

    static let success = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.455, green: 0.678, blue: 0.659, alpha: 1.0) // #74ADA8
        }
        return NSColor(srgbRed: 0.318, green: 0.525, blue: 0.506, alpha: 1.0) // #518681
    }

    static let error = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.878, green: 0.400, blue: 0.400, alpha: 1.0) // #E06666 brighter warm red
        }
        return NSColor(srgbRed: 0.773, green: 0.294, blue: 0.294, alpha: 1.0) // #C54B4B
    }

    // MARK: - Surfaces

    static let surface = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.173, green: 0.173, blue: 0.180, alpha: 1.0) // #2C2C2E rich charcoal
        }
        return NSColor(srgbRed: 0.980, green: 0.976, blue: 0.961, alpha: 1.0) // #FAF9F5 warm off-white
    }

    static let subtle = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.227, green: 0.227, blue: 0.235, alpha: 1.0) // #3A3A3C dark warm gray
        }
        return NSColor(srgbRed: 0.910, green: 0.902, blue: 0.863, alpha: 1.0) // #E8E6DC parchment gray
    }

    static let midGray = NSColor(name: nil) { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: 0.557, green: 0.549, blue: 0.522, alpha: 1.0) // #8E8C85 lighter warm gray
        }
        return NSColor(srgbRed: 0.690, green: 0.682, blue: 0.647, alpha: 1.0) // #B0AEA5
    }
}

// MARK: - Appearance Helper

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

// MARK: - Color Blending

extension NSColor {
    /// Blend from self (at fraction 0) to labelColor (at fraction 1).
    /// Used for the streaming text "ink settling" effect.
    func blendedWithLabelColor(fraction t: CGFloat) -> NSColor {
        guard let src = usingColorSpace(.sRGB),
              let dst = NSColor.labelColor.usingColorSpace(.sRGB)
        else { return NSColor.labelColor }

        let r = src.redComponent + (dst.redComponent - src.redComponent) * t
        let g = src.greenComponent + (dst.greenComponent - src.greenComponent) * t
        let b = src.blueComponent + (dst.blueComponent - src.blueComponent) * t
        // Alpha: start at 0.5, end at 1.0
        let a = 0.5 + 0.5 * t

        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

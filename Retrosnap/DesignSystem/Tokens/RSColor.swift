import SwiftUI

extension Color {
    /// An sRGB colour from a `0xRRGGBB` literal, as written in the design files.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Colour tokens from the design system board.
nonisolated enum RSColor {
    // Core
    static let ink = Color(hex: 0x0E0D0C)
    static let surface = Color(hex: 0x1B1916)
    static let raised = Color(hex: 0x26231F)
    static let paper = Color(hex: 0xF4EEE6)
    static let secondaryText = Color(hex: 0xA79F94)
    static let amber = Color(hex: 0xF2A33A)
    static let record = Color(hex: 0xE5483B)
    static let destructive = Color(hex: 0xFF8A7A)

    // Text on fills
    static let onAmber = Color(hex: 0x1E1206)
    static let onPaper = Color(hex: 0x1A1714)
    static let onAccent = Color(hex: 0x17120C)
    /// Quieter than paper: card descriptions and unselected camera names.
    static let tertiaryText = Color(hex: 0xCFC6BA)

    // Controls
    static let toggleOff = Color(hex: 0x3A3631)
    static let hairline = Color(hex: 0xF4EEE6, opacity: 0.07)

    // Prints
    static let printFrame = Color(hex: 0xF7F3EC)
    static let printPaper = Color(hex: 0xFBF8F2)
    static let photoBacking = Color(hex: 0x1A1714)
    static let stamp = Color(hex: 0xFF8A2A)

    /// "Blurred ink": the tint laid over a backdrop blur for controls floating on the viewfinder.
    static func glass(_ opacity: Double = 0.45) -> Color {
        Color(hex: 0x141210, opacity: opacity)
    }

    /// Ink at partial opacity, for sheets and bars over content.
    static func ink(_ opacity: Double) -> Color {
        Color(hex: 0x0E0D0C, opacity: opacity)
    }
}

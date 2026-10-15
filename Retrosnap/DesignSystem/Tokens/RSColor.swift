import CoreImage
import SwiftUI

/// The red, green and blue of a `0xRRGGBB` literal, each from 0 to 1.
nonisolated func rgbComponents(hex: UInt32) -> (red: Double, green: Double, blue: Double) {
    (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
}

extension Color {
    /// An sRGB colour from a `0xRRGGBB` literal, as written in the design files.
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        let rgb = rgbComponents(hex: hex)
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: opacity)
    }
}

/// Colour tokens from the design system board.
nonisolated enum RSColor {
    private static let inkHex: UInt32 = 0x0E0D0C
    private static let raisedHex: UInt32 = 0x26231F
    private static let paperHex: UInt32 = 0xF4EEE6

    // Core
    static let ink = Color(hex: inkHex)
    static let surface = Color(hex: 0x1B1916)
    static let raised = Color(hex: raisedHex)
    static let paper = Color(hex: paperHex)
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
    static let hairline = Color(hex: paperHex, opacity: 0.07)

    // Prints
    static let printFrameHex: UInt32 = 0xF7F3EC
    static let printFrame = Color(hex: printFrameHex)
    static let printPaper = Color(hex: 0xFBF8F2)
    static let photoBacking = Color(hex: 0x1A1714)
    static let stamp = Color(hex: 0xFF8A2A)

    /// "Blurred ink": the tint laid over a backdrop blur for controls floating on the viewfinder.
    static func glass(_ opacity: Double = 0.45) -> Color {
        Color(hex: 0x141210, opacity: opacity)
    }

    /// Ink at partial opacity, for sheets and bars over content.
    static func ink(_ opacity: Double) -> Color {
        Color(hex: inkHex, opacity: opacity)
    }

    /// The raised fill at partial opacity, for pills over content.
    static func raised(_ opacity: Double) -> Color {
        Color(hex: raisedHex, opacity: opacity)
    }
}

extension CIColor {
    /// An sRGB colour from a `0xRRGGBB` literal, as written in the design files.
    nonisolated convenience init(hex: UInt32) {
        let rgb = rgbComponents(hex: hex)
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

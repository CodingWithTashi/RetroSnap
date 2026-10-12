import SwiftUI
import UIKit

/// A text style from the design: SF Pro for UI, SF Pro Rounded for names and buttons.
/// Sizes equal the matching Dynamic Type text style at the default setting and scale with it.
nonisolated struct RSTextStyle: Sendable {
    var size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    /// CSS `line-height` as a multiple of the font size; nil keeps the font's natural line height.
    var lineHeight: CGFloat?
    /// CSS `letter-spacing` in em.
    var tracking: CGFloat = 0
    var isMultiline = false
    var monospacedDigits = false

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> RSTextStyle {
        RSTextStyle(size: size, weight: weight, design: .rounded)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> RSTextStyle {
        RSTextStyle(size: size, weight: weight)
    }

    func lineHeight(_ multiple: CGFloat) -> RSTextStyle {
        var copy = self
        copy.lineHeight = multiple
        return copy
    }

    func tracking(_ em: CGFloat) -> RSTextStyle {
        var copy = self
        copy.tracking = em
        return copy
    }

    /// Wrapping text: the line height is applied between lines instead of as a fixed box.
    func multiline() -> RSTextStyle {
        var copy = self
        copy.isMultiline = true
        return copy
    }

    func tabularDigits() -> RSTextStyle {
        var copy = self
        copy.monospacedDigits = true
        return copy
    }

    // Named styles from the design system board.
    static let wordmark = rounded(34, .heavy).lineHeight(1).tracking(-0.02)
    static let title = rounded(28, .heavy)
    static let heading = rounded(22, .heavy)
    static let label = rounded(17, .bold)
    static let labelSmall = rounded(15, .bold)
    static let chip = rounded(13, .bold)
    static let body = text(17)
    static let bodySmall = text(15)
    static let caption = text(13)

    var textStyle: Font.TextStyle {
        switch size {
        case 34...: .largeTitle
        case 28..<34: .title
        case 22..<28: .title2
        case 20..<22: .title3
        case 17..<20: .body
        case 16..<17: .callout
        case 15..<16: .subheadline
        case 13..<15: .footnote
        case 12..<13: .caption
        default: .caption2
        }
    }
}

private struct RSTextModifier: ViewModifier {
    let style: RSTextStyle
    @ScaledMetric private var size: CGFloat

    nonisolated init(style: RSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.textStyle)
    }

    private var font: Font {
        let base = Font.system(size: size, weight: style.weight, design: style.design)
        return style.monospacedDigits ? base.monospacedDigit() : base
    }

    func body(content: Content) -> some View {
        let styled = content
            .font(font)
            .kerning(style.tracking * size)
        if let multiple = style.lineHeight {
            if style.isMultiline {
                // CSS spreads (line box - font line height) half above and half below every line.
                let extra = size * multiple - UIFont.systemFont(ofSize: size).lineHeight
                styled
                    .lineSpacing(max(0, extra))
                    .padding(.vertical, extra / 2)
            } else {
                styled.frame(height: size * multiple)
            }
        } else {
            styled
        }
    }
}

extension View {
    nonisolated func rsText(_ style: RSTextStyle) -> some View {
        modifier(RSTextModifier(style: style))
    }
}

enum RSFont {
    /// VT323, the date-stamp motif. Never used for UI text.
    static func stamp(_ size: CGFloat) -> Font {
        .custom("VT323-Regular", fixedSize: size)
    }
}

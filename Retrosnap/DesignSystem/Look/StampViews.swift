import SwiftUI

/// The orange date in the corner: VT323 with a soft glow.
struct DateStampView: View {
    let text: String
    let size: CGFloat

    private var label: some View {
        Text(text)
            .font(RSFont.stamp(size))
            .kerning(0.06 * size)
            .fixedSize()
    }

    var body: some View {
        // text-shadow: 0 0 4px rgba(255,110,20,.85), 0 0 1px #ffb070 — drawn as blurred copies under the text.
        ZStack {
            label.foregroundStyle(Color(hex: 0xFFB070)).blur(radius: 0.5)
            label.foregroundStyle(Color(hex: 0xFF6E14, opacity: 0.85)).blur(radius: 2)
            label.foregroundStyle(RSColor.stamp)
        }
        .opacity(0.92)
        .accessibilityHidden(true)
    }
}

/// White tape text with the red/cyan misregistration: text-shadow 2px 0 red, -2px 0 cyan.
struct TapeText<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content.foregroundStyle(Color(hex: 0x00DCD2, opacity: 0.7)).offset(x: -2)
            content.foregroundStyle(Color(hex: 0xFF2846, opacity: 0.7)).offset(x: 2)
            content.foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

/// "PLAY ▶" — the triangle is drawn so it never falls back to an emoji glyph.
struct TapePlayLabel: View {
    let size: CGFloat

    var body: some View {
        TapeText {
            HStack(alignment: .firstTextBaseline, spacing: size * 0.37) {
                Text("PLAY").font(RSFont.stamp(size)).fixedSize()
                PlayTriangle()
                    .frame(width: size * 0.57, height: size * 0.586)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - size * 0.018 }
            }
        }
        // In the design the ▶ comes from a fallback font whose taller metrics push the line down.
        .padding(.top, size * 0.16)
    }
}

private nonisolated struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

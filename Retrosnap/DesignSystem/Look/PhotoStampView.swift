import SwiftUI

/// The text burned into a photo, laid out in the photo's box: the orange date bottom right, or the tape overlay.
/// Sizes follow the CSS: max(9px, N cqw) of the photo box width; insets are fractions of the box.
struct PhotoStampView: View {
    let text: PhotoStampText
    let kind: LookStamp
    let size: CGSize
    /// Insets as a fraction of the photo's height.
    var bottomInset: CGFloat = 0.05
    var topInset: CGFloat = 0.05
    /// Where the film's frame lies in the box, for a stamp that is burned into the frame rather than the box.
    var filmFrame: CGRect?

    private var frameInBox: CGRect { filmFrame ?? CGRect(origin: .zero, size: size) }

    var body: some View {
        switch kind {
        case .none:
            EmptyView()
        case .dateMatrix:
            DateBackStampView(text: text.dateBack, frame: frameInBox)
                .frame(width: size.width, height: size.height)
        case .dateSegments:
            FilmDateStampView(text: text.dateBackPlain, style: .segments, frame: frameInBox)
                .frame(width: size.width, height: size.height)
        case .dateDots:
            FilmDateStampView(text: text.dateBackPlain, style: .dots, frame: frameInBox)
                .frame(width: size.width, height: size.height)
        case .date:
            DateStampView(text: text.date, size: max(9, size.width * 0.075))
                .padding(.trailing, size.width * 0.06)
                .padding(.bottom, size.height * bottomInset)
                .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
        case .vhs:
            let small = max(9, size.width * 0.065)
            ZStack {
                TapePlayLabel(size: max(9, size.width * 0.07))
                    .padding(.leading, size.width * 0.06)
                    .padding(.top, size.height * topInset)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                TapeText {
                    HStack {
                        Text(text.tapeDate)
                        Spacer(minLength: 0)
                        Text(text.tapeTime)
                    }
                    .font(RSFont.stamp(small))
                }
                .padding(.horizontal, size.width * 0.06)
                .padding(.bottom, size.height * bottomInset)
                .frame(width: size.width, height: size.height, alignment: .bottom)
            }
        }
    }
}

// MARK: -

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

// MARK: -

/// White tape text with the red/cyan misregistration: text-shadow 2px 0 red, -2px 0 cyan.
private struct TapeText<Content: View>: View {
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

// MARK: -

/// "PLAY ▶" — the triangle is drawn so it never falls back to an emoji glyph.
private struct TapePlayLabel: View {
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

// MARK: -

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

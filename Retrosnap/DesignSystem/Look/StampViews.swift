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

    var body: some View {
        switch kind {
        case .none:
            EmptyView()
        case .dateMatrix:
            DateBackStampView(text: text.dateBack, frame: filmFrame ?? CGRect(origin: .zero, size: size))
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


/// A compact's date back: the date in a yellow 5×7 dot matrix, burned into the lower right of the film's
/// landscape frame. The film's frame turns with the camera, so on a portrait picture the stamp runs down the
/// left edge, its glyphs turned a quarter clockwise. Measured from the reference app: the dots 3.2% of the
/// frame's short side tall, 9.3% of the short side up from the bottom and 16.7% of the long side in from the
/// right, with a soft glow where the lamp bled into the film.
struct DateBackStampView: View {
    let text: String
    /// The film's frame, in the box this view fills.
    let frame: CGRect

    static let inkHex: UInt32 = 0xE8D64C
    static let glowHex: UInt32 = 0xE0A020

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let isLandscape = frame.width >= frame.height
            let long = max(frame.width, frame.height)
            let short = min(frame.width, frame.height)
            let cap = short * 0.032
            let cell = cap / 7
            let glyphs = DotMatrixFont.glyphs(for: text)
            let advance = glyphs.map { CGFloat($0.width) + 0.6 }.reduce(0, +) * cell
            // The lower-right corner of the frame, in the frame's own landscape coordinates.
            let right = long - long * 0.167
            let bottom = short - short * 0.093
            var context = context
            context.translateBy(x: frame.minX, y: frame.minY)
            if !isLandscape {
                // The landscape frame turned a quarter clockwise: its bottom-right corner is now bottom-left.
                context.translateBy(x: frame.width, y: 0)
                context.rotate(by: .degrees(90))
            }
            let origin = CGPoint(x: right - advance, y: bottom - cap)
            var glow = context
            glow.addFilter(.blur(radius: cell * 0.9))
            Self.draw(glyphs, at: origin, cell: cell, color: Color(hex: Self.glowHex, opacity: 0.75), radius: cell * 0.62, in: &glow)
            Self.draw(glyphs, at: origin, cell: cell, color: Color(hex: Self.inkHex), radius: cell * 0.42, in: &context)
        }
        .accessibilityHidden(true)
    }

    private static func draw(_ glyphs: [DotMatrixFont.Glyph], at origin: CGPoint, cell: CGFloat, color: Color, radius: CGFloat, in context: inout GraphicsContext) {
        var x = origin.x
        for glyph in glyphs {
            for (row, line) in glyph.rows.enumerated() {
                for (column, dot) in line.enumerated() where dot == "#" {
                    let centre = CGPoint(x: x + (CGFloat(column) + 0.5) * cell, y: origin.y + (CGFloat(row) + 0.5) * cell)
                    context.fill(
                        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color)
                    )
                }
            }
            x += (CGFloat(glyph.width) + 0.6) * cell
        }
    }
}

/// The dot matrix a date back prints with: digits five dots wide, the year, month and day marks, a space.
nonisolated enum DotMatrixFont {
    struct Glyph {
        let width: Int
        let rows: [String]
    }

    static func glyphs(for text: String) -> [Glyph] {
        text.map { glyph(for: $0) }
    }

    static func glyph(for character: Character) -> Glyph {
        let rows: [String]
        switch character {
        case "0": rows = [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "]
        case "1": rows = ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "]
        case "2": rows = [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"]
        case "3": rows = ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "]
        case "4": rows = ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "]
        case "5": rows = ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "]
        case "6": rows = ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "]
        case "7": rows = ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "]
        case "8": rows = [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "]
        case "9": rows = [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "]
        case "'": rows = ["# #", "# #", " # ", "   ", "   ", "   ", "   "]
        case "年": rows = [" #   ", " ####", "# #  ", "#####", " # # ", "#####", "  #  "]
        case "月": rows = [" ####", " #  #", " ####", " #  #", " ####", " #  #", "#   #"]
        case "日": rows = ["#####", "#   #", "#   #", "#####", "#   #", "#   #", "#####"]
        case " ": rows = ["  ", "  ", "  ", "  ", "  ", "  ", "  "]
        default: rows = ["     ", "     ", "     ", "     ", "     ", "     ", "     "]
        }
        return Glyph(width: rows[0].count, rows: rows)
    }
}

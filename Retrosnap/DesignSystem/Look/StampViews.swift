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
        case .dateSegments:
            FilmDateStampView(text: text.dateBackPlain, style: .segments, frame: filmFrame ?? CGRect(origin: .zero, size: size))
                .frame(width: size.width, height: size.height)
        case .dateDots:
            FilmDateStampView(text: text.dateBackPlain, style: .dots, frame: filmFrame ?? CGRect(origin: .zero, size: size))
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


/// How a 1990s date back prints: the glyphs, their size and place in the film's landscape frame, the lamp's
/// colour and glow, all measured from the reference app's exports (`tools/stamp.py`). Sizes are fractions of
/// the frame's short side; the text ends at `rightMarginLandscape` or `rightMarginPortrait` of the long side
/// from the frame's right edge (the reference app places it differently when the frame stands up).
nonisolated struct DateBackStyle: Hashable, Sendable {
    enum Glyphs: Hashable, Sendable {
        case segments
        case dots
    }

    let glyphs: Glyphs
    let capHeight: CGFloat
    let baseline: CGFloat
    let rightMarginLandscape: CGFloat
    let rightMarginPortrait: CGFloat
    /// A digit cell's width and the advance from one cell to the next, in cap heights.
    let cellWidth: CGFloat
    let advance: CGFloat
    let inkHex: UInt32

    /// Red seven-segment digits: D Classic and CT2F.
    static let segments = DateBackStyle(
        glyphs: .segments, capHeight: 0.0298, baseline: 0.1146, rightMarginLandscape: 0.1565, rightMarginPortrait: 0.2175,
        cellWidth: 0.57, advance: 0.76, inkHex: 0xFC4840
    )
    /// Red dots: Classic U.
    static let dots = DateBackStyle(
        glyphs: .dots, capHeight: 0.0283, baseline: 0.1153, rightMarginLandscape: 0.1553, rightMarginPortrait: 0.2167,
        cellWidth: 0.62, advance: 0.79, inkHex: 0xFF3937
    )
}

/// A 1990s compact's date back: "10  8 '26" screened into the lower right of the film's landscape frame by a
/// small lamp, so it glows a little into the picture around it. On a portrait picture the frame is turned a
/// quarter clockwise and the date runs down the left edge. Drawn in the style's glyphs: seven-segment digits
/// or a dot matrix; the apostrophe before the year is a short tick in the gap before its first digit. The view
/// is screened over the photo by its parent (`LookStamp.isScreened`), as the exporter screens the same drawing.
struct FilmDateStampView: View {
    let text: String
    let style: DateBackStyle
    /// The film's frame, in the box this view fills.
    let frame: CGRect

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let isLandscape = frame.width >= frame.height
            let long = max(frame.width, frame.height)
            let short = min(frame.width, frame.height)
            let cap = short * style.capHeight
            let cells = Array(text)
            // The text's width: one advance per cell, the last cell ending at its own width; the apostrophe
            // takes no cell of its own.
            let cellCount = cells.filter { $0 != "'" }.count
            let width = (CGFloat(max(cellCount - 1, 0)) * style.advance + style.cellWidth) * cap
            let right = long - long * (isLandscape ? style.rightMarginLandscape : style.rightMarginPortrait)
            let bottom = short - short * style.baseline
            var context = context
            context.translateBy(x: frame.minX, y: frame.minY)
            if !isLandscape {
                // The landscape frame turned a quarter clockwise: its bottom-right corner is now bottom-left.
                context.translateBy(x: frame.width, y: 0)
                context.rotate(by: .degrees(90))
            }
            let origin = CGPoint(x: right - width, y: bottom - cap)
            let ink = Self.ink(of: cells, at: origin, cap: cap, style: style)
            // The lamp's glow: the ink spread a little, then the ink itself.
            var glow = context
            glow.addFilter(.blur(radius: cap * 0.06))
            glow.fill(ink, with: .color(Color(hex: style.inkHex, opacity: 0.55)))
            context.fill(ink, with: .color(Color(hex: style.inkHex)))
        }
        .accessibilityHidden(true)
    }

    /// Every glyph of the text as one path, laid out from `origin` (the top-left of the first cell).
    static func ink(of cells: [Character], at origin: CGPoint, cap: CGFloat, style: DateBackStyle) -> Path {
        var path = Path()
        var x = origin.x
        for (index, character) in cells.enumerated() {
            let cell = CGRect(x: x, y: origin.y, width: style.cellWidth * cap, height: cap)
            if character == "'" {
                // The tick sits in the gap before the next cell, not in a cell of its own: the next cell starts
                // where this one would have.
                addTick(to: &path, before: x, capLine: origin.y, cap: cap)
                x -= style.advance * cap
            } else {
                switch style.glyphs {
                case .segments: addSegments(of: character, in: cell, to: &path)
                case .dots: addDots(of: character, in: cell, to: &path)
                }
            }
            if index < cells.count - 1 {
                x += style.advance * cap
            }
        }
        return path
    }

    /// The apostrophe: a short bar leaning right, its top on the cap line, ending just before `next`.
    private static func addTick(to path: inout Path, before next: CGFloat, capLine: CGFloat, cap: CGFloat) {
        let width = cap * 0.12
        let height = cap * 0.3
        let x = next - cap * 0.05 - width
        path.move(to: CGPoint(x: x + width * 0.4, y: capLine))
        path.addLine(to: CGPoint(x: x + width, y: capLine))
        path.addLine(to: CGPoint(x: x + width * 0.6, y: capLine + height))
        path.addLine(to: CGPoint(x: x, y: capLine + height))
        path.closeSubpath()
    }

    /// Seven segments in a cell: the bars with chamfered ends, 0.14 of the cap thick.
    private static func addSegments(of character: Character, in cell: CGRect, to path: inout Path) {
        let lit = segmentsLit(for: character)
        guard !lit.isEmpty else { return }
        let t = cell.height * 0.14
        let w = cell.width
        let h = cell.height
        let x = cell.minX
        let y = cell.minY
        let gap = t * 0.18
        func horizontal(_ cy: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x + t / 2 + gap, y: cy))
            p.addLine(to: CGPoint(x: x + t + gap, y: cy - t / 2))
            p.addLine(to: CGPoint(x: x + w - t - gap, y: cy - t / 2))
            p.addLine(to: CGPoint(x: x + w - t / 2 - gap, y: cy))
            p.addLine(to: CGPoint(x: x + w - t - gap, y: cy + t / 2))
            p.addLine(to: CGPoint(x: x + t + gap, y: cy + t / 2))
            p.closeSubpath()
            return p
        }
        func vertical(_ cx: CGFloat, from y0: CGFloat, to y1: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: cx, y: y0 + t / 2 + gap))
            p.addLine(to: CGPoint(x: cx + t / 2, y: y0 + t + gap))
            p.addLine(to: CGPoint(x: cx + t / 2, y: y1 - t - gap))
            p.addLine(to: CGPoint(x: cx, y: y1 - t / 2 - gap))
            p.addLine(to: CGPoint(x: cx - t / 2, y: y1 - t - gap))
            p.addLine(to: CGPoint(x: cx - t / 2, y: y0 + t + gap))
            p.closeSubpath()
            return p
        }
        // a (top), g (middle), d (bottom); f and b the upper left and right, e and c the lower.
        if lit.contains("a") { path.addPath(horizontal(y + t / 2)) }
        if lit.contains("g") { path.addPath(horizontal(y + h / 2)) }
        if lit.contains("d") { path.addPath(horizontal(y + h - t / 2)) }
        if lit.contains("f") { path.addPath(vertical(x + t / 2, from: y, to: y + h / 2)) }
        if lit.contains("b") { path.addPath(vertical(x + w - t / 2, from: y, to: y + h / 2)) }
        if lit.contains("e") { path.addPath(vertical(x + t / 2, from: y + h / 2, to: y + h)) }
        if lit.contains("c") { path.addPath(vertical(x + w - t / 2, from: y + h / 2, to: y + h)) }
    }

    static func segmentsLit(for character: Character) -> Set<Character> {
        switch character {
        case "0": ["a", "b", "c", "d", "e", "f"]
        case "1": ["b", "c"]
        case "2": ["a", "b", "g", "e", "d"]
        case "3": ["a", "b", "g", "c", "d"]
        case "4": ["f", "g", "b", "c"]
        case "5": ["a", "f", "g", "c", "d"]
        case "6": ["a", "f", "g", "e", "d", "c"]
        case "7": ["a", "b", "c"]
        case "8": ["a", "b", "c", "d", "e", "f", "g"]
        case "9": ["a", "b", "c", "d", "f", "g"]
        default: []
        }
    }

    /// A 5×7 dot matrix in a cell: round dots 0.6 of their pitch across, the pitch set so the five columns
    /// fill the cell's width and the seven rows its height.
    private static func addDots(of character: Character, in cell: CGRect, to path: inout Path) {
        let glyph = DotMatrixFont.glyph(for: character)
        guard glyph.width == 5 else { return }
        let pitchX = cell.width / 4.6
        let pitchY = cell.height / 6.6
        let radius = min(pitchX, pitchY) * 0.3
        for (row, line) in glyph.rows.enumerated() {
            for (column, dot) in line.enumerated() where dot == "#" {
                let centre = CGPoint(x: cell.minX + 0.3 * pitchX + CGFloat(column) * pitchX, y: cell.minY + 0.3 * pitchY + CGFloat(row) * pitchY)
                path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
            }
        }
    }
}

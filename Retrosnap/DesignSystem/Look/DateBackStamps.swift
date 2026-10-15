import SwiftUI

/// A compact's date back: the date in a yellow 5×7 dot matrix, burned into the lower right of the film's
/// landscape frame. The film's frame turns with the camera, so on a portrait picture the stamp runs down the
/// left edge, its glyphs turned a quarter clockwise. Measured from the reference app: the dots 3.2% of the
/// frame's short side tall, 9.3% of the short side up from the bottom and 16.7% of the long side in from the
/// right, with a soft glow where the lamp bled into the film.
struct DateBackStampView: View {
    let text: String
    /// The film's frame, in the box this view fills.
    let frame: CGRect

    private static let inkHex: UInt32 = 0xE8D64C
    private static let glowHex: UInt32 = 0xE0A020

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let space = FilmFrameSpace(frame: frame)
            let cap = space.short * 0.032
            let cell = cap / 7
            let glyphs = DotMatrixFont.glyphs(for: text)
            let advance = glyphs.map { CGFloat($0.width) + 0.6 }.reduce(0, +) * cell
            // The lower-right corner of the frame, in the frame's own landscape coordinates.
            let right = space.long - space.long * 0.167
            let bottom = space.short - space.short * 0.093
            var context = context
            space.enter(&context)
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
            for dot in glyph.dots {
                let centre = CGPoint(x: x + (CGFloat(dot.column) + 0.5) * cell, y: origin.y + (CGFloat(dot.row) + 0.5) * cell)
                context.fill(Path(ellipseIn: CGRect(centre: centre, radius: radius)), with: .color(color))
            }
            x += (CGFloat(glyph.width) + 0.6) * cell
        }
    }
}

// MARK: -

/// The dot matrix a date back prints with: digits five dots wide, the year, month and day marks, a space.
nonisolated enum DotMatrixFont {
    struct Glyph {
        let width: Int
        let rows: [String]

        /// The lit dots, row by row from the top, left to right.
        var dots: [(row: Int, column: Int)] {
            var dots: [(row: Int, column: Int)] = []
            for (row, line) in rows.enumerated() {
                for (column, dot) in line.enumerated() where dot == "#" { dots.append((row, column)) }
            }
            return dots
        }
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

// MARK: -

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

// MARK: -

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
            let space = FilmFrameSpace(frame: frame)
            let cap = space.short * style.capHeight
            let cells = Array(text)
            // The text's width: one advance per cell, the last cell ending at its own width; the apostrophe
            // takes no cell of its own.
            let cellCount = cells.filter { $0 != "'" }.count
            let width = (CGFloat(max(cellCount - 1, 0)) * style.advance + style.cellWidth) * cap
            let right = space.long - space.long * (space.isLandscape ? style.rightMarginLandscape : style.rightMarginPortrait)
            let bottom = space.short - space.short * style.baseline
            var context = context
            space.enter(&context)
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
    private static func ink(of cells: [Character], at origin: CGPoint, cap: CGFloat, style: DateBackStyle) -> Path {
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

    private static func segmentsLit(for character: Character) -> Set<Character> {
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
        for dot in glyph.dots {
            let centre = CGPoint(x: cell.minX + 0.3 * pitchX + CGFloat(dot.column) * pitchX, y: cell.minY + 0.3 * pitchY + CGFloat(dot.row) * pitchY)
            path.addEllipse(in: CGRect(centre: centre, radius: radius))
        }
    }
}

// MARK: -

/// The film's frame in its own landscape coordinates: its long and short sides, and the move that takes a context
/// there. On a portrait picture the landscape frame is turned a quarter clockwise, so its bottom-right corner is
/// the picture's bottom-left.
private struct FilmFrameSpace {
    let frame: CGRect
    var isLandscape: Bool { frame.width >= frame.height }
    var long: CGFloat { max(frame.width, frame.height) }
    var short: CGFloat { min(frame.width, frame.height) }

    func enter(_ context: inout GraphicsContext) {
        context.translateBy(x: frame.minX, y: frame.minY)
        if !isLandscape {
            context.translateBy(x: frame.width, y: 0)
            context.rotate(by: .degrees(90))
        }
    }
}

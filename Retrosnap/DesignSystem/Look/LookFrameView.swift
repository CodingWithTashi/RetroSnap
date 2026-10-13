import SwiftUI

/// Everything a frame draws around its picture: the film with its perforations and edge print, the mount with
/// its card and window, or the rebate with its frame numbers. The window is left clear, so this is laid over
/// the picture. The screen draws it as a view and the exporter rasterises the same view at the file's scale,
/// so the two cannot drift apart. The strip and the 6×7 rebate are drawn lying down and turned a quarter
/// anticlockwise for a portrait canvas, the way the reference app turns them.
struct LookFrameView: View {
    let frame: LookFrame
    let size: CGSize
    /// The photo's own shape: which way the slide mount's window turns.
    var photoAspect: CGFloat = 3.0 / 4
    /// Which of the square print's cards this photo gets.
    var design: SquarePrintDesign = .lightBlue

    var body: some View {
        switch frame {
        case .fullFrame:
            // Nothing at all: the picture is the whole canvas.
            EmptyView()
        case .filmStrip, .slideMount, .mediumFormat, .square, .instantPrint, .squarePrint:
            Canvas(rendersAsynchronously: false) { context, _ in
                var context = context
                switch frame {
                case .filmStrip:
                    turnedForPortrait(&context) { context, canvas in
                        FilmStripArt(geometry: FilmStripGeometry(canvas: canvas)).draw(in: &context)
                    }
                case .mediumFormat:
                    turnedForPortrait(&context) { context, canvas in
                        SevenRebateArt(geometry: RebateGeometry.seven(in: canvas)).draw(in: &context)
                    }
                case .square:
                    SquareRebateArt(geometry: RebateGeometry.square(in: size)).draw(in: &context)
                case .slideMount:
                    SlideMountArt(geometry: SlideMountGeometry(canvas: size, photoAspect: photoAspect)).draw(in: &context)
                case .instantPrint:
                    MiniPrintArt(geometry: MiniPrintGeometry(canvas: size)).draw(in: &context)
                case .squarePrint:
                    SquarePrintArt(geometry: SquarePrintGeometry(canvas: size), design: design).draw(in: &context)
                case .fullFrame:
                    break
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Draws the landscape artwork; a portrait canvas gets it turned a quarter anticlockwise, so the landscape
    /// bottom edge becomes the right edge.
    private func turnedForPortrait(_ context: inout GraphicsContext, draw: (inout GraphicsContext, CGSize) -> Void) {
        if size.width >= size.height {
            draw(&context, size)
        } else {
            context.translateBy(x: 0, y: size.height)
            context.rotate(by: .degrees(-90))
            draw(&context, CGSize(width: size.height, height: size.width))
        }
    }
}

/// The edge print: a small condensed sans, as it is exposed into the film's edge.
private enum EdgePrint {
    static func text(_ string: String, size: CGFloat, hex: UInt32, weight: Font.Weight = .medium) -> Text {
        Text(string)
            .font(.system(size: size, weight: weight).width(.condensed))
            .foregroundStyle(Color(hex: hex))
    }

    /// Draws text with its centre at `point`, turned by `angle`.
    static func draw(
        _ string: String, size: CGFloat, hex: UInt32, at point: CGPoint, anchor: UnitPoint = .center,
        angle: Angle = .zero, in context: inout GraphicsContext
    ) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        local.rotate(by: angle)
        local.draw(text(string, size: size, hex: hex), at: .zero, anchor: anchor)
    }

    /// A long thin triangle pointing left, its tip at `tip`.
    static func arrow(tip: CGPoint, length: CGFloat, height: CGFloat, hex: UInt32, angle: Angle = .zero, in context: inout GraphicsContext) {
        var local = context
        local.translateBy(x: tip.x, y: tip.y)
        local.rotate(by: angle)
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: length, y: -height / 2))
        path.addLine(to: CGPoint(x: length, y: height / 2))
        path.closeSubpath()
        local.fill(path, with: .color(Color(hex: hex)))
    }

    /// The thin light line the reference shows along two edges of the picture, where the clear film edge catches
    /// the light: `edges` are drawn just outside the picture.
    static func highlight(_ picture: CGRect, top: Bool, left: Bool, right: Bool, in context: inout GraphicsContext) {
        let width: CGFloat = 0.6
        var path = Path()
        if top {
            path.move(to: CGPoint(x: picture.minX, y: picture.minY - width / 2))
            path.addLine(to: CGPoint(x: picture.maxX, y: picture.minY - width / 2))
        }
        if left {
            path.move(to: CGPoint(x: picture.minX - width / 2, y: picture.minY))
            path.addLine(to: CGPoint(x: picture.minX - width / 2, y: picture.maxY))
        }
        if right {
            path.move(to: CGPoint(x: picture.maxX + width / 2, y: picture.minY))
            path.addLine(to: CGPoint(x: picture.maxX + width / 2, y: picture.maxY))
        }
        context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: width)
    }
}

/// The 35mm strip lying down: the film around the picture, perforations along both edges, and the DX code along
/// the bottom edge, which the perforations punch through.
private struct FilmStripArt {
    let geometry: FilmStripGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let u = g.unit
        let film = g.film
        let picture = g.picture
        // The film, with the picture cut out of it.
        var body = Path(film)
        body.addRect(picture)
        context.fill(body, with: .color(Color(hex: FilmStripGeometry.filmHex)), style: FillStyle(eoFill: true))
        EdgePrint.highlight(picture, top: true, left: false, right: true, in: &context)
        // The DX barcode along the bottom edge: one period of wide, narrow and medium bars, repeated; each bar
        // stands on the film's edge and reaches into the perforation band.
        let barHeight = 1.25 * u
        let barTop = film.maxY - barHeight
        let bars: [(offset: CGFloat, width: CGFloat)] = [
            (0, 2.3), (2.8, 0.47), (3.7, 0.47), (4.6, 0.47), (5.5, 0.47), (6.5, 0.47), (7.4, 0.47), (8.3, 0.47),
            (9.3, 1.4), (14.9, 2.1), (17.5, 0.47), (18.4, 0.47),
        ]
        let period = 19.3 * u
        var start = picture.minX + 1.8 * u
        while start > film.minX { start -= period }
        var x = start
        while x < film.maxX {
            for bar in bars {
                let rect = CGRect(x: x + bar.offset * u, y: barTop, width: bar.width * u, height: barHeight)
                if rect.maxX > film.minX, rect.minX < film.maxX {
                    context.fill(Path(rect.intersection(film)), with: .color(Color(hex: FilmStripGeometry.printHex)))
                }
            }
            x += period
        }
        // Perforations: the KS hole at its pitch along both edges, pitched from the picture's left edge.
        let topHoleY = film.minY + FilmStripGeometry.edge * u
        let bottomHoleY = film.maxY - (FilmStripGeometry.edge + FilmStripGeometry.holeAcross) * u
        var holeX = picture.minX + (FilmStripGeometry.pitch - FilmStripGeometry.holeAlong) / 2 * u
        while holeX > film.minX { holeX -= FilmStripGeometry.pitch * u }
        while holeX < film.maxX {
            for y in [topHoleY, bottomHoleY] {
                let hole = CGRect(x: holeX, y: y, width: FilmStripGeometry.holeAlong * u, height: FilmStripGeometry.holeAcross * u)
                    .intersection(film)
                if !hole.isNull, hole.width > 0 {
                    context.fill(Path(roundedRect: hole, cornerRadius: 0.3 * u), with: .color(.black))
                }
            }
            holeX += FilmStripGeometry.pitch * u
        }
    }
}

/// The 6×7 negative's rebate lying down: frame numbers with their arrows along the top band, the film's name and
/// the emulsion number along the bottom.
private struct SevenRebateArt {
    let geometry: RebateGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let picture = g.picture
        let w = picture.width
        let h = picture.height
        var film = Path(CGRect(origin: .zero, size: g.canvas))
        film.addRect(picture)
        context.fill(film, with: .color(Color(hex: RebateGeometry.sevenFilmHex)), style: FillStyle(eoFill: true))
        EdgePrint.highlight(picture, top: true, left: true, right: false, in: &context)
        let hex = RebateGeometry.sevenPrintHex
        let size = 0.026 * h
        let top = picture.minY - g.bands.top * g.unit / 2
        let bottom = picture.maxY + g.bands.bottom * g.unit / 2
        EdgePrint.draw("22", size: size, hex: hex, at: CGPoint(x: picture.minX + 0.012 * w, y: top), anchor: .center, in: &context)
        EdgePrint.arrow(tip: CGPoint(x: picture.minX + 0.031 * w, y: top), length: 0.046 * w, height: 0.016 * w, hex: hex, in: &context)
        EdgePrint.draw("21", size: size, hex: hex, at: CGPoint(x: picture.minX + 0.595 * w, y: top), anchor: .center, in: &context)
        EdgePrint.arrow(tip: CGPoint(x: picture.minX + 0.632 * w, y: top), length: 0.046 * w, height: 0.016 * w, hex: hex, in: &context)
        EdgePrint.draw("FILM PRO PLUS", size: size, hex: hex, at: CGPoint(x: picture.minX + 0.165 * w, y: bottom), anchor: .leading, in: &context)
        EdgePrint.draw("4454", size: size, hex: hex, at: CGPoint(x: picture.minX + 0.766 * w, y: bottom), anchor: .trailing, in: &context)
    }
}

/// The 6×6 negative's rebate: the film's name down the right band, reading downward, with marks on the left.
private struct SquareRebateArt {
    let geometry: RebateGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let picture = g.picture
        let s = picture.width
        var film = Path(CGRect(origin: .zero, size: g.canvas))
        film.addRect(picture)
        context.fill(film, with: .color(Color(hex: RebateGeometry.squareFilmHex)), style: FillStyle(eoFill: true))
        EdgePrint.highlight(picture, top: true, left: true, right: false, in: &context)
        let size = 0.024 * s
        let right = picture.maxX + g.bands.right * g.unit / 2
        let left = picture.minX - g.bands.left * g.unit / 2
        EdgePrint.draw("FILM PRO 400", size: size, hex: RebateGeometry.squarePrintHex, at: CGPoint(x: right, y: picture.minY + 0.21 * s), anchor: .leading, angle: .degrees(90), in: &context)
        EdgePrint.draw("49", size: size, hex: RebateGeometry.squarePrintHex, at: CGPoint(x: right, y: picture.minY + 0.905 * s), anchor: .leading, angle: .degrees(90), in: &context)
        EdgePrint.arrow(tip: CGPoint(x: left + 0.012 * s, y: picture.minY + 0.395 * s), length: 0.028 * s, height: 0.022 * s, hex: RebateGeometry.squareMarkHex, angle: .degrees(180), in: &context)
        EdgePrint.draw("7", size: size, hex: RebateGeometry.squareMarkHex, at: CGPoint(x: left, y: picture.minY + 0.44 * s), angle: .degrees(90), in: &context)
        EdgePrint.arrow(tip: CGPoint(x: left + 0.012 * s, y: picture.minY + 0.915 * s), length: 0.028 * s, height: 0.022 * s, hex: RebateGeometry.squareMarkHex, angle: .degrees(180), in: &context)
    }
}

/// The cardboard mount on its light table: a grey card pressed with half-moon dimples for a landscape picture,
/// a cream card with yellow stripes for a portrait one (the reference app uses both), the window cut out with the
/// film in its shadow, and the mount's own soft shadow on the table.
private struct SlideMountArt {
    let geometry: SlideMountGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let mount = g.mount
        let side = g.side
        // The shadow the mount throws on the table: soft all round, a little more below and to the right.
        for step in stride(from: 10, through: 1, by: -1) {
            let spread = CGFloat(step) * side * 0.0022
            let rect = mount.offsetBy(dx: side * 0.003, dy: side * 0.005).insetBy(dx: -spread, dy: -spread)
            context.fill(Path(roundedRect: rect, cornerRadius: g.cornerRadius + spread), with: .color(.black.opacity(0.022)))
        }
        // The card, with the window cut out.
        let card = Color(hex: g.isLandscape ? SlideMountGeometry.greyCardHex : SlideMountGeometry.creamCardHex)
        var body = Path(roundedRect: mount, cornerRadius: g.cornerRadius)
        body.addPath(Path(roundedRect: g.window, cornerRadius: g.windowRadius))
        context.fill(body, with: .color(card), style: FillStyle(eoFill: true))
        var inner = context
        inner.clip(to: body, style: FillStyle(eoFill: true))
        if g.isLandscape {
            drawGreyCard(mount: mount, side: side, in: &inner)
        } else {
            drawStripedCard(mount: mount, side: side, in: &inner)
        }
        // Paper speckle: fixed pseudo-random flecks, so every drawing of the mount is the same.
        var seed: UInt32 = 0x9E37_79B9
        func next() -> CGFloat {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return CGFloat(seed >> 8) / CGFloat(1 << 24)
        }
        for index in 0..<420 {
            let x = mount.minX + next() * mount.width
            let y = mount.minY + next() * mount.height
            let radius = side * (0.0012 + next() * 0.002)
            let dark = index.isMultiple(of: 3)
            inner.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(dark ? .black.opacity(0.05) : .white.opacity(0.1))
            )
        }
        // The window's edge: the film sits a little below the card, in its shadow, which fades in over the picture.
        for step in 1...6 {
            let inset = CGFloat(step) * side * 0.003
            context.stroke(
                Path(roundedRect: g.window.insetBy(dx: inset, dy: inset), cornerRadius: max(0, g.windowRadius - inset)),
                with: .color(.black.opacity(0.12 - 0.018 * Double(step))), lineWidth: side * 0.0035
            )
        }
    }

    /// The grey card's half-moon dimples: five along the top and bottom, three down each side.
    private func drawGreyCard(mount: CGRect, side: CGFloat, in context: inout GraphicsContext) {
        context.fill(
            Path(mount),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.05)]),
                startPoint: CGPoint(x: mount.minX, y: mount.minY), endPoint: CGPoint(x: mount.maxX, y: mount.maxY)
            )
        )
        let r = side * 0.026
        var centres: [CGPoint] = []
        for i in 0..<5 {
            let x = mount.minX + side * (0.18 + 0.16 * CGFloat(i))
            centres.append(CGPoint(x: x, y: mount.minY + side * 0.115))
            centres.append(CGPoint(x: x, y: mount.maxY - side * 0.115))
        }
        for i in 0..<3 {
            let y = mount.minY + side * (0.3 + 0.2 * CGFloat(i))
            centres.append(CGPoint(x: mount.minX + side * 0.09, y: y))
            centres.append(CGPoint(x: mount.maxX - side * 0.09, y: y))
        }
        for centre in centres {
            let disc = CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)
            // Pressed in: a dark rim on the upper half, light on the lower half, the inside a touch lighter.
            context.fill(Path(ellipseIn: disc), with: .color(.white.opacity(0.08)))
            var upper = Path()
            upper.addArc(center: centre, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            context.stroke(upper, with: .color(.black.opacity(0.16)), lineWidth: max(0.5, r * 0.12))
            var lower = Path()
            lower.addArc(center: centre, radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            context.stroke(lower, with: .color(.white.opacity(0.45)), lineWidth: max(0.5, r * 0.12))
        }
    }

    /// The cream card's yellow stripes: a wide and a narrow pair each side of the window.
    private func drawStripedCard(mount: CGRect, side: CGFloat, in context: inout GraphicsContext) {
        let yellow = Color(hex: SlideMountGeometry.stripeHex)
        for (start, width) in [(0.02, 0.064), (0.15, 0.064)] {
            context.fill(Path(CGRect(x: mount.minX + side * start, y: mount.minY, width: side * width, height: side)), with: .color(yellow))
            context.fill(Path(CGRect(x: mount.maxX - side * (start + width), y: mount.minY, width: side * width, height: side)), with: .color(yellow))
        }
        context.fill(
            Path(mount),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.1), .clear, .black.opacity(0.04)]),
                startPoint: CGPoint(x: mount.minX, y: mount.minY), endPoint: CGPoint(x: mount.maxX, y: mount.maxY)
            )
        )
    }
}

/// What both instant prints share: the print's shadow on the sheet, its faint outline, and the window's inner
/// shadow where the picture sits a little below the frame. Measured from the reference app's exports: the
/// shadow 0.009 of the print's width down and to the right, soft over 0.006; the corners rounded by 0.04.
private enum PrintArt {
    static func shadow(of print: CGRect, radius: CGFloat, in context: inout GraphicsContext) {
        let offset = print.width * 0.009
        var shade = context
        shade.addFilter(.blur(radius: print.width * 0.006))
        shade.fill(Path(roundedRect: print.offsetBy(dx: offset, dy: offset), cornerRadius: radius), with: .color(.black.opacity(0.22)))
    }

    static func outline(of print: CGRect, radius: CGFloat, in context: inout GraphicsContext) {
        context.stroke(Path(roundedRect: print, cornerRadius: radius), with: .color(.black.opacity(0.07)), lineWidth: max(0.3, print.width * 0.0006))
    }

    /// The picture sits below the frame's edge: a thin dark line and a soft shadow fading in over the picture.
    static func innerShadow(of window: CGRect, printWidth: CGFloat, in context: inout GraphicsContext) {
        var inner = context
        inner.clip(to: Path(window))
        inner.stroke(Path(window), with: .color(.black.opacity(0.28)), lineWidth: max(0.6, printWidth * 0.0012))
        for step in 1...6 {
            let inset = CGFloat(step) * printWidth * 0.0022
            inner.stroke(
                Path(window.insetBy(dx: inset, dy: inset)), with: .color(.black.opacity(0.09 - 0.013 * Double(step))),
                lineWidth: printWidth * 0.0024
            )
        }
    }

    /// The card with the window cut out, filled along the print from its top to its bottom with the stops
    /// given as (fraction of the print's height, colour).
    static func card(_ print: CGRect, window: CGRect, radius: CGFloat, from top: CGPoint, to bottom: CGPoint,
                     stops: [(CGFloat, UInt32)], in context: inout GraphicsContext) {
        var body = Path(roundedRect: print, cornerRadius: radius)
        body.addRect(window)
        context.fill(
            body,
            with: .linearGradient(
                Gradient(stops: stops.map { Gradient.Stop(color: Color(hex: $0.1), location: $0.0) }),
                startPoint: top, endPoint: bottom
            ),
            style: FillStyle(eoFill: true)
        )
    }
}

/// The mini instant print: cool white paper, a little darker beside the window's lower edge and brightest along
/// the wide border's far edge, as the reference app lights it.
private struct MiniPrintArt {
    let geometry: MiniPrintGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let print = g.print
        let window = g.window
        let radius = g.radius
        PrintArt.shadow(of: print, radius: radius, in: &context)
        // The paper's shading runs along the print from its (upright) top to its bottom.
        let top = g.isLandscape ? CGPoint(x: print.minX, y: print.midY) : CGPoint(x: print.midX, y: print.minY)
        let bottom = g.isLandscape ? CGPoint(x: print.maxX, y: print.midY) : CGPoint(x: print.midX, y: print.maxY)
        PrintArt.card(
            print, window: window, radius: radius, from: top, to: bottom,
            stops: [(0, 0xF1F3F3), (0.45, 0xECEEEF), (0.80, 0xE4E9EA), (0.86, 0xF0F2F2), (1, 0xF9FBFA)], in: &context
        )
        PrintArt.outline(of: print, radius: radius, in: &context)
        PrintArt.innerShadow(of: window, printWidth: min(print.width, print.height), in: &context)
    }
}

/// The square print's card in one of the reference app's designs: a light blue that goes greener toward the
/// bottom, a white card with cut-out shapes in blue, ochre, teal, black and pink, or a dark blue that goes from
/// cyan at the top to indigo at the bottom.
private struct SquarePrintArt {
    let geometry: SquarePrintGeometry
    let design: SquarePrintDesign

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let print = g.print
        let window = g.window
        let radius = g.radius
        PrintArt.shadow(of: print, radius: radius, in: &context)
        let top = CGPoint(x: print.midX, y: print.minY)
        let bottom = CGPoint(x: print.midX, y: print.maxY)
        switch design {
        case .lightBlue:
            PrintArt.card(
                print, window: window, radius: radius, from: top, to: bottom,
                stops: [(0, 0x5FB5DA), (0.26, 0x53ACD4), (0.50, 0x54AACB), (0.74, 0x61AFBF), (0.86, 0x74BAC5), (1, 0x87CDD7)], in: &context
            )
            glint(print, window: window, radius: radius, opacity: 0.12, in: &context)
        case .darkBlue:
            PrintArt.card(
                print, window: window, radius: radius, from: top, to: bottom,
                stops: [(0, 0x4677AA), (0.26, 0x416DA2), (0.50, 0x4A5C95), (0.74, 0x4C4B88), (0.86, 0x525191), (1, 0x5B599F)], in: &context
            )
            glint(print, window: window, radius: radius, opacity: 0.08, in: &context)
        case .whitePattern:
            PrintArt.card(
                print, window: window, radius: radius, from: top, to: bottom,
                stops: [(0, 0xF1F3F2), (0.78, 0xF1F3F2), (0.80, 0xD6BEB7), (1, 0xE6CFC8)], in: &context
            )
            shapes(print, window: window, radius: radius, in: &context)
        }
        PrintArt.outline(of: print, radius: radius, in: &context)
        PrintArt.innerShadow(of: window, printWidth: print.width, in: &context)
    }

    /// A little light on the top of the card.
    private func glint(_ print: CGRect, window: CGRect, radius: CGFloat, opacity: Double, in context: inout GraphicsContext) {
        var body = Path(roundedRect: print, cornerRadius: radius)
        body.addRect(window)
        context.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [.white.opacity(opacity), .clear]),
                center: CGPoint(x: print.midX, y: print.minY), startRadius: 0, endRadius: print.width * 0.55
            ),
            style: FillStyle(eoFill: true)
        )
    }

    /// The cut-out shapes of the white card, our own arrangement in the reference's colours: a blue blob at the
    /// top left, an ochre one at the top right, teal shapes down the sides, a black one on the left, and a
    /// cluster of black dots on the pink band.
    private func shapes(_ print: CGRect, window: CGRect, radius: CGFloat, in context: inout GraphicsContext) {
        var body = Path(roundedRect: print, cornerRadius: radius)
        body.addRect(window)
        var inner = context
        inner.clip(to: body, style: FillStyle(eoFill: true))
        let w = print.width
        func blob(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ hex: UInt32, turn: Double = 0) {
            var local = inner
            local.translateBy(x: print.minX + cx * w, y: print.minY + cy * w)
            local.rotate(by: .degrees(turn))
            local.fill(Path(ellipseIn: CGRect(x: -rx * w, y: -ry * w, width: 2 * rx * w, height: 2 * ry * w)), with: .color(Color(hex: hex)))
        }
        blob(0.12, 0.0, 0.17, 0.10, 0x275FBA, turn: -12)
        blob(0.86, 0.06, 0.09, 0.07, 0xD5971B, turn: 20)
        blob(0.0, 0.36, 0.10, 0.15, 0xA8D8DC, turn: 10)
        blob(1.0, 0.64, 0.08, 0.17, 0x81C4C9, turn: -8)
        blob(0.01, 0.54, 0.055, 0.09, 0x343539, turn: 15)
        blob(0.97, 0.26, 0.05, 0.06, 0xA8D8DC)
        blob(0.06, 1.12, 0.08, 0.06, 0xE6BE3C, turn: -10)
        blob(0.90, 1.16, 0.07, 0.05, 0x81C4C9, turn: 12)
        for row in 0..<3 {
            for column in 0..<4 {
                let cx = 0.58 + CGFloat(column) * 0.045 + (row.isMultiple(of: 2) ? 0 : 0.022)
                let cy = 1.06 + CGFloat(row) * 0.04
                blob(cx, cy, 0.009, 0.009, 0x2B2B2E)
            }
        }
    }
}

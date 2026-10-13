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

    var body: some View {
        switch frame {
        case .instantPrint, .fullFrame:
            // Flat paper, or nothing at all: the base colour is the whole frame.
            EmptyView()
        case .filmStrip, .slideMount, .mediumFormat, .square:
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
                case .instantPrint, .fullFrame:
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

import SwiftUI

/// Everything a frame draws around its picture: the film with its perforations and edge print, the mount with
/// its texture and dimples, or the rebate with its frame numbers. The window is left clear, so this is laid over
/// the picture. The screen draws it as a view and the exporter rasterises the same view at the file's scale,
/// so the two cannot drift apart. A wider-than-tall canvas gets the upright drawing turned on its side.
struct LookFrameView: View {
    let frame: LookFrame
    let size: CGSize

    var body: some View {
        switch frame {
        case .instantPrint:
            // Flat paper: the base colour is the whole frame.
            EmptyView()
        case .filmStrip, .slideMount, .mediumFormat, .square:
            Canvas(rendersAsynchronously: false) { context, _ in
                var context = context
                var canvas = size
                if size.width > size.height {
                    // Turned a quarter clockwise: the upright drawing's left edge becomes the top.
                    context.translateBy(x: size.width, y: 0)
                    context.rotate(by: .degrees(90))
                    canvas = CGSize(width: size.height, height: size.width)
                }
                switch frame {
                case .filmStrip: FilmStripArt(geometry: FilmStripGeometry(canvas: canvas)).draw(in: &context)
                case .slideMount: SlideMountArt(geometry: SlideMountGeometry(canvas: canvas)).draw(in: &context)
                case .mediumFormat: RebateArt(canvas: canvas, window: frame.window(in: canvas), isSquare: false).draw(in: &context)
                case .square: RebateArt(canvas: canvas, window: frame.window(in: canvas), isSquare: true).draw(in: &context)
                case .instantPrint: break
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// The orange edge print: a small monospaced sans, slightly soft, as it is exposed into the film's edge.
private enum EdgePrint {
    static let color = Color(hex: FilmStripGeometry.printHex, opacity: 0.92)

    static func text(_ string: String, size: CGFloat) -> Text {
        Text(string)
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
    }

    /// Draws text with its centre at `point`, turned by `angle`.
    static func draw(_ string: String, size: CGFloat, at point: CGPoint, angle: Angle = .zero, in context: inout GraphicsContext) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        local.rotate(by: angle)
        local.draw(text(string, size: size), at: .zero, anchor: .center)
    }

    /// A small solid triangle pointing right from `point`, as the arrows between frame numbers.
    static func arrow(at point: CGPoint, size: CGFloat, angle: Angle = .zero, in context: inout GraphicsContext) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        local.rotate(by: angle)
        var path = Path()
        path.move(to: CGPoint(x: -size * 0.6, y: -size * 0.45))
        path.addLine(to: CGPoint(x: size * 0.6, y: 0))
        path.addLine(to: CGPoint(x: -size * 0.6, y: size * 0.45))
        path.closeSubpath()
        local.fill(path, with: .color(color))
    }
}

/// The 35mm strip: the film around the picture, perforations down both sides, and the edge print outside them.
private struct FilmStripArt {
    let geometry: FilmStripGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let canvas = CGRect(origin: .zero, size: g.canvas)
        // The film, with the picture cut out of it.
        var film = Path(g.film)
        film.addRect(g.picture)
        context.fill(film, with: .color(Color(hex: FilmStripGeometry.filmHex)), style: FillStyle(eoFill: true))
        // A faint lighter line where the picture's edge was exposed through the gate.
        context.stroke(Path(g.picture.insetBy(dx: -0.5, dy: -0.5)), with: .color(.white.opacity(0.06)), lineWidth: 1)
        // Perforations.
        for top in g.holeTops {
            for x in [g.leftHoleX, g.rightHoleX] {
                let hole = CGRect(x: x, y: top, width: g.holeAcross, height: g.holeAlong)
                context.fill(Path(roundedRect: hole, cornerRadius: g.holeRadius), with: .color(.black))
            }
        }
        // Edge print: the film's name up the left edge, frame numbers and a barcode down the right.
        let size = g.printSize
        let leftX = g.film.minX + g.edge / 2
        let rightX = g.film.maxX - g.edge / 2
        let middle = g.picture.midY
        EdgePrint.draw("RETROSNAP 400", size: size, at: CGPoint(x: leftX, y: middle), angle: .degrees(-90), in: &context)
        EdgePrint.draw("12", size: size, at: CGPoint(x: leftX, y: g.picture.minY + size * 2), angle: .degrees(-90), in: &context)
        EdgePrint.draw("13", size: size, at: CGPoint(x: leftX, y: g.picture.maxY - size * 2), angle: .degrees(-90), in: &context)
        EdgePrint.draw("12A", size: size, at: CGPoint(x: rightX, y: g.picture.minY + size * 2.6), angle: .degrees(90), in: &context)
        EdgePrint.arrow(at: CGPoint(x: rightX, y: g.picture.minY + size * 5.2), size: size * 0.8, angle: .degrees(90), in: &context)
        // The DX barcode: bars of two widths in a fixed pattern, in two groups.
        let bars: [CGFloat] = [2, 1, 1, 2, 1, 3, 1, 1, 2, 1, 1, 1, 3, 1, 2, 1, 1, 2]
        for group in 0..<2 {
            var y = middle + g.unit * (group == 0 ? 0.12 : 0.42)
            for (index, weight) in bars.enumerated() {
                let along = size * 0.22 * weight
                if index.isMultiple(of: 2) {
                    let bar = CGRect(x: rightX - g.edge * 0.36, y: y, width: g.edge * 0.72, height: along)
                    context.fill(Path(bar), with: .color(EdgePrint.color))
                }
                y += along
            }
        }
        _ = canvas
    }
}

/// The cardboard mount: a lightly textured card with its window cut out, pressed dimples, and a shadow on the table.
private struct SlideMountArt {
    let geometry: SlideMountGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let mount = g.mount
        let card = Color(hex: SlideMountGeometry.cardHex)
        // The shadow the mount throws on the table.
        for step in stride(from: 6, through: 1, by: -1) {
            let spread = CGFloat(step) * g.side * 0.004
            let rect = mount.offsetBy(dx: 0, dy: g.side * 0.008).insetBy(dx: -spread, dy: -spread)
            context.fill(Path(roundedRect: rect, cornerRadius: g.cornerRadius + spread), with: .color(.black.opacity(0.035)))
        }
        // The card, with the window cut out.
        var body = Path(roundedRect: mount, cornerRadius: g.cornerRadius)
        body.addPath(Path(roundedRect: g.window, cornerRadius: g.windowRadius))
        context.fill(body, with: .color(card), style: FillStyle(eoFill: true))
        // A little light falling across the card.
        context.clip(to: body, style: FillStyle(eoFill: true))
        context.fill(
            Path(mount),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.06)]),
                startPoint: CGPoint(x: mount.minX, y: mount.minY), endPoint: CGPoint(x: mount.maxX, y: mount.maxY)
            )
        )
        // Paper speckle: fixed pseudo-random flecks, so every drawing of the mount is the same.
        var seed: UInt32 = 0x9E37_79B9
        func next() -> CGFloat {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return CGFloat(seed >> 8) / CGFloat(1 << 24)
        }
        for index in 0..<340 {
            let x = mount.minX + next() * mount.width
            let y = mount.minY + next() * mount.height
            let radius = g.side * (0.0015 + next() * 0.0025)
            let dark = index.isMultiple(of: 3)
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(dark ? .black.opacity(0.05) : .white.opacity(0.09))
            )
        }
        // The dimples the mount was pressed with: five across the top and bottom, four down each side.
        let r = g.dimpleRadius
        var centres: [CGPoint] = []
        for i in 0..<5 {
            let x = mount.minX + mount.width * (0.18 + 0.16 * CGFloat(i))
            centres.append(CGPoint(x: x, y: mount.minY + g.side * 0.115))
            centres.append(CGPoint(x: x, y: mount.maxY - g.side * 0.115))
        }
        for i in 0..<4 {
            let y = mount.minY + mount.height * (0.26 + 0.16 * CGFloat(i))
            centres.append(CGPoint(x: mount.minX + g.side * 0.09, y: y))
            centres.append(CGPoint(x: mount.maxX - g.side * 0.09, y: y))
        }
        for centre in centres {
            let disc = CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: disc),
                with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.13), .clear, .white.opacity(0.4)]),
                    startPoint: CGPoint(x: centre.x, y: disc.minY), endPoint: CGPoint(x: centre.x, y: disc.maxY)
                )
            )
            context.stroke(Path(ellipseIn: disc), with: .color(.black.opacity(0.06)), lineWidth: max(0.5, r * 0.08))
        }
        // The window's edge: the film sits a little below the card, in its shadow, which fades in over the picture.
        for step in 1...8 {
            let inset = CGFloat(step) * g.side * 0.0045
            context.stroke(
                Path(roundedRect: g.window.insetBy(dx: inset, dy: inset), cornerRadius: max(0, g.windowRadius - inset)),
                with: .color(.black.opacity(0.13 - 0.013 * Double(step))), lineWidth: g.side * 0.005
            )
        }
    }
}

/// A medium-format negative's rebate: black film around the picture, with the frame numbers along the top and the
/// film's name along the bottom for 6×7, or down the right edge for the square 6×6.
private struct RebateArt {
    let canvas: CGSize
    let window: CGRect
    let isSquare: Bool

    func draw(in context: inout GraphicsContext) {
        var film = Path(CGRect(origin: .zero, size: canvas))
        film.addRect(window)
        context.fill(film, with: .color(.black), style: FillStyle(eoFill: true))
        context.stroke(Path(window.insetBy(dx: -0.5, dy: -0.5)), with: .color(.white.opacity(0.07)), lineWidth: 1)
        let size = canvas.width * (isSquare ? 0.021 : 0.026)
        if isSquare {
            let x = (window.maxX + canvas.width) / 2
            EdgePrint.draw("RETROSNAP 400", size: size, at: CGPoint(x: x, y: window.midY), angle: .degrees(-90), in: &context)
            EdgePrint.draw("12", size: size, at: CGPoint(x: x, y: window.minY + size * 3), angle: .degrees(-90), in: &context)
            let left = (window.minX + 0) / 2
            EdgePrint.arrow(at: CGPoint(x: left, y: window.minY + window.height * 0.3), size: size * 0.9, in: &context)
            EdgePrint.arrow(at: CGPoint(x: left, y: window.minY + window.height * 0.7), size: size * 0.9, in: &context)
        } else {
            let top = window.minY / 2
            let bottom = (window.maxY + canvas.height) / 2
            EdgePrint.draw("12", size: size, at: CGPoint(x: window.minX + size * 1.6, y: top), in: &context)
            EdgePrint.arrow(at: CGPoint(x: window.minX + size * 4.4, y: top), size: size * 0.9, angle: .degrees(180), in: &context)
            EdgePrint.draw("13", size: size, at: CGPoint(x: window.midX + size * 1.6, y: top), in: &context)
            EdgePrint.arrow(at: CGPoint(x: window.midX + size * 4.4, y: top), size: size * 0.9, angle: .degrees(180), in: &context)
            EdgePrint.draw("RETROSNAP 400", size: size, at: CGPoint(x: window.minX + window.width * 0.22, y: bottom), in: &context)
            EdgePrint.draw("0407", size: size, at: CGPoint(x: window.minX + window.width * 0.78, y: bottom), in: &context)
        }
    }
}

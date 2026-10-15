import SwiftUI

/// A square cardboard mount on a white light table, on a 3:4 canvas: the mount 0.81 of the canvas wide and
/// centred, its 3:2 window centred in it and turned the way the picture is. The window measured over six of the
/// reference app's screens is 0.67 of the mount's side along and 0.46 across (the refinement round, 13 October
/// 2026; batch 1 had read 0.447 off one screen). The card is one of four designs (`SlideMountDesign`).
nonisolated struct SlideMountGeometry: Hashable, Sendable {
    static let canvasAspect: CGFloat = 3.0 / 4
    static let tableHex: UInt32 = 0xFFFFFF
    static let greyCardHex: UInt32 = 0xBABAAB
    static let creamCardHex: UInt32 = 0xE9E0C9
    static let stripeHex: UInt32 = 0xE9D882
    /// The printed cream card (sRGB, measured on two screens: 236, 229, 215) and its coral print.
    static let printedCardHex: UInt32 = 0xECE5D7
    static let printedInkHex: UInt32 = 0xE67A6A
    /// The white plastic mount's body (225 grey) and the paper label across its top (230, 228, 225).
    static let plasticHex: UInt32 = 0xE1E1E1
    static let labelHex: UInt32 = 0xE6E4E1
    static let mountFraction: CGFloat = 0.81
    static let windowLong: CGFloat = 0.67
    static let windowShort: CGFloat = 0.46

    let canvas: CGSize
    let photoAspect: CGFloat
    let design: SlideMountDesign

    init(canvas: CGSize, photoAspect: CGFloat = Photo.cameraAspect, design: SlideMountDesign = .greyDimpled) {
        self.canvas = canvas
        self.photoAspect = photoAspect
        self.design = design
    }

    var isLandscape: Bool {
        photoAspect >= 1
    }

    var side: CGFloat {
        min(canvas.width, canvas.height * Self.canvasAspect) * Self.mountFraction
    }

    var mount: CGRect {
        CGRect(centredIn: canvas, size: CGSize(width: side, height: side))
    }

    var window: CGRect {
        let size = isLandscape
            ? CGSize(width: side * Self.windowLong, height: side * Self.windowShort)
            : CGSize(width: side * Self.windowShort, height: side * Self.windowLong)
        return CGRect(centredIn: canvas, size: size)
    }

    var cornerRadius: CGFloat {
        side * design.cornerFraction
    }

    var windowRadius: CGFloat { side * 0.012 }
}

// MARK: -

/// The slide mount's card, as the reference app varies it from slide to slide: a grey card pressed with half-moon
/// dimples, a cream card with yellow stripes, a cream card printed "this side towards screen" down its left side,
/// and a white plastic mount with a paper label across the top (the last two seen in the refinement round). A photo
/// gets one by its id, so a slide always comes out the same and the gallery varies as the reference app's does.
nonisolated enum SlideMountDesign: Int, CaseIterable, Hashable, Sendable {
    case greyDimpled
    case creamStriped
    case creamPrinted
    case whitePlastic

    /// The `0xRRGGBB` colour of the card.
    fileprivate var cardHex: UInt32 {
        switch self {
        case .greyDimpled: SlideMountGeometry.greyCardHex
        case .creamStriped: SlideMountGeometry.creamCardHex
        case .creamPrinted: SlideMountGeometry.printedCardHex
        case .whitePlastic: SlideMountGeometry.plasticHex
        }
    }

    /// The card's corners, in units of its side: the printed cream card is cut round (0.09, measured), the
    /// plastic mount a little, the pressed cards hardly at all.
    fileprivate var cornerFraction: CGFloat {
        switch self {
        case .creamPrinted: 0.09
        case .whitePlastic: 0.03
        case .greyDimpled, .creamStriped: 0.008
        }
    }

    /// How many flecks of paper speckle the card gets.
    fileprivate var fleckCount: Int {
        self == .whitePlastic ? 120 : 420
    }

    /// The design for a photo id: a stable hash, so the same photo always gets the same card.
    static func forPhoto(id: String) -> SlideMountDesign {
        allCases[Int(FrameDesign.hash(id, salt: "slide") % UInt32(allCases.count))]
    }
}

// MARK: -

/// The cardboard mount on its light table in one of the reference app's designs (`SlideMountDesign`): a grey card
/// pressed with half-moon dimples, a cream card with yellow stripes, a cream card printed "this side towards
/// screen" down its left side, or a white plastic mount with a paper label across the top; the window cut out with
/// the film in its shadow, and the mount's own soft shadow on the table.
struct SlideMountArt {
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
        let body = Path(roundedRect: mount, cornerRadius: g.cornerRadius)
            .cuttingOut(Path(roundedRect: g.window, cornerRadius: g.windowRadius))
        context.fill(body, with: .color(Color(hex: g.design.cardHex)), style: .evenOdd)
        var inner = context
        inner.clip(to: body, style: .evenOdd)
        switch g.design {
        case .greyDimpled: drawGreyCard(mount: mount, side: side, in: &inner)
        case .creamStriped: drawStripedCard(mount: mount, side: side, in: &inner)
        case .creamPrinted: drawPrintedCard(mount: mount, side: side, in: &inner)
        case .whitePlastic: drawPlasticMount(mount: mount, side: side, in: &inner)
        }
        // Paper speckle: fixed pseudo-random flecks, so every drawing of the mount is the same.
        var seed: UInt32 = 0x9E37_79B9
        func next() -> CGFloat {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return CGFloat(seed >> 8) / CGFloat(1 << 24)
        }
        for index in 0..<g.design.fleckCount {
            let x = mount.minX + next() * mount.width
            let y = mount.minY + next() * mount.height
            let radius = side * (0.0012 + next() * 0.002)
            let dark = index.isMultiple(of: 3)
            inner.fill(
                Path(ellipseIn: CGRect(centre: CGPoint(x: x, y: y), radius: radius)),
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

    /// The card's light: white at the top left through clear to black at the bottom right.
    private func sheen(_ mount: CGRect, light: Double, dark: Double, in context: inout GraphicsContext) {
        context.fill(
            Path(mount),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(light), .clear, .black.opacity(dark)]),
                startPoint: CGPoint(x: mount.minX, y: mount.minY), endPoint: CGPoint(x: mount.maxX, y: mount.maxY)
            )
        )
    }

    /// The grey card's half-moon dimples: five along the top and bottom, three down each side.
    private func drawGreyCard(mount: CGRect, side: CGFloat, in context: inout GraphicsContext) {
        sheen(mount, light: 0.12, dark: 0.05, in: &context)
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
            let disc = CGRect(centre: centre, radius: r)
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
        sheen(mount, light: 0.1, dark: 0.04, in: &context)
    }

    /// The printed card: "this side towards screen" in coral, reading upward along the left side, measured on
    /// the reference app's screens as a run 0.53 of the side long centred 0.477 down, its letters 0.04 of the
    /// side tall in a band 0.062 to 0.102 in from the left edge.
    private func drawPrintedCard(mount: CGRect, side: CGFloat, in context: inout GraphicsContext) {
        sheen(mount, light: 0.08, dark: 0.03, in: &context)
        let trial = side * 0.05
        let probe = context.resolve(Text(verbatim: "this side towards screen").font(.system(size: trial, weight: .regular)))
        let measured = probe.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
        let size = trial * (side * 0.528 / max(measured, 1))
        let text = context.resolve(
            Text(verbatim: "this side towards screen").font(.system(size: size, weight: .regular))
                .foregroundColor(Color(hex: SlideMountGeometry.printedInkHex))
        )
        var local = context
        local.translateBy(x: mount.minX + side * 0.082, y: mount.minY + side * 0.477)
        local.rotate(by: .degrees(-90))
        local.draw(text, at: .zero, anchor: .center)
    }

    /// The white plastic mount: a moulded rim (a light bevel, a dark line 0.017 in, a shallow groove at 0.03 to
    /// 0.045 with a dark line at its inner edge), and the paper label across the top, from 0.045 to 0.26 of the side
    /// down, with a soft lower edge. The body (225 grey) and the label (230, 228, 225) measure as the reference's.
    private func drawPlasticMount(mount: CGRect, side: CGFloat, in context: inout GraphicsContext) {
        let radius = side * 0.03
        context.stroke(
            Path(roundedRect: mount.insetBy(dx: side * 0.006, dy: side * 0.006), cornerRadius: radius),
            with: .color(.white.opacity(0.7)), lineWidth: side * 0.012
        )
        context.stroke(
            Path(roundedRect: mount.insetBy(dx: side * 0.017, dy: side * 0.017), cornerRadius: radius * 0.8),
            with: .color(.black.opacity(0.2)), lineWidth: side * 0.003
        )
        context.stroke(
            Path(roundedRect: mount.insetBy(dx: side * 0.038, dy: side * 0.038), cornerRadius: radius * 0.6),
            with: .color(.black.opacity(0.08)), lineWidth: side * 0.012
        )
        context.stroke(
            Path(roundedRect: mount.insetBy(dx: side * 0.045, dy: side * 0.045), cornerRadius: radius * 0.55),
            with: .color(.black.opacity(0.13)), lineWidth: side * 0.003
        )
        let label = CGRect(x: mount.minX + side * 0.05, y: mount.minY + side * 0.045, width: side * 0.9, height: side * 0.215)
        var shade = context
        shade.addFilter(.blur(radius: side * 0.004))
        shade.fill(Path(label.offsetBy(dx: 0, dy: side * 0.004)), with: .color(.black.opacity(0.08)))
        context.fill(Path(label), with: .color(Color(hex: SlideMountGeometry.labelHex)))
    }
}

import SwiftUI

/// A square instant print on its sheet, measured from the reference app's exports in units of the canvas's
/// width (the canvas is 3024:3840, upright whichever way the photo is): the print 0.893 wide and 1.2007 times as
/// tall as it is wide, 0.046 in from the left and 0.097 down from the top; its square window 0.855 of the print
/// wide, 0.073 of the print in from each side and 0.120 from the top, leaving 0.226 below; the print's corners
/// rounded by 0.04 of its width. The frame's design is one of five the reference app draws (`SquarePrintDesign`).
nonisolated struct SquarePrintGeometry: Hashable, Sendable {
    static let canvasAspect: CGFloat = 3024.0 / 3840
    static let printWidth: CGFloat = 0.8925
    static let printHeight: CGFloat = 0.8925 * 1.2007
    static let printLeft: CGFloat = 0.0456
    static let printTop: CGFloat = 0.0969
    static let windowWidth: CGFloat = 0.8547
    /// The window is centred: 0.073 of the print each side.
    static let windowSide: CGFloat = (1 - windowWidth) / 2
    static let windowTop: CGFloat = 0.1204
    static let cornerRadius: CGFloat = 0.040

    let canvas: CGSize

    /// Points per unit of the canvas's width, with the canvas's shape fitted and centred in the box.
    var unit: CGFloat {
        min(canvas.width, canvas.height * Self.canvasAspect)
    }

    var sheet: CGRect {
        let size = CGSize(width: unit, height: unit / Self.canvasAspect)
        return CGRect(centredIn: canvas, size: size)
    }

    var print: CGRect {
        let s = sheet
        return CGRect(x: s.minX + Self.printLeft * unit, y: s.minY + Self.printTop * unit, width: Self.printWidth * unit, height: Self.printHeight * unit)
    }

    var window: CGRect {
        let p = print
        let side = Self.windowWidth * p.width
        return CGRect(x: p.minX + Self.windowSide * p.width, y: p.minY + Self.windowTop * p.width, width: side, height: side)
    }

    var radius: CGFloat {
        Self.cornerRadius * Self.printWidth * unit
    }
}

// MARK: -

/// The square print's frame designs, as the reference app varies them from print to print: a light blue card,
/// a white card with cut-out shapes, a dark blue card, a plain white card and a green one (the last two seen in
/// the refinement round, 13 October 2026). A photo gets one by its id, so a print always comes out the same and
/// the gallery varies as the reference app's does.
nonisolated enum SquarePrintDesign: Int, CaseIterable, Hashable, Sendable {
    case lightBlue
    case whitePattern
    case darkBlue
    case plainWhite
    case green

    /// The card's gradient down the print, as (fraction of the print's height, `0xRRGGBB` colour) stops.
    fileprivate var cardStops: [(CGFloat, UInt32)] {
        switch self {
        case .lightBlue:
            [(0, 0x5FB5DA), (0.26, 0x53ACD4), (0.50, 0x54AACB), (0.74, 0x61AFBF), (0.86, 0x74BAC5), (1, 0x87CDD7)]
        case .darkBlue:
            [(0, 0x4677AA), (0.26, 0x416DA2), (0.50, 0x4A5C95), (0.74, 0x4C4B88), (0.86, 0x525191), (1, 0x5B599F)]
        case .whitePattern:
            [(0, 0xF1F3F2), (0.78, 0xF1F3F2), (0.80, 0xD6BEB7), (1, 0xE6CFC8)]
        case .plainWhite:
            [(0, 0xF1F2F4), (0.3, 0xEFF0F2), (0.5, 0xECEEF0), (0.7, 0xE7EBEC), (0.9, 0xF2F3F5), (1, 0xF4F5F6)]
        case .green:
            [(0, 0x6AA56D), (0.26, 0x639E66), (0.40, 0x5D985C), (0.50, 0x619454), (0.60, 0x648F47), (0.70, 0x658F42),
             (0.80, 0x729A46), (0.90, 0x94B55B), (1, 0x9CBB62)]
        }
    }

    /// The opacity of the light on the top of the card, if it has any.
    fileprivate var glintOpacity: Double? {
        switch self {
        case .lightBlue: 0.12
        case .darkBlue, .green: 0.08
        case .whitePattern, .plainWhite: nil
        }
    }

    /// Whether the card has cut-out shapes.
    fileprivate var hasShapes: Bool {
        self == .whitePattern
    }

    /// The design for a photo id: a stable hash, so the same photo always gets the same card.
    static func forPhoto(id: String) -> SquarePrintDesign {
        allCases[Int(FrameDesign.hash(id, salt: "") % UInt32(allCases.count))]
    }
}

// MARK: -

/// The square print's card in one of the reference app's designs: a light blue that goes greener toward the
/// bottom, a white card with cut-out shapes in blue, ochre, teal, black and pink, a dark blue that goes from
/// cyan at the top to indigo at the bottom, a plain white card, or a green that goes from leaf green at the top to
/// a lighter yellow-green at the bottom (the last two measured down the card on the reference app's exports).
struct SquarePrintArt {
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
        PrintArt.card(print, window: window, radius: radius, from: top, to: bottom, stops: design.cardStops, in: &context)
        if let opacity = design.glintOpacity {
            glint(print, window: window, radius: radius, opacity: opacity, in: &context)
        }
        if design.hasShapes {
            shapes(print, window: window, radius: radius, in: &context)
        }
        PrintArt.outline(of: print, radius: radius, in: &context)
        PrintArt.innerShadow(of: window, printWidth: print.width, in: &context)
    }

    /// A little light on the top of the card.
    private func glint(_ print: CGRect, window: CGRect, radius: CGFloat, opacity: Double, in context: inout GraphicsContext) {
        context.fill(
            Path(roundedRect: print, cornerRadius: radius).cuttingOut(window),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(opacity), .clear]),
                center: CGPoint(x: print.midX, y: print.minY), startRadius: 0, endRadius: print.width * 0.55
            ),
            style: .evenOdd
        )
    }

    /// The cut-out shapes of the white card, our own arrangement in the reference's colours: a blue blob at the
    /// top left, an ochre one at the top right, teal shapes down the sides, a black one on the left, and a
    /// cluster of black dots on the pink band.
    private func shapes(_ print: CGRect, window: CGRect, radius: CGFloat, in context: inout GraphicsContext) {
        var inner = context
        inner.clip(to: Path(roundedRect: print, cornerRadius: radius).cuttingOut(window), style: .evenOdd)
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

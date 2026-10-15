import SwiftUI

/// A black rebate around a medium-format negative, with the bands measured as fractions of the picture.
nonisolated struct RebateGeometry: Hashable, Sendable {
    static let sevenFilmHex: UInt32 = 0x020707
    static let sevenPrintHex: UInt32 = 0xD48E58
    static let squareFilmHex: UInt32 = 0x0B0C0B
    static let squarePrintHex: UInt32 = 0xD99340
    static let squareMarkHex: UInt32 = 0xE4A356

    /// The 6×7 negative lying down: a 1.25 × 1 picture with the bands around it.
    static let sevenLandscape = Bands(picture: CGSize(width: 1.25, height: 1), left: 0.0375, right: 0.0375, top: 0.069, bottom: 0.082)
    /// Standing up: the frame numbers' band on the left and the film name's on the right.
    static let sevenPortrait = Bands(picture: CGSize(width: 1, height: 1.25), left: 0.102, right: 0.033, top: 0.056, bottom: 0.056)
    /// The 6×6 negative: the edge print's band on the right, the same whichever way the photo is.
    static let squareBands = Bands(picture: CGSize(width: 1, height: 1), left: 0.03, right: 0.056, top: 0.026, bottom: 0.032)

    /// A picture with a band of film on each side, in units of the picture's short side.
    struct Bands: Hashable, Sendable {
        let picture: CGSize
        let left: CGFloat
        let right: CGFloat
        let top: CGFloat
        let bottom: CGFloat

        var canvas: CGSize {
            CGSize(width: picture.width + left + right, height: picture.height + top + bottom)
        }

        var canvasAspect: CGFloat {
            let size = canvas
            return size.width / size.height
        }

        /// The bands fitted into a canvas of this size and centred: points per unit, and the picture.
        func fitted(in size: CGSize) -> RebateGeometry {
            let unit = min(size.width / canvas.width, size.height / canvas.height)
            let x = (size.width - canvas.width * unit) / 2 + left * unit
            let y = (size.height - canvas.height * unit) / 2 + top * unit
            return RebateGeometry(
                canvas: size, unit: unit, bands: self,
                picture: CGRect(x: x, y: y, width: picture.width * unit, height: picture.height * unit)
            )
        }
    }

    let canvas: CGSize
    let unit: CGFloat
    let bands: Bands
    let picture: CGRect

    static func seven(in canvas: CGSize) -> RebateGeometry {
        (canvas.width > canvas.height ? sevenLandscape : sevenPortrait).fitted(in: canvas)
    }

    static func square(in canvas: CGSize) -> RebateGeometry {
        squareBands.fitted(in: canvas)
    }
}

// MARK: -

/// The 6×7 negative's rebate lying down: frame numbers with their arrows along the top band, the film's name and
/// the emulsion number along the bottom.
struct SevenRebateArt {
    let geometry: RebateGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let picture = g.picture
        let w = picture.width
        let h = picture.height
        RebateArt.drawFilm(g, hex: RebateGeometry.sevenFilmHex, in: &context)
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

// MARK: -

/// The 6×6 negative's rebate: the film's name down the right band, reading downward, with marks on the left.
struct SquareRebateArt {
    let geometry: RebateGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let picture = g.picture
        let s = picture.width
        RebateArt.drawFilm(g, hex: RebateGeometry.squareFilmHex, in: &context)
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

// MARK: -

private enum RebateArt {
    /// The rebate's film with the picture cut out, and the light along the picture's top and left edges.
    static func drawFilm(_ geometry: RebateGeometry, hex: UInt32, in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: geometry.canvas)).cuttingOut(geometry.picture), with: .color(Color(hex: hex)), style: .evenOdd)
        EdgePrint.highlight(geometry.picture, top: true, left: true, right: false, in: &context)
    }
}

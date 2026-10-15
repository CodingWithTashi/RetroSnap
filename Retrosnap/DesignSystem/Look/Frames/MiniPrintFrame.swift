import SwiftUI

/// A mini instant print on its sheet, measured from the reference app's exports in units of the sheet's width
/// (the sheet is 2:3; a landscape photo gets the whole sheet turned a quarter anticlockwise): the print 0.899
/// wide, 0.044 in from the left and 0.053 down from the top, its 3:4 window 0.845 of the print wide with
/// 0.077 of the print each side, 0.131 above and 0.304 below; the print's corners rounded by 0.04 of its width,
/// a thin outline, and a soft shadow down and to the right.
nonisolated struct MiniPrintGeometry: Hashable, Sendable {
    static let sheetHex: UInt32 = 0xFFFFFF
    /// The sheet's width over its height, standing up.
    static let sheetAspect: CGFloat = 2.0 / 3
    static let printWidth: CGFloat = 0.8988
    static let printHeight: CGFloat = 0.8988 * 1.5625
    static let printLeft: CGFloat = 0.0439
    static let printTop: CGFloat = 0.0528
    static let windowWidth: CGFloat = 0.8452
    static let windowHeight: CGFloat = 0.8452 * 4 / 3
    static let windowSide: CGFloat = 0.0774
    static let windowTop: CGFloat = 0.1306
    static let cornerRadius: CGFloat = 0.040

    let canvas: CGSize

    /// The sheet lies down (a landscape picture) or stands up.
    var isLandscape: Bool {
        canvas.width > canvas.height
    }

    /// Points per unit of the sheet's (upright) width, with the sheet fitted and centred in the canvas.
    var unit: CGFloat {
        isLandscape
            ? min(canvas.height, canvas.width * Self.sheetAspect)
            : min(canvas.width, canvas.height * Self.sheetAspect)
    }

    /// The sheet, fitted and centred in the canvas.
    var sheet: CGRect {
        let size = isLandscape ? CGSize(width: unit / Self.sheetAspect, height: unit) : CGSize(width: unit, height: unit / Self.sheetAspect)
        return CGRect(centredIn: canvas, size: size)
    }

    /// A rectangle given in the upright sheet's units, placed on the canvas: turned a quarter anticlockwise
    /// when the sheet lies down (the upright top edge becomes the left edge).
    private func placed(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        let s = sheet
        if isLandscape {
            // Upright (x, y) from the top-left maps to (y, 1 - x - width) on the lying sheet.
            return CGRect(x: s.minX + y * unit, y: s.minY + (1 - x - width) * unit, width: height * unit, height: width * unit)
        }
        return CGRect(x: s.minX + x * unit, y: s.minY + y * unit, width: width * unit, height: height * unit)
    }

    var print: CGRect {
        placed(x: Self.printLeft, y: Self.printTop, width: Self.printWidth, height: Self.printHeight)
    }

    var window: CGRect {
        placed(
            x: Self.printLeft + Self.windowSide * Self.printWidth, y: Self.printTop + Self.windowTop * Self.printWidth,
            width: Self.windowWidth * Self.printWidth, height: Self.windowHeight * Self.printWidth
        )
    }

    /// The print's corner radius in points.
    var radius: CGFloat {
        Self.cornerRadius * Self.printWidth * unit
    }
}

/// The mini instant print: cool white paper, a little darker beside the window's lower edge and brightest along
/// the wide border's far edge, as the reference app lights it.
struct MiniPrintArt {
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

import SwiftUI

/// The edge print: a small condensed sans, as it is exposed into the film's edge.
enum EdgePrint {
    static func text(_ string: String, size: CGFloat, hex: UInt32, weight: Font.Weight = .medium) -> Text {
        Text(string)
            .font(.system(size: size, weight: weight).width(.condensed))
            .foregroundStyle(Color(hex: hex))
    }

    /// Draws text at `point`, placed there by `anchor` (its centre by default), turned by `angle`.
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

// MARK: -

/// What both instant prints share: the print's shadow on the sheet, its faint outline, and the window's inner
/// shadow where the picture sits a little below the frame. Measured from the reference app's exports: the
/// shadow 0.009 of the print's width down and to the right, soft over 0.006; the corners rounded by 0.04.
enum PrintArt {
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
        context.fill(
            Path(roundedRect: print, cornerRadius: radius).cuttingOut(window),
            with: .linearGradient(
                Gradient(stops: stops.map { Gradient.Stop(color: Color(hex: $0.1), location: $0.0) }),
                startPoint: top, endPoint: bottom
            ),
            style: .evenOdd
        )
    }
}

// MARK: -

extension Path {
    /// This path with `hole` added: under an even-odd fill or clip (`.evenOdd`) the hole stays clear.
    func cuttingOut(_ hole: CGRect) -> Path {
        var path = self
        path.addRect(hole)
        return path
    }

    func cuttingOut(_ hole: Path) -> Path {
        var path = self
        path.addPath(hole)
        return path
    }
}

// MARK: -

extension FillStyle {
    /// Even-odd filling, so a path's inner subpath cuts a hole in its outer one.
    static var evenOdd: FillStyle { FillStyle(eoFill: true) }
}

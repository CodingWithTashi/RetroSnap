import SwiftUI

/// A strip of 135 film, measured in its picture's short side (24mm on real film) as the reference app draws it:
/// the perforations at the real KS pitch and size, 0.6 from the picture, with 0.45 of film beyond them, so the
/// strip is 31.96 across; along the film the canvas is the 36 picture plus 1 of film at each end.
nonisolated struct FilmStripGeometry: Hashable, Sendable {
    static let filmHex: UInt32 = 0x0B0B0B
    static let printHex: UInt32 = 0xB56A1A
    static let pictureLong: CGFloat = 36
    static let pictureShort: CGFloat = 24
    static let gap: CGFloat = 0.6
    static let holeAcross: CGFloat = 2.93
    static let holeAlong: CGFloat = 2.05
    static let pitch: CGFloat = 4.72
    static let edge: CGFloat = 0.45
    static let endMargin: CGFloat = 1
    static let across = pictureShort + 2 * (gap + holeAcross + edge)
    static let along = pictureLong + 2 * endMargin
    /// The canvas's width over its height with the strip lying down.
    static let canvasAspect = along / across

    let canvas: CGSize

    /// The strip lies down (a landscape picture) or stands up.
    var isLandscape: Bool {
        canvas.width > canvas.height
    }

    /// Points per unit of the picture's short side.
    var unit: CGFloat {
        isLandscape
            ? min(canvas.height / Self.across, canvas.width / Self.along)
            : min(canvas.width / Self.across, canvas.height / Self.along)
    }

    /// The picture, 3:2 the way the strip lies, centred.
    var picture: CGRect {
        let size = isLandscape
            ? CGSize(width: Self.pictureLong * unit, height: Self.pictureShort * unit)
            : CGSize(width: Self.pictureShort * unit, height: Self.pictureLong * unit)
        return CGRect(centredIn: canvas, size: size)
    }

    /// The film itself, when the canvas is larger than the strip.
    var film: CGRect {
        let size = isLandscape
            ? CGSize(width: Self.along * unit, height: Self.across * unit)
            : CGSize(width: Self.across * unit, height: Self.along * unit)
        return CGRect(centredIn: canvas, size: size)
    }
}

/// The 35mm strip lying down: the film around the picture, perforations along both edges, and the DX code along
/// the bottom edge, which the perforations punch through.
struct FilmStripArt {
    let geometry: FilmStripGeometry

    func draw(in context: inout GraphicsContext) {
        let g = geometry
        let u = g.unit
        let film = g.film
        let picture = g.picture
        // The film, with the picture cut out of it.
        context.fill(Path(film).cuttingOut(picture), with: .color(Color(hex: FilmStripGeometry.filmHex)), style: .evenOdd)
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

import CoreGraphics

/// The canvas a camera puts around its picture when a photo is shown as its finished print or negative:
/// the Instant print's paper, a strip of 35mm film, a cardboard slide mount, or a medium-format rebate.
/// The canvas is the photo's own box; the picture sits in a window inside it, at the film's own ratio.
nonisolated enum LookFrame: Hashable, Sendable, CaseIterable {
    /// White paper with the wide strip at the bottom. Its canvas has the print's own shape (`InstantPrint`).
    case instantPrint
    /// A strip of 35mm film running the long way: the picture at 2:3 between the sprocket holes, edge print outside them.
    case filmStrip
    /// A cardboard slide mount with a 2:3 window, lying on a light table.
    case slideMount
    /// A 6×7 negative: the picture at 4:5 inside a thin black rebate with frame numbers.
    case mediumFormat
    /// A 6×6 negative: the picture square inside a thin black rebate, with the edge print down one side.
    case square

    /// The picture's width over its height, with the canvas upright.
    var pictureRatio: CGFloat {
        switch self {
        case .instantPrint, .square: 1
        case .filmStrip, .slideMount: 2.0 / 3
        case .mediumFormat: 4.0 / 5
        }
    }

    /// The `0xRRGGBB` colour of the canvas under everything.
    var baseHex: UInt32 {
        switch self {
        case .instantPrint: RSColor.printFrameHex
        case .slideMount: SlideMountGeometry.tableHex
        case .filmStrip, .mediumFormat, .square: 0x000000
        }
    }

    /// Where the picture sits inside a canvas of this size, in points. A wider-than-tall canvas gets the
    /// frame turned on its side, so the window turns with it.
    func window(in canvas: CGSize) -> CGRect {
        if self != .instantPrint, canvas.width > canvas.height {
            let upright = uprightWindow(in: CGSize(width: canvas.height, height: canvas.width))
            return CGRect(x: canvas.width - upright.maxY, y: upright.minX, width: upright.height, height: upright.width)
        }
        return uprightWindow(in: canvas)
    }

    private func uprightWindow(in canvas: CGSize) -> CGRect {
        let width = canvas.width
        let height = canvas.height
        switch self {
        case .instantPrint:
            // padding: 5.5% 5.5% 22% 5.5%, every side measured against the width.
            let side = width * InstantPrint.side
            return CGRect(x: side, y: side, width: width - side * 2, height: max(0, height - side - width * InstantPrint.bottom))
        case .filmStrip:
            return FilmStripGeometry(canvas: canvas).picture
        case .slideMount:
            return SlideMountGeometry(canvas: canvas).window
        case .mediumFormat:
            return Self.fitted(ratio: pictureRatio, margin: 0.05 * width, in: canvas)
        case .square:
            return Self.fitted(ratio: 1, margin: 0.035 * width, in: canvas)
        }
    }

    /// The largest picture of this ratio that fits inside the canvas with the margin kept on every side, centred.
    static func fitted(ratio: CGFloat, margin: CGFloat, in canvas: CGSize) -> CGRect {
        let room = CGSize(width: max(1, canvas.width - margin * 2), height: max(1, canvas.height - margin * 2))
        let size = room.width / room.height <= ratio
            ? CGSize(width: room.width, height: room.width / ratio)
            : CGSize(width: room.height * ratio, height: room.height)
        return CGRect(
            x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
            width: size.width, height: size.height
        )
    }
}

/// A strip of 135 film standing upright, measured in its picture's short side (24mm on real film): the film is
/// 35mm wide, a perforation 2.8mm across and 2mm along at a 4.75mm pitch, 0.7mm from the picture, and the edge
/// print lies in the 2mm outside the perforations.
nonisolated struct FilmStripGeometry: Hashable, Sendable {
    let canvas: CGSize

    static let filmHex: UInt32 = 0x141210
    static let printHex: UInt32 = 0xE8892B

    /// The picture's short side in points. The strip is as wide as the canvas unless the picture would not fit.
    var unit: CGFloat {
        min(canvas.width * 24 / 35, canvas.height / 1.5 * 0.96)
    }

    /// The picture, 2:3 and centred.
    var picture: CGRect {
        let size = CGSize(width: unit, height: unit * 1.5)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width, height: size.height)
    }

    /// The film's two edges, when it is narrower than the canvas.
    var film: CGRect {
        let width = unit * 35 / 24
        return CGRect(x: (canvas.width - width) / 2, y: 0, width: width, height: canvas.height)
    }

    var gap: CGFloat { unit * 0.7 / 24 }
    var holeAcross: CGFloat { unit * 2.8 / 24 }
    var holeAlong: CGFloat { unit * 2.0 / 24 }
    var pitch: CGFloat { unit * 4.75 / 24 }
    var holeRadius: CGFloat { unit * 0.45 / 24 }
    /// The edge zone outside the perforations.
    var edge: CGFloat { unit * 2.0 / 24 }
    /// Edge print text size.
    var printSize: CGFloat { unit * 1.15 / 24 }

    /// The perforations down one side: their left edges, for the left side; mirrored for the right.
    var leftHoleX: CGFloat { picture.minX - gap - holeAcross }
    var rightHoleX: CGFloat { picture.maxX + gap }

    /// The perforations' top edges, pitched down the whole strip from a hole centred on the picture's top.
    var holeTops: [CGFloat] {
        var tops: [CGFloat] = []
        var y = picture.minY - holeAlong / 2
        while y > -pitch { y -= pitch }
        while y < canvas.height {
            tops.append(y)
            y += pitch
        }
        return tops
    }
}

/// A square cardboard mount lying on a light table, with a window near the real 23×35mm aperture of a 50mm mount.
nonisolated struct SlideMountGeometry: Hashable, Sendable {
    let canvas: CGSize

    static let tableHex: UInt32 = 0xEDECE8
    static let cardHex: UInt32 = 0xC9C7BF

    var side: CGFloat { min(canvas.width, canvas.height) * 0.9 }

    var mount: CGRect {
        CGRect(x: (canvas.width - side) / 2, y: (canvas.height - side) / 2, width: side, height: side)
    }

    /// The window, upright: 0.46 of the mount wide and 0.69 tall.
    var window: CGRect {
        let size = CGSize(width: side * 0.46, height: side * 0.69)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width, height: size.height)
    }

    var cornerRadius: CGFloat { side * 0.012 }
    var windowRadius: CGFloat { side * 0.02 }
    var dimpleRadius: CGFloat { side * 0.024 }
}

import CoreGraphics

/// The canvas a camera puts around its picture when a photo is shown as its finished print or negative: the
/// Instant print's paper, a strip of 35mm film, a cardboard slide mount, a medium-format rebate, or nothing but
/// the film's own crop. The canvas has the camera's own shape (`canvasAspect`), not the photo's; the picture is
/// the photo's centred crop at the film's ratio, in the canvas's window. Proportions are measured from the
/// reference app's result screens (`docs/camera-lineup.md`, "Frames").
nonisolated enum LookFrame: Hashable, Sendable, CaseIterable {
    /// White paper with the wide strip at the bottom. Its canvas has the print's own shape (`InstantPrint`).
    case instantPrint
    /// A strip of 135 film: the 3:2 picture between the perforations, the edge print and DX code along one edge.
    /// Turns with the photo: a landscape picture lies in a horizontal strip, a portrait one stands in a vertical strip.
    case filmStrip
    /// A square cardboard mount lying on a white light table, its 3:2 window turned the way the picture is.
    case slideMount
    /// A 6×7 negative: the 5:4 picture inside a black rebate with frame numbers along the top and the film's
    /// name along the bottom. Turns with the photo.
    case mediumFormat
    /// A 6×6 negative: the square picture inside a dark rebate with the edge print down the right side.
    case square
    /// A 35mm compact's 3:2 frame with nothing around it: the canvas is the picture.
    case fullFrame

    /// The picture's width over its height with the film the long way round (landscape).
    var pictureRatio: CGFloat {
        switch self {
        case .instantPrint, .square: 1
        case .filmStrip, .slideMount, .fullFrame: 3.0 / 2
        case .mediumFormat: 5.0 / 4
        }
    }

    /// Whether the canvas stands up for a portrait photo and lies down for a landscape one.
    var turnsWithThePhoto: Bool {
        switch self {
        case .filmStrip, .mediumFormat, .fullFrame: true
        case .instantPrint, .slideMount, .square: false
        }
    }

    /// The `0xRRGGBB` colour of the canvas under everything.
    var baseHex: UInt32 {
        switch self {
        case .instantPrint: RSColor.printFrameHex
        case .slideMount: SlideMountGeometry.tableHex
        case .filmStrip: FilmStripGeometry.filmHex
        case .mediumFormat: RebateGeometry.sevenFilmHex
        case .square: RebateGeometry.squareFilmHex
        case .fullFrame: 0x000000
        }
    }

    /// The picture's width over its height for a photo of this shape: the film's ratio the way the photo is.
    func pictureAspect(forPhotoAspect photoAspect: CGFloat) -> CGFloat {
        switch self {
        case .instantPrint, .square: 1
        case .slideMount, .filmStrip, .mediumFormat, .fullFrame:
            photoAspect >= 1 ? pictureRatio : 1 / pictureRatio
        }
    }

    /// The canvas's width over its height for a photo of this shape.
    func canvasAspect(forPhotoAspect photoAspect: CGFloat) -> CGFloat {
        switch self {
        case .instantPrint:
            InstantPrint.size.width / InstantPrint.size.height
        case .slideMount:
            SlideMountGeometry.canvasAspect
        case .square:
            RebateGeometry.squareBands.canvasAspect
        case .fullFrame:
            pictureAspect(forPhotoAspect: photoAspect)
        case .filmStrip:
            photoAspect >= 1 ? FilmStripGeometry.canvasAspect : 1 / FilmStripGeometry.canvasAspect
        case .mediumFormat:
            (photoAspect >= 1 ? RebateGeometry.sevenLandscape : RebateGeometry.sevenPortrait).canvasAspect
        }
    }

    /// Where the picture sits inside a canvas of this size, in points. The canvas is expected at
    /// `canvasAspect`; a canvas of another shape gets the drawing fitted and centred in it.
    /// - Parameter photoAspect: The photo's own shape, which decides which way the slide mount's window turns.
    func window(in canvas: CGSize, photoAspect: CGFloat = 3.0 / 4) -> CGRect {
        switch self {
        case .instantPrint:
            // padding: 5.5% 5.5% 22% 5.5%, every side measured against the width.
            let side = canvas.width * InstantPrint.side
            return CGRect(
                x: side, y: side, width: canvas.width - side * 2,
                height: max(0, canvas.height - side - canvas.width * InstantPrint.bottom)
            )
        case .fullFrame:
            return CGRect(origin: .zero, size: canvas)
        case .filmStrip:
            return FilmStripGeometry(canvas: canvas).picture
        case .slideMount:
            return SlideMountGeometry(canvas: canvas, photoAspect: photoAspect).window
        case .mediumFormat:
            return RebateGeometry.seven(in: canvas).picture
        case .square:
            return RebateGeometry.square(in: canvas).picture
        }
    }
}

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
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width, height: size.height)
    }

    /// The film itself, when the canvas is larger than the strip.
    var film: CGRect {
        let size = isLandscape
            ? CGSize(width: Self.along * unit, height: Self.across * unit)
            : CGSize(width: Self.across * unit, height: Self.along * unit)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width, height: size.height)
    }
}

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

/// A square cardboard mount on a white light table, on a 3:4 canvas: the mount 0.81 of the canvas wide and
/// centred, its 3:2 window centred in it and turned the way the picture is.
nonisolated struct SlideMountGeometry: Hashable, Sendable {
    static let canvasAspect: CGFloat = 3.0 / 4
    static let tableHex: UInt32 = 0xFFFFFF
    static let greyCardHex: UInt32 = 0xBABAAB
    static let creamCardHex: UInt32 = 0xE9E0C9
    static let stripeHex: UInt32 = 0xE9D882
    static let mountFraction: CGFloat = 0.81
    static let windowLong: CGFloat = 0.667
    static let windowShort: CGFloat = 0.447

    let canvas: CGSize
    let photoAspect: CGFloat

    init(canvas: CGSize, photoAspect: CGFloat = 3.0 / 4) {
        self.canvas = canvas
        self.photoAspect = photoAspect
    }

    var isLandscape: Bool {
        photoAspect >= 1
    }

    var side: CGFloat {
        min(canvas.width, canvas.height * Self.canvasAspect) * Self.mountFraction
    }

    var mount: CGRect {
        CGRect(x: (canvas.width - side) / 2, y: (canvas.height - side) / 2, width: side, height: side)
    }

    var window: CGRect {
        let size = isLandscape
            ? CGSize(width: side * Self.windowLong, height: side * Self.windowShort)
            : CGSize(width: side * Self.windowShort, height: side * Self.windowLong)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width, height: size.height)
    }

    var cornerRadius: CGFloat { side * 0.008 }
    var windowRadius: CGFloat { side * 0.012 }
    var dimpleRadius: CGFloat { side * 0.026 }
}

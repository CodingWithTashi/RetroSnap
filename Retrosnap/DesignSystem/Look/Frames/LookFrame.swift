import CoreGraphics

/// The canvas a camera puts around its picture when a photo is shown as its finished print or negative: an
/// instant print on its sheet, a strip of 35mm film, a cardboard slide mount, a medium-format rebate, or nothing
/// but the film's own crop. The canvas has the camera's own shape (`canvasAspect`), not the photo's; the picture
/// is the photo's centred crop at the film's ratio, in the canvas's window. Proportions are measured from the
/// reference app's result screens and exports (`docs/camera-lineup.md`, "Frames").
nonisolated enum LookFrame: Hashable, Sendable {
    /// A mini instant print lying on a white sheet: the 3:4 picture in a white frame with the wide border at
    /// the bottom, the print's corners rounded and its shadow on the sheet. Turns with the photo: a landscape
    /// picture gets the whole sheet turned a quarter anticlockwise, so the wide border is on the right.
    case instantPrint
    /// A square instant print on a white sheet, upright whichever way the photo is: the square picture in a
    /// coloured frame with the wide border at the bottom; the frame's design varies from print to print.
    case squarePrint
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
        case .square, .squarePrint: 1
        case .instantPrint: 4.0 / 3
        case .filmStrip, .slideMount, .fullFrame: 3.0 / 2
        case .mediumFormat: 5.0 / 4
        }
    }

    /// The `0xRRGGBB` colour of the canvas under everything.
    var baseHex: UInt32 {
        switch self {
        case .instantPrint, .squarePrint: MiniPrintGeometry.sheetHex
        case .slideMount: SlideMountGeometry.tableHex
        case .filmStrip: FilmStripGeometry.filmHex
        case .mediumFormat: RebateGeometry.sevenFilmHex
        case .square: RebateGeometry.squareFilmHex
        case .fullFrame: 0x000000
        }
    }

    /// The picture's width over its height for a photo of this shape: the film's ratio the way the photo is.
    func pictureAspect(forPhotoAspect photoAspect: CGFloat) -> CGFloat {
        photoAspect >= 1 ? pictureRatio : 1 / pictureRatio
    }

    /// The canvas's width over its height for a photo of this shape.
    func canvasAspect(forPhotoAspect photoAspect: CGFloat) -> CGFloat {
        switch self {
        case .instantPrint:
            photoAspect >= 1 ? 1 / MiniPrintGeometry.sheetAspect : MiniPrintGeometry.sheetAspect
        case .squarePrint:
            SquarePrintGeometry.canvasAspect
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
    func window(in canvas: CGSize, photoAspect: CGFloat = Photo.cameraAspect) -> CGRect {
        switch self {
        case .instantPrint:
            return MiniPrintGeometry(canvas: canvas).window
        case .squarePrint:
            return SquarePrintGeometry(canvas: canvas).window
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

/// Which of the reference app's cards a photo's canvases get: the square print's and the slide mount's, each by
/// a stable hash of the photo's id.
nonisolated struct FrameDesign: Hashable, Sendable {
    var square: SquarePrintDesign = .lightBlue
    var slide: SlideMountDesign = .greyDimpled

    static func forPhoto(id: String) -> FrameDesign {
        FrameDesign(square: SquarePrintDesign.forPhoto(id: id), slide: SlideMountDesign.forPhoto(id: id))
    }

    /// FNV-1a over the id and a salt, so the two cards vary independently.
    static func hash(_ id: String, salt: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in (id + salt).utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return hash
    }
}

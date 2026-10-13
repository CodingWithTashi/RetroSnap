import CoreGraphics

/// How a photo is laid out when its look is baked into a file: which part of the original is used,
/// how big the finished picture is, and how many pixels make one of the look's points.
nonisolated struct BakeLayout: Hashable, Sendable {
    /// The width the Viewer gives a photo on the design's 390pt screen. Grain, scanlines and stamps are
    /// sized in points, so the file is drawn as that screen shows it.
    static let photoWidth = DesignLayout.referenceSize.width

    /// The part of the original that ends up in the picture, in pixels.
    let crop: CGRect
    /// The finished picture, in pixels.
    let canvas: CGSize
    /// Where the photo sits in the picture, measured from its bottom-left corner as Core Image does.
    let photoOrigin: CGPoint
    /// Pixels per point.
    let scale: CGFloat

    /// The photo's own box in points, as the look measures it.
    var pointSize: CGSize {
        CGSize(width: crop.width / scale, height: crop.height / scale)
    }

    /// The whole picture in points, as a frame's artwork is drawn.
    var canvasPointSize: CGSize {
        CGSize(width: canvas.width / scale, height: canvas.height / scale)
    }

    /// The longest side, in pixels, of a bitmap the artwork is drawn into before Core Image scales it to the
    /// file. A slide mount around a full-resolution photo would otherwise want a bitmap of a hundred
    /// megapixels, which `ImageRenderer` quietly refuses.
    static let artworkPixelLimit: CGFloat = 4096

    /// Pixels per point for rasterising the frame's artwork: the file's scale, or less for a huge canvas.
    var artworkScale: CGFloat {
        min(scale, Self.artworkPixelLimit / max(canvasPointSize.width, canvasPointSize.height))
    }

    /// Pixels per point for rasterising the stamp over the photo, bounded the same way.
    var stampScale: CGFloat {
        min(scale, Self.artworkPixelLimit / max(pointSize.width, pointSize.height))
    }

    /// A print: the photo filling the paper from its centre, inside a border when there is one.
    /// - Parameters:
    ///   - paper: The paper as the Print screen draws it, in points.
    ///   - border: The border's width on that drawing.
    init(source: CGSize, paper: CGSize, border: CGFloat) {
        let window = CGSize(width: paper.width - border * 2, height: paper.height - border * 2)
        crop = Self.centredCrop(of: source, aspect: window.width / window.height)
        let size = crop.size
        scale = size.width / window.width
        let edge = (border * scale).rounded()
        canvas = CGSize(width: size.width + edge * 2, height: size.height + edge * 2)
        photoOrigin = CGPoint(x: edge, y: edge)
    }

    /// The photo on its camera's canvas, or whole when it has none.
    init(source: CGSize, frame: LookFrame?) {
        switch frame {
        case nil:
            crop = CGRect(origin: .zero, size: source)
            canvas = source
            photoOrigin = .zero
            scale = source.width / Self.photoWidth
        case .fullFrame:
            // The film's crop and nothing around it, measured as the Viewer shows it at its full width.
            let aspect = LookFrame.fullFrame.pictureAspect(forPhotoAspect: source.width / source.height)
            crop = Self.centredCrop(of: source, aspect: aspect)
            canvas = crop.size
            photoOrigin = .zero
            scale = crop.width / Self.photoWidth
        case let frame?:
            // The canvas has the camera's own shape at the Viewer's width; the picture keeps every pixel of the
            // original that fits the window, so the canvas is as many pixels as that needs.
            let photoAspect = source.width / source.height
            let canvasPoints = CGSize(width: Self.photoWidth, height: Self.photoWidth / frame.canvasAspect(forPhotoAspect: photoAspect))
            let window = frame.window(in: canvasPoints, photoAspect: photoAspect)
            crop = Self.centredCrop(of: source, aspect: window.width / window.height)
            scale = crop.width / window.width
            canvas = CGSize(width: (canvasPoints.width * scale).rounded(), height: (canvasPoints.height * scale).rounded())
            photoOrigin = CGPoint(x: (window.minX * scale).rounded(), y: (canvas.height - window.maxY * scale).rounded())
        }
    }

    /// The largest part of the picture with this aspect, taken from its centre, on whole pixels.
    private static func centredCrop(of source: CGSize, aspect: CGFloat) -> CGRect {
        let size = source.width / source.height <= aspect
            ? CGSize(width: source.width, height: (source.width / aspect).rounded())
            : CGSize(width: (source.height * aspect).rounded(), height: source.height)
        return CGRect(
            x: ((source.width - size.width) / 2).rounded(), y: ((source.height - size.height) / 2).rounded(),
            width: size.width, height: size.height
        )
    }
}

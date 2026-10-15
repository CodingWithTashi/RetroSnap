import Foundation

/// One step of a CSS `filter` chain. The design's looks (`disp`, `digi`, `vhs`) take their colour from such a chain,
/// transcribed from the design's `LOOKS` table; cameras fitted from reference photos use a `ColorStage` (and a colour
/// table) instead.
nonisolated enum LookFilter: Hashable, Sendable {
    case sepia(Double)
    case saturate(Double)
    case contrast(Double)
    case brightness(Double)
    case hueRotate(degrees: Double)
}

// MARK: -

nonisolated enum LookStamp: Hashable, Sendable {
    case none
    /// The orange VT323 date in the corner, from the design.
    case date
    /// A compact's date back: the date in a yellow dot-matrix with the year, month and day marks, burned into the
    /// lower right of the film's landscape frame (so it runs down the left edge of a portrait picture).
    case dateMatrix
    /// A date back in red seven-segment digits ("10  8 '26": month, day, year), screened into the lower right of
    /// the film's landscape frame; measured from the reference app (`DateBackStyle.segments`).
    case dateSegments
    /// The same date in a red dot matrix (`DateBackStyle.dots`).
    case dateDots
    case vhs

    /// Whether the stamp is screened over the picture (a lamp's light on the film) rather than painted on it.
    var isScreened: Bool {
        switch self {
        case .dateSegments, .dateDots: true
        case .none, .date, .dateMatrix, .vhs: false
        }
    }
}

// MARK: -

/// The hue-dependent part of a measured colour response: around the hue circle, in eight sectors 45° apart
/// starting at red, a hue shift in radians, a saturation gain and a lightness gain, blended smoothly between
/// sectors and faded out on near-neutral colours. What a 3×3 matrix and tone curves cannot express: a film that
/// turns blue skies cyan-grey while greens go yellow.
nonisolated struct HueTerms: Hashable, Sendable {
    static let sectorCount = 8
    static let identity = HueTerms(
        shift: Array(repeating: 0, count: sectorCount),
        saturation: Array(repeating: 1, count: sectorCount),
        lightness: Array(repeating: 1, count: sectorCount)
    )

    let shift: [Double]
    let saturation: [Double]
    let lightness: [Double]

    init(shift: [Double], saturation: [Double], lightness: [Double]) {
        precondition([shift, saturation, lightness].allSatisfy { $0.count == Self.sectorCount }, "eight sectors each")
        self.shift = shift
        self.saturation = saturation
        self.lightness = lightness
    }
}

// MARK: -

/// A measured colour response: a 3×3 matrix with an offset per row, a monotone cubic tone curve per channel
/// through six fixed knots, then the per-hue terms. Fitted to a camera's reference pairs by `tools/fit.py`, which
/// evaluates it exactly as `RetroLook.metal` does, on gamma-encoded sRGB in 0...1.
nonisolated struct ColorStage: Hashable, Sendable {
    /// Where the curves' knots sit; the same for every camera.
    static let knotPositions: [Double] = [0, 0.1, 0.25, 0.45, 0.7, 1]

    /// The red, green and blue rows: three weights and an offset each.
    let matrix: [[Double]]
    /// The red, green and blue curves: the value at each knot.
    let curves: [[Double]]
    /// The per-hue terms; nil leaves every hue as the matrix and curves made it.
    let hue: HueTerms?

    init(matrix: [[Double]], curves: [[Double]], hue: HueTerms? = nil) {
        precondition(matrix.count == 3 && matrix.allSatisfy { $0.count == 4 }, "three rows of four")
        precondition(curves.count == 3 && curves.allSatisfy { $0.count == Self.knotPositions.count }, "three curves of six")
        self.matrix = matrix
        self.curves = curves
        self.hue = hue
    }
}

// MARK: -

/// The glow film throws around its highlights: the bright parts, spread and tinted, screened over the picture.
/// The reference app's is white or a cool white and tight (`tools/halation.py` measures each camera's threshold,
/// spread and amount; the recipes carry them): a bloom that lifts what sits next to a highlight by a few levels, not
/// the red halo of a real colour negative.
nonisolated struct Halation: Hashable, Sendable {
    /// The luminance a pixel must reach to glow.
    let threshold: Double
    /// How far the glow spreads, in points.
    let radius: Double
    /// The glow's strength at a full highlight.
    let amount: Double
    let tintHex: UInt32
}

// MARK: -

/// Film grain: gradient noise the size of a grain clump, added to the picture, strongest a third of the way up
/// the tone scale and fading to a fifth at white, the way the reference app's exports measure by luminance.
nonisolated struct FilmGrain: Hashable, Sendable {
    /// A clump's size in points.
    let size: Double
    /// The amplitude where the grain is strongest (luminance about 0.32), in 0...1 of the channel range.
    let amount: Double
    /// 0 is monochrome grain; 1 is a different pattern in every channel.
    let color: Double
}

// MARK: -

/// A lens going soft toward the corners: a blurred copy shows through, from `inner` to `outer` of the half-diagonal.
nonisolated struct Softness: Hashable, Sendable {
    /// The blur's radius, in points.
    let radius: Double
    let inner: Double
    let outer: Double
    /// How much of the blurred copy shows at the corners.
    let strength: Double
}

// MARK: -

/// A camera's recipe. The three cameras still on the design's looks (`disp`, `digi`, `vhs`) are transcribed from the
/// `LOOKS` table in the design's Photo component; the others are fitted from reference photos
/// (`docs/camera-lineup.md`).
nonisolated struct CameraLook: Hashable, Sendable {
    let filters: [LookFilter]
    let blurRadius: Double
    let tintHex: UInt32
    let tint: Double
    let flash: Double
    let fade: Double
    let chroma: Double
    let scan: Double
    let vignette: Double
    let grain: Double
    let stamp: LookStamp
    /// The measured colour response; when set, `filters` is not used.
    let color: ColorStage?
    /// The colour measured as a 3D lookup table (`Resources/Looks/<name>.cube`); when set and loadable it is drawn
    /// instead of `color`, which stays as the table's prior and the fallback.
    let colorCube: String?
    let halation: Halation?
    let filmGrain: FilmGrain?
    let soft: Softness?
    /// What the camera puts around its picture when a photo is shown framed.
    let frame: LookFrame?

    init(
        filters: [LookFilter] = [], blurRadius: Double = 0, tintHex: UInt32 = 0, tint: Double = 0, flash: Double = 0,
        fade: Double = 0, chroma: Double = 0, scan: Double = 0, vignette: Double = 0, grain: Double = 0,
        stamp: LookStamp = .none, color: ColorStage? = nil, colorCube: String? = nil, halation: Halation? = nil,
        filmGrain: FilmGrain? = nil, soft: Softness? = nil, frame: LookFrame? = nil
    ) {
        self.filters = filters
        self.blurRadius = blurRadius
        self.tintHex = tintHex
        self.tint = tint
        self.flash = flash
        self.fade = fade
        self.chroma = chroma
        self.scan = scan
        self.vignette = vignette
        self.grain = grain
        self.stamp = stamp
        self.color = color
        self.colorCube = colorCube
        self.halation = halation
        self.filmGrain = filmGrain
        self.soft = soft
        self.frame = frame
    }
}

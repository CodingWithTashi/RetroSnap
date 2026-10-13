import Foundation

/// One step of a CSS `filter` chain. The first five cameras' colour comes from such a chain, transcribed from the
/// design's `LOOKS` table; cameras fitted from reference photos use a `ColorStage` instead.
nonisolated enum LookFilter: Hashable, Sendable {
    case sepia(Double)
    case saturate(Double)
    case contrast(Double)
    case brightness(Double)
    case hueRotate(degrees: Double)
}

nonisolated enum LookStamp: Hashable, Sendable {
    case none
    /// The orange VT323 date in the corner, from the design.
    case date
    /// A compact's date back: the date in a yellow dot-matrix with the year, month and day marks, burned into the
    /// lower right of the film's landscape frame (so it runs down the left edge of a portrait picture).
    case dateMatrix
    case vhs
}

/// The hue-dependent part of a measured colour response: around the hue circle, in eight sectors 45° apart
/// starting at red, a hue shift in radians, a saturation gain and a lightness gain, blended smoothly between
/// sectors and faded out on near-neutral colours. What a 3×3 matrix and tone curves cannot express: a film that
/// turns blue skies cyan-grey while greens go yellow.
nonisolated struct HueTerms: Hashable, Sendable {
    static let sectorCount = 8
    /// Where the sectors sit, in degrees of the hue angle; the same for every camera.
    static let sectorCentres: [Double] = (0..<sectorCount).map { Double($0) * 45 }
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

/// The glow film throws around its highlights: the bright parts, spread and tinted, screened over the picture.
/// The reference app's is white and tight (`tools/halation.py`): a bloom a couple of points wide that lifts what
/// sits next to a highlight by a few levels, not the red halo of a real colour negative.
nonisolated struct Halation: Hashable, Sendable {
    /// The luminance a pixel must reach to glow.
    let threshold: Double
    /// How far the glow spreads, in points.
    let radius: Double
    /// The glow's strength at a full highlight.
    let amount: Double
    let tintHex: UInt32
}

/// Film grain: gradient noise the size of a grain clump, strongest in the midtones, added to the picture.
nonisolated struct FilmGrain: Hashable, Sendable {
    /// A clump's size in points.
    let size: Double
    /// The amplitude at mid grey, in 0...1 of the channel range.
    let amount: Double
    /// 0 is monochrome grain; 1 is a different pattern in every channel.
    let color: Double
}

/// A lens going soft toward the corners: a blurred copy shows through, from `inner` to `outer` of the half-diagonal.
nonisolated struct Softness: Hashable, Sendable {
    /// The blur's radius, in points.
    let radius: Double
    let inner: Double
    let outer: Double
    /// How much of the blurred copy shows at the corners.
    let strength: Double
}

/// A camera's recipe. The first five cameras were transcribed from the `LOOKS` table in the design's Photo
/// component; the cameras after them are fitted from reference photos (`docs/camera-lineup.md`).
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

extension CameraStyle {
    nonisolated var look: CameraLook {
        switch self {
        case .film:
            CameraLook(
                filters: [.sepia(0.34), .saturate(1.3), .contrast(1.06), .brightness(1.03), .hueRotate(degrees: -8)],
                blurRadius: 0, tintHex: 0xFF9A2E, tint: 0.2, flash: 0, fade: 0, chroma: 0, scan: 0,
                vignette: 0.6, grain: 0.26, stamp: .date
            )
        case .disposable:
            CameraLook(
                filters: [.contrast(1.22), .saturate(1.35), .sepia(0.16), .brightness(1.13)],
                blurRadius: 0, tintHex: 0xFFCF5A, tint: 0.18, flash: 0.7, fade: 0, chroma: 0, scan: 0,
                vignette: 0.4, grain: 0.42, stamp: .date
            )
        case .instant:
            CameraLook(
                filters: [.contrast(0.8), .saturate(0.74), .sepia(0.22), .brightness(1.12)],
                blurRadius: 0, tintHex: 0xFFB9A0, tint: 0.22, flash: 0, fade: 0.16, chroma: 0, scan: 0,
                vignette: 0.22, grain: 0.14, stamp: .none, frame: .instantPrint
            )
        case .digicam:
            CameraLook(
                filters: [.contrast(1.16), .saturate(0.86), .brightness(1.06)],
                blurRadius: 0, tintHex: 0x3D7DFF, tint: 0.28, flash: 0.15, fade: 0, chroma: 0, scan: 0,
                vignette: 0.08, grain: 0.08, stamp: .date
            )
        case .camcorder:
            CameraLook(
                filters: [.saturate(1.5), .contrast(0.9), .brightness(1.06)],
                blurRadius: 0.6, tintHex: 0x20D0C0, tint: 0.14, flash: 0, fade: 0.05, chroma: 0.5, scan: 0.4,
                vignette: 0.32, grain: 0.22, stamp: .vhs
            )

        // Batch 1: fitted from the reference pairs in `ref/pairs`, in sRGB (the first fits read the pictures'
        // Display P3 values as sRGB, which dulled every saturated colour on a phone). In brackets: the median
        // ΔE2000 of the fit on each picture, over 4×4 boxes; with texture averaged out (a 16 px blur) the colour
        // mapping itself is 1.2 to 2.7 on every picture. Halation is fitted by `tools/halation.py` on the same
        // pairs (white, tight, threshold 0.6); grain by `tools/grain.py` (amplitude and how coloured it is).

        case .negative:
            // 135 NE (3.4 and 3.6 on its two pictures, fit --reg 1 on both, the dunes weighted 3×): warm colour negative, lifted
            // blacks, yellow-green highlights, a soft white bloom. The reference turns a blue sky cyan-grey and greens
            // yellow; the per-hue terms take some of that, the rest is beyond a smooth per-pixel mapping.
            CameraLook(
                vignette: 0.510,
                color: ColorStage(
                    matrix: [[1.0745, -0.1522, 0.0685, -0.0188], [0.2048, 0.6893, 0.0608, 0.0171], [0.1437, -0.1883, 1.0919, 0.0116]],
                    curves: [[0.0537, 0.0831, 0.2509, 0.4813, 0.7868, 0.9988], [0.0433, 0.0851, 0.2379, 0.4468, 0.7200, 0.9395],
                             [0.0481, 0.0773, 0.2021, 0.4096, 0.6546, 0.8506]],
                    hue: HueTerms(
                        shift: [0.0274, 0.0137, 0.0135, 0.0172, 0.0176, 0.0323, 0.0403, 0.0630],
                        saturation: [1.0039, 1.0115, 1.0309, 1.0102, 0.9945, 0.9657, 0.9565, 0.9910],
                        lightness: [0.9785, 0.9831, 0.9708, 0.9903, 0.9901, 0.9788, 0.9556, 0.9814]
                    )
                ),
                colorCube: "negative",
                halation: Halation(threshold: 0.6, radius: 2, amount: 0.4, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.065, color: 0.15),
                frame: .filmStrip
            )
        case .plastic35:
            // CPM35 (2.4 and 2.3 on its two pictures, fit --reg 3 on both): low contrast and hazy, a cool
            // green-grey cast. Its export keeps 0.92 of the input's fine detail in the middle and 0.90 at the
            // corners (`tools/grain.py`, second picture), so the lens is sharp and no softer at the corners: the
            // haze is all in the tone curve. The reference crops to 3:2 with nothing around it and burns the date
            // into the lower right of the film's frame as a date back does.
            CameraLook(
                vignette: 0.225, stamp: .dateMatrix,
                color: ColorStage(
                    matrix: [[0.9803, 0.0327, 0.0629, -0.0354], [0.0119, 0.9257, 0.1318, -0.0205], [-0.0463, -0.0475, 1.0282, 0.0591]],
                    curves: [[0.1170, 0.1625, 0.2858, 0.4622, 0.7214, 0.9571], [0.1666, 0.2163, 0.3309, 0.4973, 0.7460, 0.9587],
                             [0.1474, 0.1769, 0.2755, 0.4705, 0.7571, 0.9892]],
                    hue: HueTerms(
                        shift: [0.0008, -0.0175, -0.0532, -0.1143, -0.0350, 0.0247, 0.0342, 0.0402],
                        saturation: [1.0008, 1.0017, 1.0044, 0.9887, 0.9756, 1.0111, 0.9753, 1.0251],
                        lightness: [1.0056, 1.0021, 1.0006, 1.0067, 1.0165, 1.0009, 0.9374, 1.0012]
                    )
                ),
                colorCube: "plastic35",
                halation: Halation(threshold: 0.6, radius: 2.5, amount: 0.25, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.45, amount: 0.075, color: 0.15),
                frame: .fullFrame
            )
        case .slide:
            // D Slide (3.5 and 2.5 on its two pictures, fit --reg 3 on both, the selfie weighted 2×): slide film, warm and rich with
            // deep shadows, in a cardboard mount on a white light table.
            CameraLook(
                vignette: 0.271,
                color: ColorStage(
                    matrix: [[1.0012, 0.0540, 0.1091, -0.0391], [0.0732, 0.8993, 0.1737, -0.0295], [-0.0132, 0.1219, 0.9932, 0.0176]],
                    curves: [[0.0707, 0.1033, 0.2215, 0.4019, 0.6671, 0.8704], [0.0650, 0.1000, 0.2123, 0.3992, 0.6936, 0.9107],
                             [0.0297, 0.0784, 0.1609, 0.3470, 0.6783, 0.8795]],
                    hue: HueTerms(
                        shift: [-0.0468, -0.0200, -0.0132, -0.0213, -0.0096, -0.0252, -0.0421, -0.0072],
                        saturation: [0.9605, 0.9763, 0.9682, 0.9337, 0.9100, 0.8607, 0.7268, 0.9440],
                        lightness: [1.0354, 1.0167, 1.0149, 1.0293, 1.0495, 1.0294, 1.0542, 1.0684]
                    )
                ),
                colorCube: "slide",
                halation: Halation(threshold: 0.4, radius: 2.5, amount: 0.15, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.9, amount: 0.036, color: 0.2),
                frame: .slideMount
            )
        case .mediumFormat:
            // S 67 (2.6 and 2.9 on its two pictures, fit --reg 3 on both): 6×7 colour negative, warm skin,
            // deep blacks, fine grain, in a black rebate with the frame numbers and the film's name.
            CameraLook(
                vignette: 0.312,
                color: ColorStage(
                    matrix: [[1.0073, -0.1414, 0.0247, 0.0412], [0.0514, 0.9195, 0.0937, -0.0335], [-0.0081, 0.1320, 0.9694, -0.0343]],
                    curves: [[-0.0028, 0.0470, 0.2043, 0.4323, 0.7036, 0.8946], [0.0356, 0.1072, 0.2450, 0.4215, 0.6348, 0.8398],
                             [0.0377, 0.1141, 0.2365, 0.4381, 0.6574, 0.8286]],
                    hue: HueTerms(
                        shift: [-0.1112, -0.0516, -0.0443, -0.0341, -0.0133, -0.0161, -0.0063, -0.0351],
                        saturation: [1.0808, 1.0251, 0.9956, 0.9467, 0.9621, 0.9369, 0.8801, 1.0630],
                        lightness: [1.0094, 1.0116, 1.0235, 1.0547, 1.0181, 0.9981, 0.9623, 1.0236]
                    )
                ),
                colorCube: "mediumFormat",
                halation: Halation(threshold: 0.6, radius: 2.5, amount: 0.4, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.7, amount: 0.04, color: 0.25),
                frame: .mediumFormat
            )
        case .tlr:
            // S Classic (1.9 and 2.6 on its two pictures, fit --reg 3 on both): 6×6 colour negative, warm
            // and natural, the finest grain of the five, in a dark rebate with the edge print down the right.
            CameraLook(
                vignette: 0.371,
                color: ColorStage(
                    matrix: [[1.0109, -0.0644, -0.0439, 0.0044], [0.0459, 0.9635, 0.0061, 0.0061], [-0.0337, -0.0810, 1.0390, 0.0330]],
                    curves: [[0.0497, 0.0604, 0.2034, 0.4357, 0.7524, 1.0275], [0.0459, 0.0700, 0.2002, 0.3730, 0.6228, 0.8706],
                             [0.0495, 0.0582, 0.1792, 0.3885, 0.6457, 0.8663]],
                    hue: HueTerms(
                        shift: [0.0223, 0.0085, 0.0034, 0.0106, 0.0179, 0.0096, 0.0266, 0.0306],
                        saturation: [1.0287, 1.0188, 1.0281, 1.0397, 1.0255, 1.0227, 1.0427, 1.0746],
                        lightness: [1.0113, 0.9951, 0.9730, 0.9546, 0.9790, 0.9828, 0.9757, 1.0262]
                    )
                ),
                colorCube: "tlr",
                halation: Halation(threshold: 0.6, radius: 2, amount: 0.25, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.037, color: 0.2),
                frame: .square
            )
        }
    }
}

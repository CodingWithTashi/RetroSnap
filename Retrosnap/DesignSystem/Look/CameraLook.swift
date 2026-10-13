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
    case date
    case vhs
}

/// A measured colour response: a 3×3 matrix with an offset per row, then a monotone cubic tone curve per channel
/// through six fixed knots. Fitted to a reference pair by `tools/fit.py`, which evaluates it exactly as
/// `RetroLook.metal` does, on gamma-encoded sRGB in 0...1.
nonisolated struct ColorStage: Hashable, Sendable {
    /// Where the curves' knots sit; the same for every camera.
    static let knotPositions: [Double] = [0, 0.1, 0.25, 0.45, 0.7, 1]

    /// The red, green and blue rows: three weights and an offset each.
    let matrix: [[Double]]
    /// The red, green and blue curves: the value at each knot.
    let curves: [[Double]]

    init(matrix: [[Double]], curves: [[Double]]) {
        precondition(matrix.count == 3 && matrix.allSatisfy { $0.count == 4 }, "three rows of four")
        precondition(curves.count == 3 && curves.allSatisfy { $0.count == Self.knotPositions.count }, "three curves of six")
        self.matrix = matrix
        self.curves = curves
    }
}

/// The red glow film throws around its highlights: the bright parts, spread and tinted, screened over the picture.
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
    let halation: Halation?
    let filmGrain: FilmGrain?
    let soft: Softness?
    /// What the camera puts around its picture when a photo is shown framed.
    let frame: LookFrame?

    init(
        filters: [LookFilter] = [], blurRadius: Double = 0, tintHex: UInt32 = 0, tint: Double = 0, flash: Double = 0,
        fade: Double = 0, chroma: Double = 0, scan: Double = 0, vignette: Double = 0, grain: Double = 0,
        stamp: LookStamp = .none, color: ColorStage? = nil, halation: Halation? = nil, filmGrain: FilmGrain? = nil,
        soft: Softness? = nil, frame: LookFrame? = nil
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

        // Batch 1: fitted from the reference pairs in `ref/pairs` (median ΔE2000 of the fit on each picture in brackets).

        case .negative:
            // 135 NE (3.4 and 3.5 on its two pictures, fit --reg 1 on both, the second weighted 5×): warm colour
            // negative, lifted blacks, yellow-green highlights, a soft red glow. The reference turns a blue sky cyan-grey
            // and greens yellow, a hue-dependent shift the matrix and curves can only approximate, so it sits just over
            // the 3.0 line on both pictures; the fit kept is the one with the smallest worse median.
            CameraLook(
                vignette: 0.516,
                color: ColorStage(
                    matrix: [[1.0868, -0.2430, 0.0753, -0.0158], [0.2227, 0.6902, 0.1395, -0.0720], [0.1568, -0.3032, 0.8094, 0.0335]],
                    curves: [[0.0511, 0.0858, 0.2626, 0.5067, 0.8256, 0.9885], [0.0599, 0.1559, 0.2929, 0.4840, 0.7277, 0.9349],
                             [0.0235, 0.0846, 0.3072, 0.6292, 0.9410, 1.8334]]
                ),
                halation: Halation(threshold: 0.8, radius: 7, amount: 0.15, tintHex: 0xFF7A3A),
                filmGrain: FilmGrain(size: 0.8, amount: 0.085, color: 0.35),
                frame: .filmStrip
            )
        case .plastic35:
            // CPM35 (2.4 and 2.3 on its two pictures, fit --reg 3 on both): low contrast and hazy, a cool green-grey
            // cast. Its export keeps 0.92 of the input's fine detail in the middle and 0.90 at the corners
            // (`tools/grain.py`, second picture; even a 0.08pt blur left only 0.75), so the lens is sharp and
            // no softer at the corners: the haze is all in the tone curve.
            CameraLook(
                vignette: 0.235, stamp: .date,
                color: ColorStage(
                    matrix: [[0.9798, -0.0482, 0.1149, -0.0218], [-0.0448, 0.9137, 0.1968, -0.0118], [-0.0157, -0.1904, 0.9189, -0.0206]],
                    curves: [[0.1109, 0.1589, 0.2811, 0.4632, 0.7255, 0.9750], [0.1489, 0.2033, 0.3215, 0.4866, 0.7331, 0.9662],
                             [0.1556, 0.2463, 0.4297, 0.7298, 0.9979, 1.1103]]
                ),
                halation: Halation(threshold: 0.75, radius: 10, amount: 0.1, tintHex: 0xFFE2C8),
                filmGrain: FilmGrain(size: 0.45, amount: 0.09, color: 0.15)
            )
        case .slide:
            // D Slide (2.9 and 2.4 on its two pictures, fit --reg 3 on both): slide film, warm and rich with deep
            // shadows, in a cardboard mount.
            CameraLook(
                vignette: 0.240,
                color: ColorStage(
                    matrix: [[1.0126, -0.0271, 0.1376, 0.0203], [0.1733, 0.8130, 0.1883, -0.0281], [0.0361, 0.2089, 0.8721, 0.0272]],
                    curves: [[0.0367, 0.0762, 0.1918, 0.3776, 0.6473, 0.8848], [0.0480, 0.1005, 0.2265, 0.4058, 0.6872, 0.9176],
                             [0.0284, 0.0577, 0.1839, 0.3479, 0.6665, 0.8921]]
                ),
                filmGrain: FilmGrain(size: 0.9, amount: 0.032, color: 0.2),
                frame: .slideMount
            )
        case .mediumFormat:
            // S 67 (2.8 and 2.8 on its two pictures, fit --reg 3 on both, the second weighted 2×): 6×7 colour
            // negative, warm skin, deep blacks, fine grain.
            CameraLook(
                vignette: 0.306,
                color: ColorStage(
                    matrix: [[0.9845, -0.1998, 0.0711, 0.0465], [0.0598, 0.8685, 0.1581, -0.0472], [-0.0516, 0.0745, 1.0084, 0.0305]],
                    curves: [[0.0014, 0.0467, 0.2039, 0.4436, 0.7327, 0.9036], [0.0397, 0.1165, 0.2534, 0.4253, 0.6497, 0.8456],
                             [0.0057, 0.0670, 0.1898, 0.3942, 0.6531, 0.8389]]
                ),
                halation: Halation(threshold: 0.85, radius: 8, amount: 0.15, tintHex: 0xFF8A50),
                filmGrain: FilmGrain(size: 0.7, amount: 0.04, color: 0.25),
                frame: .mediumFormat
            )
        case .tlr:
            // S Classic (2.0 and 2.8 on its two pictures, fit --reg 3 on both): 6×6 colour negative, warm and
            // natural, the finest grain of the five.
            CameraLook(
                vignette: 0.382,
                color: ColorStage(
                    matrix: [[1.0048, -0.1358, -0.0865, 0.0225], [0.0844, 0.9511, -0.0230, -0.0002], [0.0698, -0.2360, 0.8789, 0.0047]],
                    curves: [[0.0423, 0.0544, 0.2139, 0.4886, 0.8371, 1.0629], [0.0337, 0.0693, 0.2007, 0.3791, 0.6285, 0.8826],
                             [0.0194, 0.0838, 0.2802, 0.5654, 0.8452, 1.2998]]
                ),
                halation: Halation(threshold: 0.85, radius: 8, amount: 0.14, tintHex: 0xFF8A50),
                filmGrain: FilmGrain(size: 0.8, amount: 0.037, color: 0.2),
                frame: .square
            )
        }
    }
}

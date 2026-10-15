import Foundation

/// Everything `PhotoLookView` and `LookRenderer` need to draw one photo, derived from the camera's look and the edit sliders.
/// Mirrors `renderVals()` in the design's Photo component.
nonisolated struct LookRenderModel: Hashable, Sendable {
    let filters: [LookFilter]
    let blurRadius: Double
    let lookOpacity: Double
    let tintHex: UInt32
    let tintOpacity: Double
    let flashOpacity: Double
    let fadeOpacity: Double
    let chromaOpacity: Double
    let scanOpacity: Double
    let vignetteOpacity: Double
    let grainOpacity: Double
    let warmHex: UInt32
    let warmOpacity: Double
    let brightness: Double
    let contrast: Double
    let stamp: LookStamp
    /// The measured colour response, drawn instead of `filters` when the camera has one.
    let color: ColorStage?
    /// The colour table drawn instead of `color` when the camera ships one.
    let colorCube: String?
    /// Drawn inside the looked copy, so they fade with the effect like the colour does.
    let halation: Halation?
    let soft: Softness?
    /// Its amount already follows the Grain slider and the effect strength.
    let filmGrain: FilmGrain?
    /// The canvas around the picture, when the photo is shown framed and the camera has one.
    let frame: LookFrame?

    /// The effect strength a stamp needs to be drawn.
    static let stampMinimumStrength = 0.3
    /// The Warmth slider's washes: orange for warmer, blue for cooler.
    static let warmerHex: UInt32 = 0xFF8A00
    static let coolerHex: UInt32 = 0x2F6BFF

    init(camera: CameraStyle, adjustments: PhotoAdjustments, framed: Bool, stampEnabled: Bool) {
        let look = camera.look
        let strength = Double(adjustments.intensity) / 100
        let grainScale = Double(adjustments.grain) / 50
        /// An amount scaled by the Grain slider and faded with the effect.
        func grained(_ amount: Double) -> Double { amount * grainScale * (0.4 + 0.6 * strength) }

        filters = look.filters
        blurRadius = look.blurRadius
        lookOpacity = strength
        tintHex = look.tintHex
        tintOpacity = look.tint * strength
        flashOpacity = look.flash * strength
        fadeOpacity = look.fade * strength
        chromaOpacity = look.chroma * strength
        scanOpacity = look.scan * strength
        vignetteOpacity = look.vignette * strength
        grainOpacity = min(1, grained(look.grain))
        warmHex = adjustments.warmth >= 0 ? Self.warmerHex : Self.coolerHex
        warmOpacity = Double(abs(adjustments.warmth)) / 100
        brightness = 1 + Double(adjustments.exposure) / 100
        contrast = 1 + Double(adjustments.contrast) / 100
        stamp = stampEnabled && strength > Self.stampMinimumStrength ? look.stamp : .none
        color = look.color
        colorCube = look.colorCube
        halation = look.halation
        soft = look.soft
        filmGrain = look.filmGrain.map { grain in
            FilmGrain(size: grain.size, amount: min(1, grained(grain.amount)), color: grain.color)
        }
        frame = framed ? look.frame : nil
    }

    /// The photo is shown on its canvas: the Instant print's paper, or a film camera's strip, mount or rebate.
    var isFramed: Bool {
        frame != nil
    }

    /// The colour under a baked picture wherever its layout leaves a margin: the frame's canvas, or the print frame's paper for a photo shown whole.
    var paperHex: UInt32 {
        frame?.baseHex ?? RSColor.printFrameHex
    }

    /// Light and contrast run as a second pass over the finished photo, only when they are set.
    var needsAdjustmentPass: Bool {
        brightness != 1 || contrast != 1
    }
}

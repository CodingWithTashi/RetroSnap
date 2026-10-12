import Testing
@testable import Retrosnap

@MainActor
struct LookRenderModelTests {

    private func model(
        _ camera: CameraStyle,
        _ adjustments: PhotoAdjustments = .neutral,
        framed: Bool = false,
        stamp: Bool = true
    ) -> LookRenderModel {
        LookRenderModel(camera: camera, adjustments: adjustments, framed: framed, stampEnabled: stamp)
    }

    @Test func filmAtFullEffectUsesTheTableValues() {
        let m = model(.film)
        #expect(isClose(m.lookOpacity, 1))
        #expect(isClose(m.tintOpacity, 0.2))
        #expect(isClose(m.flashOpacity, 0))
        #expect(isClose(m.fadeOpacity, 0))
        #expect(isClose(m.chromaOpacity, 0))
        #expect(isClose(m.scanOpacity, 0))
        #expect(isClose(m.vignetteOpacity, 0.6))
        #expect(isClose(m.grainOpacity, 0.26))
        #expect(isClose(m.brightness, 1))
        #expect(isClose(m.contrast, 1))
        #expect(isClose(m.warmOpacity, 0))
        #expect(m.stamp == .date)
    }

    @Test func camcorderCarriesChromaScanlinesAndBlur() {
        let m = model(.camcorder)
        #expect(isClose(m.chromaOpacity, 0.5))
        #expect(isClose(m.scanOpacity, 0.4))
        #expect(isClose(m.fadeOpacity, 0.05))
        #expect(isClose(m.blurRadius, 0.6))
        #expect(m.stamp == .vhs)
    }

    @Test func effectStrengthScalesEveryLookLayer() {
        var adjustments = PhotoAdjustments.neutral
        adjustments.intensity = 50
        let m = model(.disposable, adjustments)
        #expect(isClose(m.lookOpacity, 0.5))
        #expect(isClose(m.tintOpacity, 0.09))
        #expect(isClose(m.flashOpacity, 0.35))
        #expect(isClose(m.vignetteOpacity, 0.2))
    }

    @Test func grainFollowsTheSliderAndFadesWithTheEffect() {
        var heavy = PhotoAdjustments.neutral
        heavy.grain = 100
        #expect(isClose(model(.film, heavy).grainOpacity, 0.52))

        var none = PhotoAdjustments.neutral
        none.grain = 0
        #expect(isClose(model(.film, none).grainOpacity, 0))

        var faded = PhotoAdjustments.neutral
        faded.intensity = 0
        #expect(isClose(model(.film, faded).grainOpacity, 0.26 * 0.4))
    }

    @Test func grainOpacityNeverExceedsOne() {
        var adjustments = PhotoAdjustments.neutral
        adjustments.grain = 100
        // Disposable: 0.42 * 2 = 0.84, still below the cap; the cap guards future looks.
        #expect(model(.disposable, adjustments).grainOpacity <= 1)
    }

    @Test func lightAndContrastBecomeMultipliers() {
        var adjustments = PhotoAdjustments.neutral
        adjustments.exposure = 10
        adjustments.contrast = -20
        let m = model(.film, adjustments)
        #expect(isClose(m.brightness, 1.1))
        #expect(isClose(m.contrast, 0.8))
        #expect(m.needsAdjustmentPass)
        #expect(!model(.film).needsAdjustmentPass)
    }

    @Test func warmthPicksOrangeOrBlue() {
        var warm = PhotoAdjustments.neutral
        warm.warmth = 18
        #expect(model(.film, warm).warmHex == 0xFF8A00)
        #expect(isClose(model(.film, warm).warmOpacity, 0.18))

        var cool = PhotoAdjustments.neutral
        cool.warmth = -20
        #expect(model(.film, cool).warmHex == 0x2F6BFF)
        #expect(isClose(model(.film, cool).warmOpacity, 0.2))
    }

    @Test(arguments: [
        (CameraStyle.film, LookStamp.date),
        (.disposable, .date),
        (.instant, .none),
        (.digicam, .date),
        (.camcorder, .vhs),
    ])
    func stampKindPerCamera(camera: CameraStyle, expected: LookStamp) {
        #expect(model(camera).stamp == expected)
    }

    @Test func stampIsHiddenWhenNotRequested() {
        #expect(model(.film, stamp: false).stamp == .none)
    }

    @Test func stampDisappearsOnceTheEffectIsMostlyOff() {
        var adjustments = PhotoAdjustments.neutral
        adjustments.intensity = 30
        #expect(model(.film, adjustments).stamp == .none)
        adjustments.intensity = 31
        #expect(model(.film, adjustments).stamp == .date)
    }

    @Test func onlyInstantGetsTheWhiteFrame() {
        #expect(model(.instant, framed: true).isFramed)
        #expect(!model(.instant, framed: false).isFramed)
        #expect(!model(.film, framed: true).isFramed)
    }

    @Test func originalComparisonShowsThePlainPhoto() {
        let m = model(.film, .original)
        #expect(isClose(m.lookOpacity, 0))
        #expect(isClose(m.grainOpacity, 0))
        #expect(isClose(m.tintOpacity, 0))
        #expect(m.stamp == .none)
    }
}

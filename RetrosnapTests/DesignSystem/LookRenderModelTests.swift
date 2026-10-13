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

    @Test func theDisposableAtFullEffectUsesTheTableValues() {
        let m = model(.disposable)
        #expect(isClose(m.lookOpacity, 1))
        #expect(isClose(m.tintOpacity, 0.18))
        #expect(isClose(m.flashOpacity, 0.7))
        #expect(isClose(m.fadeOpacity, 0))
        #expect(isClose(m.chromaOpacity, 0))
        #expect(isClose(m.scanOpacity, 0))
        #expect(isClose(m.vignetteOpacity, 0.4))
        #expect(isClose(m.grainOpacity, 0.42))
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
        #expect(isClose(model(.disposable, heavy).grainOpacity, 0.84))

        var none = PhotoAdjustments.neutral
        none.grain = 0
        #expect(isClose(model(.disposable, none).grainOpacity, 0))

        var faded = PhotoAdjustments.neutral
        faded.intensity = 0
        #expect(isClose(model(.disposable, faded).grainOpacity, 0.42 * 0.4))
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
        (CameraStyle.film, LookStamp.dateSegments),
        (.disposable, .date),
        (.instant, .none),
        (.digicam, .date),
        (.camcorder, .vhs),
        (.negative, .none),
        (.plastic35, .dateMatrix),
        (.slide, .none),
        (.mediumFormat, .none),
        (.tlr, .none),
        (.compactPro, .dateSegments),
        (.classicSLR, .dateDots),
        (.instSquare, .none),
    ])
    func stampKindPerCamera(camera: CameraStyle, expected: LookStamp) {
        #expect(model(camera).stamp == expected)
    }

    @Test func stampIsHiddenWhenNotRequested() {
        #expect(model(.film, stamp: false).stamp == .none)
    }

    @Test func theDateBacksAreScreenedAndTheOthersPainted() {
        #expect(LookStamp.dateSegments.isScreened)
        #expect(LookStamp.dateDots.isScreened)
        #expect(!LookStamp.dateMatrix.isScreened)
        #expect(!LookStamp.date.isScreened)
        #expect(!LookStamp.vhs.isScreened)
        #expect(!LookStamp.none.isScreened)
    }

    @Test func stampDisappearsOnceTheEffectIsMostlyOff() {
        var adjustments = PhotoAdjustments.neutral
        adjustments.intensity = 30
        #expect(model(.film, adjustments).stamp == .none)
        adjustments.intensity = 31
        #expect(model(.film, adjustments).stamp == .dateSegments)
    }

    @Test(arguments: [
        (CameraStyle.instant, LookFrame?.some(.instantPrint)),
        (.negative, .filmStrip),
        (.slide, .slideMount),
        (.mediumFormat, .mediumFormat),
        (.tlr, .square),
        (.disposable, nil),
        (.digicam, nil),
        (.plastic35, .fullFrame),
        (.film, .fullFrame),
        (.compactPro, .fullFrame),
        (.classicSLR, .fullFrame),
        (.instSquare, .squarePrint),
    ])
    func framedCamerasGetTheirFrame(camera: CameraStyle, frame: LookFrame?) {
        #expect(model(camera, framed: true).frame == frame)
        #expect(model(camera, framed: true).isFramed == (frame != nil))
        #expect(model(camera, framed: false).frame == nil)
        #expect(!model(camera, framed: false).isFramed)
    }

    // MARK: Fitted cameras

    @Test func aFittedCameraDrawsItsColourStageInsteadOfAFilterChain() {
        let m = model(.negative)
        #expect(m.filters.isEmpty)
        #expect(m.color?.matrix.count == 3)
        #expect(m.color?.curves.count == 3)
        #expect(m.colorCube == "negative")
        #expect(isClose(m.color?.matrix[0][0] ?? 0, 1.0745))
        #expect(isClose(m.vignetteOpacity, 0.510))
        #expect(isClose(m.grainOpacity, 0))
        #expect(isClose(m.tintOpacity, 0))
        #expect(m.halation?.radius == 2)
        #expect(m.halation?.tintHex == 0xFFFFFF)
        #expect(m.soft == nil)
        #expect(model(.disposable).color == nil)
    }

    @Test func filmGrainFollowsTheSliderAndFadesWithTheEffect() {
        #expect(isClose(model(.negative).filmGrain?.amount ?? 0, 0.065))
        #expect(isClose(model(.negative).filmGrain?.size ?? 0, 0.8))

        var heavy = PhotoAdjustments.neutral
        heavy.grain = 100
        #expect(isClose(model(.negative, heavy).filmGrain?.amount ?? 0, 0.13))

        var none = PhotoAdjustments.neutral
        none.grain = 0
        #expect(isClose(model(.negative, none).filmGrain?.amount ?? 0, 0))

        var faded = PhotoAdjustments.neutral
        faded.intensity = 0
        #expect(isClose(model(.negative, faded).filmGrain?.amount ?? 0, 0.065 * 0.4))
        #expect(model(.disposable).filmGrain == nil)
    }

    @Test func thePlasticCompactIsSharpWithNoSoftCorners() {
        // Its reference export keeps 0.92 of the input's fine detail in the middle and 0.90 at the corners
        // (`tools/grain.py` on the second picture), so the lens neither blurs nor falls off at the corners.
        let m = model(.plastic35)
        #expect(isClose(m.blurRadius, 0))
        #expect(m.soft == nil)
        #expect(m.halation != nil)
        #expect(m.stamp == .dateMatrix)
    }

    @Test func originalComparisonShowsThePlainPhoto() {
        let m = model(.film, .original)
        #expect(isClose(m.lookOpacity, 0))
        #expect(isClose(m.grainOpacity, 0))
        #expect(isClose(m.tintOpacity, 0))
        #expect(m.stamp == .none)
    }
}

import CoreImage
import Testing
@testable import Retrosnap

/// The look as Core Image draws it for files. Expected colours are worked by hand from the W3C filter
/// and blend formulas the design uses, on a flat picture so that only the maths is under test.
@MainActor
struct LookRendererTests {
    private let renderer: LookRenderer
    /// 30 x 40 points at one pixel per point, in the fixtures' orange.
    private let orange = CIImage.flat(red: 200.0 / 255, green: 120.0 / 255, blue: 40.0 / 255, width: 30, height: 40)

    init() throws {
        renderer = try LookRenderer()
    }

    private func model(_ camera: CameraStyle, _ adjustments: PhotoAdjustments) -> LookRenderModel {
        LookRenderModel(camera: camera, adjustments: adjustments, framed: false, stampEnabled: false)
    }

    private func centre(_ image: CIImage) -> Pixel {
        renderer.context.pixel(of: image, x: Int(image.extent.width) / 2, y: Int(image.extent.height) / 2)
    }

    @Test(arguments: CameraStyle.allCases)
    func theOriginalComesThroughUntouched(camera: CameraStyle) {
        let image = renderer.render(orange, model: model(camera, .original), scale: 1)
        #expect(centre(image).isClose(to: Pixel(red: 200, green: 120, blue: 40), tolerance: 1))
        #expect(renderer.context.pixel(of: image, x: 0, y: 0).isClose(to: Pixel(red: 200, green: 120, blue: 40), tolerance: 1))
    }

    @Test func filmRunsItsFilterChainThenItsTint() {
        let noGrain = PhotoAdjustments(intensity: 100, grain: 0)
        let image = renderer.render(orange, model: model(.film, noGrain), scale: 1)
        #expect(centre(image).isClose(to: Pixel(red: 237, green: 135, blue: 47)))
    }

    @Test func effectStrengthBlendsTheLookWithTheOriginal() {
        let half = PhotoAdjustments(intensity: 50, grain: 0)
        let image = renderer.render(orange, model: model(.film, half), scale: 1)
        #expect(centre(image).isClose(to: Pixel(red: 220, green: 127, blue: 44)))
    }

    @Test func lightAndContrastAreTheCSSFilters() {
        let grey = CIImage.flat(red: 0.4, green: 0.4, blue: 0.4, width: 30, height: 40)
        let edited = PhotoAdjustments(intensity: 0, grain: 0, exposure: 20, contrast: 50)
        let image = renderer.render(grey, model: model(.film, edited), scale: 1)
        #expect(centre(image).isClose(to: Pixel(red: 120, green: 120, blue: 120), tolerance: 1))
    }

    @Test func warmthIsASoftLightWash() {
        let grey = CIImage.flat(red: 0.5, green: 0.5, blue: 0.5, width: 30, height: 40)
        let warm = PhotoAdjustments(intensity: 0, grain: 0, warmth: 50)
        let image = renderer.render(grey, model: model(.film, warm), scale: 1)
        #expect(centre(image).isClose(to: Pixel(red: 154, green: 130, blue: 96), tolerance: 1))
    }

    @Test func theFlashSitsAboveTheMiddleAsOnScreen() {
        // Core Image counts rows from the bottom, the look from the top: the flash is centred 42% down.
        let grey = CIImage.flat(red: 0.5, green: 0.5, blue: 0.5, width: 30, height: 100)
        let image = renderer.render(grey, model: model(.disposable, PhotoAdjustments(intensity: 100, grain: 0)), scale: 1)
        let upper = renderer.context.pixel(of: image, x: 15, y: 30)
        let lower = renderer.context.pixel(of: image, x: 15, y: 70)
        #expect(upper.red > lower.red + 4)
    }

    @Test func theVignetteDarkensTheCorners() {
        let image = renderer.render(orange, model: model(.film, PhotoAdjustments(intensity: 100, grain: 0)), scale: 1)
        #expect(renderer.context.pixel(of: image, x: 0, y: 0).red < centre(image).red - 40)
    }

    @Test func theLookKeepsItsSizeOnABiggerPicture() {
        // At 3 pixels per point the centre is still far from the vignette, exactly as at 1.
        let big = CIImage.flat(red: 200.0 / 255, green: 120.0 / 255, blue: 40.0 / 255, width: 90, height: 120)
        let image = renderer.render(big, model: model(.film, PhotoAdjustments(intensity: 100, grain: 0)), scale: 3)
        #expect(image.extent == big.extent)
        #expect(centre(image).isClose(to: Pixel(red: 237, green: 135, blue: 47)))
        let small = renderer.render(orange, model: model(.film, PhotoAdjustments(intensity: 100, grain: 0)), scale: 1)
        #expect(renderer.context.pixel(of: image, x: 1, y: 1).isClose(to: renderer.context.pixel(of: small, x: 0, y: 0), tolerance: 6))
    }

    @Test(arguments: CameraStyle.allCases)
    func everyCameraChangesThePicture(camera: CameraStyle) {
        // A fitted look can leave one colour where it was; no look leaves both the orange and a mid grey.
        let grey = CIImage.flat(red: 0.5, green: 0.5, blue: 0.5, width: 30, height: 40)
        let image = renderer.render(orange, model: model(camera, .neutral), scale: 1)
        let greyed = renderer.render(grey, model: model(camera, .neutral), scale: 1)
        #expect(image.extent == orange.extent)
        let orangeMoved = !centre(image).isClose(to: Pixel(red: 200, green: 120, blue: 40), tolerance: 3)
        let greyMoved = !centre(greyed).isClose(to: Pixel(red: 128, green: 128, blue: 128), tolerance: 3)
        #expect(orangeMoved || greyMoved)
    }

    @Test func theStampGoesUnderLightAndContrast() {
        let black = CIImage.flat(red: 0, green: 0, blue: 0, width: 30, height: 40)
        let stamp = CIImage.flat(red: 0.4, green: 0.4, blue: 0.4, width: 30, height: 40)
        let edited = PhotoAdjustments(intensity: 0, grain: 0, exposure: 20, contrast: 50)
        let image = renderer.render(black, model: model(.film, edited), scale: 1, stamp: stamp)
        #expect(centre(image).isClose(to: Pixel(red: 120, green: 120, blue: 120), tolerance: 1))
    }

    // MARK: The saved picture

    @Test func aPhotoIsSavedWholeAtItsOwnSize() {
        let layout = BakeLayout(source: orange.extent.size, frame: nil)
        let image = renderer.picture(from: orange, model: model(.film, .neutral), layout: layout, stamp: nil)
        #expect(image.extent == orange.extent)
    }

    @Test func anInstantPhotoIsSavedAsAFramedPrint() {
        let source = CIImage.flat(red: 0.2, green: 0.3, blue: 0.4, width: 300, height: 400)
        let framed = LookRenderModel(camera: .instant, adjustments: .neutral, framed: true, stampEnabled: true)
        let layout = BakeLayout(source: source.extent.size, frame: .instantPrint)
        let image = renderer.picture(from: source, model: framed, layout: layout, stamp: nil)

        #expect(image.extent.size == layout.canvas)
        let paper = Pixel(red: 0xF7, green: 0xF3, blue: 0xEC)
        #expect(renderer.context.pixel(of: image, x: 2, y: 2).isClose(to: paper, tolerance: 1))
        #expect(renderer.context.pixel(of: image, x: 2, y: Int(layout.canvas.height) - 3).isClose(to: paper, tolerance: 1))
        #expect(!centre(image).isClose(to: paper, tolerance: 20))
    }
}

// MARK: Fitted cameras

extension LookRendererTests {
    /// The colour stage on a flat orange gives what `tools/colour.py` computes for the same recipe.
    @Test func aFittedCameraRunsItsColourTable() {
        // The fixtures' orange through each camera's table (`tools/lut.py` gives the same numbers), with no
        // grain, no vignette in the middle, and no glow (the orange is below the halation threshold).
        let noGrain = PhotoAdjustments(intensity: 100, grain: 0)
        let tlr = renderer.render(orange, model: model(.tlr, noGrain), scale: 1)
        #expect(centre(tlr).isClose(to: Pixel(red: 219, green: 107, blue: 17), tolerance: 2))
        let negative = renderer.render(orange, model: model(.negative, noGrain), scale: 1)
        #expect(centre(negative).isClose(to: Pixel(red: 216, green: 126, blue: 44), tolerance: 2))
    }

    @Test func filmGrainRoughensAFlatPicture() {
        let grey = CIImage.flat(red: 0.5, green: 0.5, blue: 0.5, width: 40, height: 40)
        let plain = renderer.render(grey, model: model(.negative, PhotoAdjustments(intensity: 100, grain: 0)), scale: 1)
        let grainy = renderer.render(grey, model: model(.negative, .neutral), scale: 1)
        let region = CGRect(x: 10, y: 10, width: 20, height: 20)
        let flat = renderer.context.pixels(of: plain, in: region).map(\.green)
        let rough = renderer.context.pixels(of: grainy, in: region).map(\.green)
        #expect(Set(flat).count <= 2)
        #expect(Set(rough).count > 8)
    }

    @Test func halationGlowsBesideAHighlight() {
        // A white square on dark grey: just outside the square the glow lifts the grey; far from it nothing changes.
        // (Dark grey rather than black: 135 NE's fitted toe is flat enough at black to swallow a faint glow.)
        let grey = CIImage.flat(red: 0.2, green: 0.2, blue: 0.2, width: 120, height: 120)
        let white = CIImage.flat(red: 1, green: 1, blue: 1, width: 30, height: 30)
            .transformed(by: CGAffineTransform(translationX: 45, y: 45))
        let scene = white.composited(over: grey)
        let image = renderer.render(scene, model: model(.negative, PhotoAdjustments(intensity: 100, grain: 0)), scale: 1)
        // The square covers rows 45 to 74 counted from the top; the row above it is 44.
        let beside = renderer.context.pixel(of: image, x: 60, y: 44)
        let far = renderer.context.pixel(of: image, x: 60, y: 5)
        // The glow is white: beside the square every channel is lifted by a few levels.
        #expect(beside.red > far.red + 3)
        #expect(beside.green > far.green + 3)
        #expect(beside.blue > far.blue + 2)
    }

    @Test func aFramedNegativeIsSavedOnItsStrip() {
        let source = CIImage.flat(red: 0.2, green: 0.3, blue: 0.4, width: 300, height: 400)
        let framed = LookRenderModel(camera: .negative, adjustments: .neutral, framed: true, stampEnabled: false)
        let layout = BakeLayout(source: source.extent.size, frame: .filmStrip)
        let image = renderer.picture(from: source, model: framed, layout: layout, stamp: nil, paper: CIColor(hex: 0))
        #expect(image.extent.size == layout.canvas)
        let black = Pixel(red: 0, green: 0, blue: 0)
        #expect(renderer.context.pixel(of: image, x: 2, y: Int(layout.canvas.height) / 2).isClose(to: black, tolerance: 1))
        #expect(!centre(image).isClose(to: black, tolerance: 20))
        // The artwork goes over the lot.
        let art = CIImage.flat(red: 1, green: 0, blue: 0, width: Int(layout.canvas.width), height: Int(layout.canvas.height))
        let decorated = renderer.picture(from: source, model: framed, layout: layout, stamp: nil, paper: CIColor(hex: 0), artwork: art)
        #expect(centre(decorated).isClose(to: Pixel(red: 255, green: 0, blue: 0), tolerance: 1))
    }
}

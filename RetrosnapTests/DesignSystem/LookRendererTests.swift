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
        let image = renderer.render(orange, model: model(camera, .neutral), scale: 1)
        #expect(image.extent == orange.extent)
        #expect(!centre(image).isClose(to: Pixel(red: 200, green: 120, blue: 40), tolerance: 3))
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
        let layout = BakeLayout(source: orange.extent.size, isFramed: false)
        let image = renderer.picture(from: orange, model: model(.film, .neutral), layout: layout, stamp: nil)
        #expect(image.extent == orange.extent)
    }

    @Test func anInstantPhotoIsSavedAsAFramedPrint() {
        let source = CIImage.flat(red: 0.2, green: 0.3, blue: 0.4, width: 300, height: 400)
        let framed = LookRenderModel(camera: .instant, adjustments: .neutral, framed: true, stampEnabled: true)
        let layout = BakeLayout(source: source.extent.size, isFramed: true)
        let image = renderer.picture(from: source, model: framed, layout: layout, stamp: nil)

        #expect(image.extent.size == layout.canvas)
        let paper = Pixel(red: 0xF7, green: 0xF3, blue: 0xEC)
        #expect(renderer.context.pixel(of: image, x: 2, y: 2).isClose(to: paper, tolerance: 1))
        #expect(renderer.context.pixel(of: image, x: 2, y: Int(layout.canvas.height) - 3).isClose(to: paper, tolerance: 1))
        #expect(!centre(image).isClose(to: paper, tolerance: 20))
    }
}

import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct LookFrameTests {
    private let photo = CGSize(width: 390, height: 520)

    @Test func theInstantWindowIsTheDesignsPadding() {
        let window = LookFrame.instantPrint.window(in: CGSize(width: 88, height: 107))
        #expect(isClose(window.minX, 88 * 0.055, tolerance: 1e-9))
        #expect(isClose(window.minY, 88 * 0.055, tolerance: 1e-9))
        #expect(isClose(window.width, 88 * 0.89, tolerance: 1e-9))
        #expect(isClose(window.height, 107 - 88 * 0.275, tolerance: 1e-9))
    }

    @Test func theFilmStripPictureIsTwoByThreeBetweenThePerforations() {
        let window = LookFrame.filmStrip.window(in: photo)
        #expect(isClose(window.width, 390 * 24 / 35, tolerance: 1e-6))
        #expect(isClose(window.height, window.width * 1.5, tolerance: 1e-6))
        #expect(isClose(window.midX, 195, tolerance: 1e-6))
        #expect(isClose(window.midY, 260, tolerance: 1e-6))
        let strip = FilmStripGeometry(canvas: photo)
        // The perforations lie between the picture and the film's edge, with room for the edge print outside them.
        #expect(strip.leftHoleX > 0)
        #expect(strip.leftHoleX + strip.holeAcross < window.minX)
        #expect(isClose(strip.leftHoleX - strip.edge, 0, tolerance: 1e-6))
        #expect(strip.holeTops.first! <= 0)
        #expect(strip.holeTops.last! >= photo.height - strip.pitch)
        #expect(isClose(strip.holeTops[1] - strip.holeTops[0], strip.pitch, tolerance: 1e-9))
    }

    @Test func aTallerCanvasOnlyAddsFilmAboveAndBelow() {
        let window = LookFrame.filmStrip.window(in: CGSize(width: 390, height: 844))
        #expect(isClose(window.width, 390 * 24 / 35, tolerance: 1e-6))
        #expect(isClose(window.midY, 422, tolerance: 1e-6))
    }

    @Test func aWideCanvasTurnsTheFrameOnItsSide() {
        let upright = LookFrame.filmStrip.window(in: photo)
        let turned = LookFrame.filmStrip.window(in: CGSize(width: 520, height: 390))
        #expect(isClose(turned.width, upright.height, tolerance: 1e-6))
        #expect(isClose(turned.height, upright.width, tolerance: 1e-6))
        #expect(isClose(turned.midX, 260, tolerance: 1e-6))
        #expect(isClose(turned.midY, 195, tolerance: 1e-6))
        let square = LookFrame.square.window(in: CGSize(width: 520, height: 390))
        #expect(isClose(square.width, square.height, tolerance: 1e-6))
        #expect(isClose(square.height, 390 - 2 * 0.035 * 390, tolerance: 1e-6))
    }

    @Test func theRebatesKeepTheirRatiosInsideThinMargins() {
        let seven = LookFrame.mediumFormat.window(in: photo)
        #expect(isClose(seven.width, 390 * 0.9, tolerance: 1e-6))
        #expect(isClose(seven.width / seven.height, 0.8, tolerance: 1e-6))
        #expect(isClose(seven.midY, 260, tolerance: 1e-6))
        let square = LookFrame.square.window(in: photo)
        #expect(isClose(square.width, 390 * 0.93, tolerance: 1e-6))
        #expect(isClose(square.height, square.width, tolerance: 1e-6))
    }

    @Test func theSlideWindowSitsInTheMiddleOfTheMount() {
        let mount = SlideMountGeometry(canvas: photo)
        #expect(isClose(mount.side, 351, tolerance: 1e-6))
        #expect(isClose(mount.mount.midX, 195, tolerance: 1e-6))
        #expect(isClose(mount.mount.midY, 260, tolerance: 1e-6))
        let window = LookFrame.slideMount.window(in: photo)
        #expect(isClose(window.width, 351 * 0.46, tolerance: 1e-6))
        #expect(isClose(window.height, 351 * 0.69, tolerance: 1e-6))
        #expect(mount.mount.contains(window))
    }

    @Test func everyFrameNamesItsPictureRatioAndBase() {
        #expect(LookFrame.filmStrip.pictureRatio == 2.0 / 3)
        #expect(LookFrame.slideMount.pictureRatio == 2.0 / 3)
        #expect(LookFrame.mediumFormat.pictureRatio == 4.0 / 5)
        #expect(LookFrame.square.pictureRatio == 1)
        #expect(LookFrame.instantPrint.pictureRatio == 1)
        #expect(LookFrame.instantPrint.baseHex == RSColor.printFrameHex)
        #expect(LookFrame.filmStrip.baseHex == 0)
        #expect(CameraStyle.negative.pictureRatio == 2.0 / 3)
        #expect(CameraStyle.film.pictureRatio == nil)
        #expect(CameraStyle.instant.pictureRatio == 1)
    }

    @Test func fittedWindowsNeverLeaveTheirMargins() {
        for ratio in [0.5, 0.8, 1.0, 1.5] {
            let window = LookFrame.fitted(ratio: ratio, margin: 20, in: photo)
            #expect(window.minX >= 20 - 1e-9 && window.maxX <= 370 + 1e-9)
            #expect(window.minY >= 20 - 1e-9 && window.maxY <= 500 + 1e-9)
            #expect(isClose(window.width / window.height, ratio, tolerance: 1e-9))
        }
    }
}

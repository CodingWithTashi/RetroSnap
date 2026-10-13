import CoreGraphics
import Testing
@testable import Retrosnap

/// The canvases as the reference app lays them out (`docs/camera-lineup.md`, "Frames"): each camera's own shape,
/// with the picture at the film's ratio inside it.
@MainActor
struct LookFrameTests {
    private let portrait: CGFloat = 3.0 / 4
    private let landscape: CGFloat = 4.0 / 3

    @Test func theInstantWindowIsTheDesignsPadding() {
        let window = LookFrame.instantPrint.window(in: CGSize(width: 88, height: 107))
        #expect(isClose(window.minX, 88 * 0.055, tolerance: 1e-9))
        #expect(isClose(window.minY, 88 * 0.055, tolerance: 1e-9))
        #expect(isClose(window.width, 88 * 0.89, tolerance: 1e-9))
        #expect(isClose(window.height, 107 - 88 * 0.275, tolerance: 1e-9))
        #expect(isClose(LookFrame.instantPrint.canvasAspect(forPhotoAspect: portrait), 88.0 / 107, tolerance: 1e-9))
        #expect(isClose(LookFrame.instantPrint.canvasAspect(forPhotoAspect: landscape), 88.0 / 107, tolerance: 1e-9))
    }

    @Test func theFilmStripIsRealFilmAroundAThreeByTwoPicture() {
        // Lying down for a landscape photo: 38 units along the film, 31.96 across, the picture 36 x 24 in the middle.
        let aspect = LookFrame.filmStrip.canvasAspect(forPhotoAspect: landscape)
        #expect(isClose(aspect, 38 / 31.96, tolerance: 1e-6))
        let canvas = CGSize(width: 390, height: 390 / aspect)
        let window = LookFrame.filmStrip.window(in: canvas, photoAspect: landscape)
        let unit = 390.0 / 38
        #expect(isClose(window.width, 36 * unit, tolerance: 1e-6))
        #expect(isClose(window.height, 24 * unit, tolerance: 1e-6))
        #expect(isClose(window.midX, 195, tolerance: 1e-6))
        #expect(isClose(window.midY, canvas.height / 2, tolerance: 1e-6))
        // Standing up for a portrait photo: the same strip turned, the picture 24 units of the 31.96 wide.
        let upright = LookFrame.filmStrip.canvasAspect(forPhotoAspect: portrait)
        #expect(isClose(upright, 31.96 / 38, tolerance: 1e-6))
        let tall = CGSize(width: 390, height: 390 / upright)
        let standing = LookFrame.filmStrip.window(in: tall, photoAspect: portrait)
        #expect(isClose(standing.width, 390 * 24 / 31.96, tolerance: 1e-6))
        #expect(isClose(standing.height, standing.width * 1.5, tolerance: 1e-6))
        #expect(isClose(standing.midX, 195, tolerance: 1e-6))
        // The perforations' pitch and size are 135 film's.
        #expect(isClose(FilmStripGeometry.pitch, 4.72, tolerance: 1e-9))
        #expect(FilmStripGeometry.holeAcross > FilmStripGeometry.holeAlong)
        #expect(isClose(FilmStripGeometry.across, 24 + 2 * (0.6 + 2.93 + 0.45), tolerance: 1e-9))
    }

    @Test func aCanvasOfAnotherShapeGetsTheStripFittedAndCentred() {
        // A 3:4 box is taller than the standing strip, so the strip fills the width and sits in the middle.
        let window = LookFrame.filmStrip.window(in: CGSize(width: 390, height: 520), photoAspect: portrait)
        #expect(isClose(window.width, 390 * 24 / 31.96, tolerance: 1e-6))
        #expect(isClose(window.height, 390 * 36 / 31.96, tolerance: 1e-6))
        #expect(isClose(window.midY, 260, tolerance: 1e-6))
        #expect(isClose(window.midX, 195, tolerance: 1e-6))
    }

    @Test func theSevenRebateTurnsWithThePhoto() {
        let lying = LookFrame.mediumFormat.canvasAspect(forPhotoAspect: landscape)
        #expect(isClose(lying, 1.325 / 1.151, tolerance: 1e-6))
        let canvas = CGSize(width: 390, height: 390 / lying)
        let window = LookFrame.mediumFormat.window(in: canvas, photoAspect: landscape)
        let unit = 390 / 1.325
        #expect(isClose(window.width, 1.25 * unit, tolerance: 1e-6))
        #expect(isClose(window.height, unit, tolerance: 1e-6))
        #expect(isClose(window.minX, 0.0375 * unit, tolerance: 1e-6))
        #expect(isClose(window.minY, 0.069 * unit, tolerance: 1e-6))
        let standing = LookFrame.mediumFormat.canvasAspect(forPhotoAspect: portrait)
        #expect(isClose(standing, 1.135 / 1.362, tolerance: 1e-6))
        let tall = CGSize(width: 390, height: 390 / standing)
        let up = LookFrame.mediumFormat.window(in: tall, photoAspect: portrait)
        #expect(isClose(up.width / up.height, 0.8, tolerance: 1e-6))
        #expect(isClose(up.minX, 0.102 * 390 / 1.135, tolerance: 1e-6))
    }

    @Test func theSquareRebateIsTheSameWhicheverWayThePhotoIs() {
        let aspect = LookFrame.square.canvasAspect(forPhotoAspect: portrait)
        #expect(isClose(aspect, 1.086 / 1.058, tolerance: 1e-6))
        #expect(isClose(LookFrame.square.canvasAspect(forPhotoAspect: landscape), aspect, tolerance: 1e-9))
        let canvas = CGSize(width: 390, height: 390 / aspect)
        let window = LookFrame.square.window(in: canvas, photoAspect: landscape)
        let unit = 390 / 1.086
        #expect(isClose(window.width, unit, tolerance: 1e-6))
        #expect(isClose(window.height, unit, tolerance: 1e-6))
        #expect(isClose(window.minX, 0.03 * unit, tolerance: 1e-6))
        #expect(isClose(canvas.width - window.maxX, 0.056 * unit, tolerance: 1e-6))
        #expect(isClose(window.minY, 0.026 * unit, tolerance: 1e-6))
    }

    @Test func theSlideMountIsUprightAndItsWindowTurns() {
        #expect(isClose(LookFrame.slideMount.canvasAspect(forPhotoAspect: portrait), 0.75, tolerance: 1e-9))
        #expect(isClose(LookFrame.slideMount.canvasAspect(forPhotoAspect: landscape), 0.75, tolerance: 1e-9))
        let canvas = CGSize(width: 390, height: 520)
        let mount = SlideMountGeometry(canvas: canvas, photoAspect: landscape)
        #expect(isClose(mount.side, 390 * 0.81, tolerance: 1e-6))
        #expect(isClose(mount.mount.midX, 195, tolerance: 1e-6))
        #expect(isClose(mount.mount.midY, 260, tolerance: 1e-6))
        let wide = LookFrame.slideMount.window(in: canvas, photoAspect: landscape)
        #expect(isClose(wide.width, mount.side * 0.667, tolerance: 1e-6))
        #expect(isClose(wide.height, mount.side * 0.447, tolerance: 1e-6))
        #expect(mount.mount.contains(wide))
        let tall = LookFrame.slideMount.window(in: canvas, photoAspect: portrait)
        #expect(isClose(tall.width, mount.side * 0.447, tolerance: 1e-6))
        #expect(isClose(tall.height, mount.side * 0.667, tolerance: 1e-6))
        #expect(isClose(tall.midX, wide.midX, tolerance: 1e-6))
    }

    @Test func theFullFrameIsTheCropAndNothingElse() {
        #expect(isClose(LookFrame.fullFrame.canvasAspect(forPhotoAspect: landscape), 1.5, tolerance: 1e-9))
        #expect(isClose(LookFrame.fullFrame.canvasAspect(forPhotoAspect: portrait), 2.0 / 3, tolerance: 1e-9))
        let canvas = CGSize(width: 390, height: 585)
        #expect(LookFrame.fullFrame.window(in: canvas, photoAspect: portrait) == CGRect(origin: .zero, size: canvas))
    }

    @Test func everyFrameNamesItsPictureRatioAndBase() {
        #expect(LookFrame.filmStrip.pictureRatio == 3.0 / 2)
        #expect(LookFrame.slideMount.pictureRatio == 3.0 / 2)
        #expect(LookFrame.mediumFormat.pictureRatio == 5.0 / 4)
        #expect(LookFrame.square.pictureRatio == 1)
        #expect(LookFrame.fullFrame.pictureRatio == 3.0 / 2)
        #expect(LookFrame.instantPrint.pictureRatio == 1)
        #expect(LookFrame.instantPrint.baseHex == RSColor.printFrameHex)
        #expect(LookFrame.slideMount.baseHex == 0xFFFFFF)
        #expect(LookFrame.filmStrip.baseHex == 0x0B0B0B)
        #expect(CameraStyle.negative.pictureRatio == 3.0 / 2)
        #expect(CameraStyle.plastic35.pictureRatio == 3.0 / 2)
        #expect(CameraStyle.film.pictureRatio == nil)
        #expect(CameraStyle.instant.pictureRatio == 1)
    }

    @Test func thePictureTurnsWithThePhotoExceptForTheSquareAndThePrint() {
        #expect(isClose(LookFrame.filmStrip.pictureAspect(forPhotoAspect: portrait), 2.0 / 3, tolerance: 1e-9))
        #expect(isClose(LookFrame.filmStrip.pictureAspect(forPhotoAspect: landscape), 1.5, tolerance: 1e-9))
        #expect(isClose(LookFrame.mediumFormat.pictureAspect(forPhotoAspect: portrait), 0.8, tolerance: 1e-9))
        #expect(isClose(LookFrame.slideMount.pictureAspect(forPhotoAspect: landscape), 1.5, tolerance: 1e-9))
        #expect(isClose(LookFrame.square.pictureAspect(forPhotoAspect: landscape), 1, tolerance: 1e-9))
        #expect(isClose(LookFrame.instantPrint.pictureAspect(forPhotoAspect: landscape), 1, tolerance: 1e-9))
    }
}

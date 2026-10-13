import CoreGraphics
import Testing
@testable import Retrosnap

/// The canvases as the reference app lays them out (`docs/camera-lineup.md`, "Frames"): each camera's own shape,
/// with the picture at the film's ratio inside it.
@MainActor
struct LookFrameTests {
    private let portrait: CGFloat = 3.0 / 4
    private let landscape: CGFloat = 4.0 / 3

    @Test func theMiniPrintStandsOnItsSheetAndTurnsWithThePhoto() {
        // Standing up: a 2:3 sheet, the print 0.899 of it wide with its 3:4 window 0.845 of the print wide.
        #expect(isClose(LookFrame.instantPrint.canvasAspect(forPhotoAspect: portrait), 2.0 / 3, tolerance: 1e-9))
        let canvas = CGSize(width: 390, height: 585)
        let geometry = MiniPrintGeometry(canvas: canvas)
        #expect(isClose(geometry.print.width, 390 * 0.8988, tolerance: 1e-6))
        #expect(isClose(geometry.print.minX, 390 * 0.0439, tolerance: 1e-6))
        #expect(isClose(geometry.print.minY, 390 * 0.0528, tolerance: 1e-6))
        let window = LookFrame.instantPrint.window(in: canvas, photoAspect: portrait)
        #expect(isClose(window.width, 390 * 0.8988 * 0.8452, tolerance: 1e-6))
        #expect(isClose(window.height, window.width * 4 / 3, tolerance: 1e-6))
        #expect(isClose(window.minX, 390 * (0.0439 + 0.0774 * 0.8988), tolerance: 1e-6))
        #expect(isClose(window.minY, 390 * (0.0528 + 0.1306 * 0.8988), tolerance: 1e-6))
        #expect(isClose(window.midX, geometry.print.midX, tolerance: 1e-6))
        #expect(geometry.print.contains(window))
        // Lying down for a landscape photo: the sheet turned a quarter anticlockwise, the wide border on the right.
        #expect(isClose(LookFrame.instantPrint.canvasAspect(forPhotoAspect: landscape), 1.5, tolerance: 1e-9))
        let wide = CGSize(width: 390, height: 260)
        let lying = LookFrame.instantPrint.window(in: wide, photoAspect: landscape)
        #expect(isClose(lying.height, 260 * 0.8988 * 0.8452, tolerance: 1e-6))
        #expect(isClose(lying.width, lying.height * 4 / 3, tolerance: 1e-6))
        #expect(isClose(lying.minX, 260 * (0.0528 + 0.1306 * 0.8988), tolerance: 1e-6))
        let print = MiniPrintGeometry(canvas: wide).print
        let bottomBorder: CGFloat = 1.5625 - 0.1306 - 0.8452 * 4 / 3
        let unit: CGFloat = 260 * 0.8988
        #expect(isClose(print.maxX - lying.maxX, unit * bottomBorder, tolerance: 0.01))
        #expect(isClose(lying.minY - print.minY, unit * 0.0774, tolerance: 0.01))
    }

    @Test func theSquarePrintIsUprightWithItsWindowCentred() {
        #expect(isClose(LookFrame.squarePrint.canvasAspect(forPhotoAspect: portrait), 3024.0 / 3840, tolerance: 1e-9))
        #expect(isClose(LookFrame.squarePrint.canvasAspect(forPhotoAspect: landscape), 3024.0 / 3840, tolerance: 1e-9))
        let canvas = CGSize(width: 390, height: 390.0 * 3840 / 3024)
        let geometry = SquarePrintGeometry(canvas: canvas)
        #expect(isClose(geometry.print.width, 390 * 0.8925, tolerance: 1e-6))
        #expect(isClose(geometry.print.height, 390 * 0.8925 * 1.2007, tolerance: 1e-6))
        let window = LookFrame.squarePrint.window(in: canvas, photoAspect: landscape)
        #expect(isClose(window.width, window.height, tolerance: 1e-9))
        #expect(isClose(window.width, 390 * 0.8925 * 0.8547, tolerance: 1e-6))
        #expect(isClose(window.midX, geometry.print.midX, tolerance: 1e-6))
        #expect(isClose(window.minY - geometry.print.minY, 390 * 0.8925 * 0.1204, tolerance: 1e-6))
        #expect(geometry.print.maxY - window.maxY > window.minY - geometry.print.minY)
        // A photo gets the same card every time, and the three cards are all used.
        #expect(SquarePrintDesign.forPhoto(id: "s1") == SquarePrintDesign.forPhoto(id: "s1"))
        #expect(Set((0..<60).map { SquarePrintDesign.forPhoto(id: "photo-\($0)") }).count == 3)
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
        #expect(LookFrame.instantPrint.pictureRatio == 4.0 / 3)
        #expect(LookFrame.squarePrint.pictureRatio == 1)
        #expect(LookFrame.instantPrint.baseHex == 0xFFFFFF)
        #expect(LookFrame.squarePrint.baseHex == 0xFFFFFF)
        #expect(LookFrame.slideMount.baseHex == 0xFFFFFF)
        #expect(LookFrame.filmStrip.baseHex == 0x0B0B0B)
        #expect(CameraStyle.negative.pictureRatio == 3.0 / 2)
        #expect(CameraStyle.plastic35.pictureRatio == 3.0 / 2)
        #expect(CameraStyle.film.pictureRatio == 3.0 / 2)
        #expect(CameraStyle.disposable.pictureRatio == nil)
        #expect(CameraStyle.instant.pictureRatio == 4.0 / 3)
        #expect(CameraStyle.instSquare.pictureRatio == 1)
    }

    @Test func thePictureTurnsWithThePhotoExceptForTheSquares() {
        #expect(isClose(LookFrame.filmStrip.pictureAspect(forPhotoAspect: portrait), 2.0 / 3, tolerance: 1e-9))
        #expect(isClose(LookFrame.filmStrip.pictureAspect(forPhotoAspect: landscape), 1.5, tolerance: 1e-9))
        #expect(isClose(LookFrame.mediumFormat.pictureAspect(forPhotoAspect: portrait), 0.8, tolerance: 1e-9))
        #expect(isClose(LookFrame.slideMount.pictureAspect(forPhotoAspect: landscape), 1.5, tolerance: 1e-9))
        #expect(isClose(LookFrame.square.pictureAspect(forPhotoAspect: landscape), 1, tolerance: 1e-9))
        #expect(isClose(LookFrame.squarePrint.pictureAspect(forPhotoAspect: landscape), 1, tolerance: 1e-9))
        #expect(isClose(LookFrame.instantPrint.pictureAspect(forPhotoAspect: landscape), 4.0 / 3, tolerance: 1e-9))
        #expect(isClose(LookFrame.instantPrint.pictureAspect(forPhotoAspect: portrait), 3.0 / 4, tolerance: 1e-9))
    }
}

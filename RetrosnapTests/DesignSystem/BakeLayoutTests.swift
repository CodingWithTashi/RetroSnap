import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct BakeLayoutTests {

    @Test func aPhotoIsBakedWholeAndMeasuredAsTheViewerShowsIt() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: nil)
        #expect(layout.crop == CGRect(x: 0, y: 0, width: 3024, height: 4032))
        #expect(layout.canvas == CGSize(width: 3024, height: 4032))
        #expect(layout.photoOrigin == .zero)
        #expect(isClose(layout.scale, 3024.0 / 390))
        #expect(isClose(layout.pointSize.width, 390))
        #expect(isClose(layout.pointSize.height, 520))
    }

    @Test func aLandscapePhotoKeepsItsOwnShape() {
        let layout = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: nil)
        #expect(layout.canvas == CGSize(width: 4032, height: 3024))
        #expect(isClose(layout.pointSize.width, 390))
    }

    @Test func anInstantPrintHasTheDesignsFrame() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .instantPrint)
        // padding: 5.5% 5.5% 22% 5.5% of the print's width, on an 88:107 print.
        let printWidth = layout.canvas.width
        #expect(isClose(layout.canvas.height / printWidth, 107.0 / 88, tolerance: 0.001))
        #expect(isClose(layout.photoOrigin.x / printWidth, 0.055, tolerance: 0.001))
        #expect(isClose(layout.photoOrigin.y / printWidth, 0.22, tolerance: 0.001))
        #expect(isClose(layout.crop.width / printWidth, 0.89, tolerance: 0.001))
        let top = layout.canvas.height - layout.photoOrigin.y - layout.crop.height
        #expect(isClose(top / printWidth, 0.055, tolerance: 0.001))
        #expect(isClose(layout.scale, printWidth / 340))
    }

    // MARK: Film canvases

    @Test func aFilmStripPhotoKeepsEveryPixelOfItsCrop() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .filmStrip)
        // 2:3 from the full height of the photo, centred.
        #expect(layout.crop.height == 4032)
        #expect(layout.crop.width == 2688)
        #expect(isClose(layout.crop.midX, 1512, tolerance: 1))
        // The canvas keeps the photo's 3:4, the picture is 24/35 of it wide and sits in the middle.
        #expect(isClose(layout.canvas.width / layout.canvas.height, 0.75, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 24 / 35, tolerance: 0.5))
        #expect(isClose(layout.canvasPointSize.width, 390, tolerance: 0.5))
        #expect(isClose(layout.canvasPointSize.height, 520, tolerance: 0.5))
        #expect(isClose(layout.photoOrigin.x, (layout.canvas.width - layout.crop.width) / 2, tolerance: 1))
        #expect(isClose(layout.photoOrigin.y, (layout.canvas.height - layout.crop.height) / 2, tolerance: 1))
    }

    @Test func aSquareNegativeCropsTheHeight() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .square)
        #expect(layout.crop.width == 3024)
        #expect(layout.crop.height == 3024)
        #expect(isClose(layout.crop.midY, 2016, tolerance: 1))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 0.75, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 0.93, tolerance: 0.5))
    }

    @Test func aMediumFormatNegativeIsFourByFive() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .mediumFormat)
        #expect(layout.crop.width == 3024)
        #expect(layout.crop.height == 3780)
        #expect(isClose(layout.pointSize.width / layout.pointSize.height, 0.8, tolerance: 0.002))
    }

    @Test func aSlideSitsInTheMountsWindow() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .slideMount)
        #expect(isClose(layout.crop.width / layout.crop.height, 0.46 / 0.69, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 0.9 * 0.46, tolerance: 0.5))
        #expect(layout.canvas.width > layout.crop.width * 2)
    }

    @Test func aLandscapePhotoGetsItsFrameOnItsSide() {
        let layout = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .filmStrip)
        #expect(layout.crop.width == 4032)
        #expect(layout.crop.height == 2688)
        #expect(isClose(layout.canvas.width / layout.canvas.height, 4.0 / 3, tolerance: 0.002))
        #expect(isClose(layout.pointSize.height, 292.5 * 24 / 35, tolerance: 0.5))
    }

    // MARK: Prints

    @Test func aBorderedPrintPutsThePhotoInsideThePaperAsThePreviewDraws() {
        // 4x6 as previewed: 240 x 360 points of paper with a 14 point border.
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), paper: CGSize(width: 240, height: 360), border: 14)
        #expect(isClose(layout.canvas.width / layout.canvas.height, 240.0 / 360, tolerance: 0.002))
        #expect(isClose(layout.photoOrigin.x / layout.canvas.width, 14.0 / 240, tolerance: 0.002))
        #expect(isClose(layout.photoOrigin.y / layout.canvas.height, 14.0 / 360, tolerance: 0.002))
        #expect(isClose(layout.crop.width / layout.crop.height, 212.0 / 332, tolerance: 0.002))
        #expect(isClose(layout.crop.midX, 1512, tolerance: 1))
        #expect(isClose(layout.crop.midY, 2016, tolerance: 1))
        #expect(isClose(layout.scale, layout.canvas.width / 240, tolerance: 0.01))
        #expect(isClose(layout.pointSize.width, 212, tolerance: 0.5))
    }

    @Test func aBorderlessPrintFillsThePaper() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), paper: CGSize(width: 290, height: 290), border: 0)
        #expect(layout.photoOrigin == .zero)
        #expect(layout.canvas == layout.crop.size)
        #expect(layout.crop.width == layout.crop.height)
        #expect(layout.crop.width == 3024)
    }

    @Test func theInstantPhotoUsesItsFullWidthAndTheMiddleOfItsHeight() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .instantPrint)
        #expect(layout.crop.width == 3024)
        #expect(layout.crop.height < 4032)
        #expect(isClose(layout.crop.midY, 2016, tolerance: 1))
        #expect(layout.crop.minX == 0)
    }

    @Test func aLandscapeInstantPhotoIsCroppedAtTheSidesInstead() {
        let layout = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .instantPrint)
        #expect(layout.crop.height == 3024)
        #expect(layout.crop.width < 4032)
        #expect(isClose(layout.crop.midX, 2016, tolerance: 1))
    }
}

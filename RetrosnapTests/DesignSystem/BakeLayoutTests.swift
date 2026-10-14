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

    @Test func aMiniPrintKeepsTheWholePhotoInItsWindowOnItsSheet() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .instantPrint)
        // The 3:4 window takes the whole 3:4 photo; the sheet is 2:3 and the window 0.7597 of it wide.
        #expect(layout.crop == CGRect(x: 0, y: 0, width: 3024, height: 4032))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 2.0 / 3, tolerance: 0.002))
        #expect(isClose(layout.crop.width / layout.canvas.width, 0.8988 * 0.8452, tolerance: 0.002))
        #expect(isClose(layout.photoOrigin.x / layout.canvas.width, 0.0439 + 0.0774 * 0.8988, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 0.8988 * 0.8452, tolerance: 0.5))
        #expect(isClose(layout.canvasPointSize.width, 390, tolerance: 0.5))
    }

    @Test func aSquarePrintCropsTheSquareFromTheMiddle() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .squarePrint)
        #expect(layout.crop.width == 3024)
        #expect(layout.crop.height == 3024)
        #expect(isClose(layout.crop.midY, 2016, tolerance: 1))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 3024.0 / 3840, tolerance: 0.002))
        #expect(isClose(layout.crop.width / layout.canvas.width, 0.8925 * 0.8547, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 0.8925 * 0.8547, tolerance: 0.5))
        let wide = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .squarePrint)
        #expect(wide.crop.height == 3024)
        #expect(wide.crop.width == 3024)
        #expect(isClose(wide.canvas.width / wide.canvas.height, 3024.0 / 3840, tolerance: 0.002))
    }

    // MARK: Film canvases

    @Test func aFilmStripPhotoKeepsEveryPixelOfItsCrop() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .filmStrip)
        // 2:3 from the full height of the photo, centred.
        #expect(layout.crop.height == 4032)
        #expect(layout.crop.width == 2688)
        #expect(isClose(layout.crop.midX, 1512, tolerance: 1))
        // The canvas is the strip standing up: 31.96 units wide and 38 along, the picture 24 of them wide.
        #expect(isClose(layout.canvas.width / layout.canvas.height, 31.96 / 38, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 24 / 31.96, tolerance: 0.5))
        #expect(isClose(layout.canvasPointSize.width, 390, tolerance: 0.5))
        #expect(isClose(layout.canvasPointSize.height, 390 * 38 / 31.96, tolerance: 0.5))
        #expect(isClose(layout.photoOrigin.x, (layout.canvas.width - layout.crop.width) / 2, tolerance: 1))
        #expect(isClose(layout.photoOrigin.y, (layout.canvas.height - layout.crop.height) / 2, tolerance: 1))
    }

    @Test func aSquareNegativeCropsTheHeight() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .square)
        #expect(layout.crop.width == 3024)
        #expect(layout.crop.height == 3024)
        #expect(isClose(layout.crop.midY, 2016, tolerance: 1))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 1.086 / 1.058, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 / 1.086, tolerance: 0.5))
        #expect(isClose(layout.photoOrigin.x, 0.03 * layout.crop.width, tolerance: 2))
    }

    @Test func aMediumFormatNegativeIsFourByFive() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .mediumFormat)
        #expect(layout.crop.width == 3024)
        #expect(layout.crop.height == 3780)
        #expect(isClose(layout.pointSize.width / layout.pointSize.height, 0.8, tolerance: 0.002))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 1.135 / 1.362, tolerance: 0.002))
        #expect(isClose(layout.photoOrigin.x, 0.102 * layout.crop.width, tolerance: 2))
    }

    @Test func aSlideSitsInTheMountsWindowOnAnUprightTable() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .slideMount)
        #expect(isClose(layout.crop.width / layout.crop.height, 0.46 / 0.67, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 0.81 * 0.46, tolerance: 0.5))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 0.75, tolerance: 0.002))
        let wide = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .slideMount)
        #expect(isClose(wide.crop.width / wide.crop.height, 0.67 / 0.46, tolerance: 0.002))
        #expect(isClose(wide.canvas.width / wide.canvas.height, 0.75, tolerance: 0.002))
    }

    @Test func aLandscapePhotoGetsItsStripLyingDown() {
        let layout = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .filmStrip)
        #expect(layout.crop.width == 4032)
        #expect(layout.crop.height == 2688)
        #expect(isClose(layout.canvas.width / layout.canvas.height, 38 / 31.96, tolerance: 0.002))
        #expect(isClose(layout.pointSize.width, 390 * 36 / 38, tolerance: 0.5))
    }

    @Test func aFullFrameIsTheThreeByTwoCropAlone() {
        let layout = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .fullFrame)
        #expect(layout.crop.width == 2688)
        #expect(layout.crop.height == 4032)
        #expect(layout.canvas == layout.crop.size)
        #expect(layout.photoOrigin == .zero)
        #expect(isClose(layout.pointSize.width, 390, tolerance: 0.5))
        let wide = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .fullFrame)
        #expect(wide.crop.width == 4032)
        #expect(wide.crop.height == 2688)
        #expect(isClose(wide.scale, 4032.0 / 390, tolerance: 0.01))
    }

    @Test func artworkIsRasterisedNoLargerThanTheRendererCanMake() {
        // A slide mount around a 4032-pixel photo: the file is some 7500 pixels wide, the artwork is drawn at 4096.
        let slide = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .slideMount)
        #expect(slide.canvas.width > 4096)
        #expect(isClose(slide.artworkScale * max(slide.canvasPointSize.width, slide.canvasPointSize.height), 4096, tolerance: 0.5))
        #expect(slide.artworkScale < slide.scale)
        // A square rebate around the same photo is under the limit and is drawn at the file's own scale.
        let square = BakeLayout(source: CGSize(width: 3024, height: 4032), frame: .square)
        #expect(square.canvas.width < 4096)
        #expect(isClose(square.artworkScale, square.scale, tolerance: 1e-9))
        #expect(isClose(square.stampScale, square.scale, tolerance: 1e-9))
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

    @Test func aLandscapeInstantPhotoLiesOnItsSheetWhole() {
        let layout = BakeLayout(source: CGSize(width: 4032, height: 3024), frame: .instantPrint)
        #expect(layout.crop == CGRect(x: 0, y: 0, width: 4032, height: 3024))
        #expect(isClose(layout.canvas.width / layout.canvas.height, 1.5, tolerance: 0.002))
        // The sheet lies down: the window is 1.0129 of the sheet's short side wide, 0.1702 of it in.
        #expect(isClose(layout.crop.width / layout.canvas.height, 0.8988 * 0.8452 * 4 / 3, tolerance: 0.002))
        #expect(isClose(layout.photoOrigin.x / layout.canvas.height, 0.0528 + 0.1306 * 0.8988, tolerance: 0.002))
    }

    @Test func aWiderImportIsCroppedToTheMiniPrintsWindow() {
        let layout = BakeLayout(source: CGSize(width: 4000, height: 2000), frame: .instantPrint)
        #expect(layout.crop.height == 2000)
        #expect(isClose(layout.crop.width, 2000 * 4 / 3, tolerance: 1))
        #expect(isClose(layout.crop.midX, 2000, tolerance: 1))
    }
}

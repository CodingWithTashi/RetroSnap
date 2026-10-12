import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct CollageLayoutTests {

    @Test func cellsArePercentagesOfTheFrameInsetByTheGutter() {
        let cells = CollageLayout.cells(of: .feature, in: CGSize(width: 280, height: 380), gap: 4)
        #expect(cells == [
            CGRect(x: 4, y: 4, width: 272, height: 220),
            CGRect(x: 4, y: 232, width: 132, height: 144),
            CGRect(x: 144, y: 232, width: 132, height: 144),
        ])
    }

    @Test func withoutAGutterCellsTouch() {
        let cells = CollageLayout.cells(of: .sideBySide, in: CGSize(width: 300, height: 400), gap: 0)
        #expect(cells == [CGRect(x: 0, y: 0, width: 150, height: 400), CGRect(x: 150, y: 0, width: 150, height: 400)])
    }

    @Test func theFrameIsTallAndNarrowForAStrip() {
        #expect(CollageLayout(template: .feature, border: .cream).frameSize == CGSize(width: 300, height: 400))
        #expect(CollageLayout(template: .strip, border: .cream).frameSize.width == 170)
    }

    @Test func aBorderAddsAnEdgeAndGutters() {
        let bordered = CollageLayout(template: .grid, border: .black)
        #expect(bordered.inset == 10)
        #expect(bordered.gap == 4)
        let plain = CollageLayout(template: .grid, border: .none)
        #expect(plain.inset == 0)
        #expect(plain.gap == 0)
    }

    @Test func photoCellsSitInsideTheFramesEdge() {
        let layout = CollageLayout(template: .stacked, border: .cream)
        #expect(layout.photoCells == [
            CGRect(x: 14, y: 14, width: 272, height: 182),
            CGRect(x: 14, y: 204, width: 272, height: 182),
        ])
    }
}

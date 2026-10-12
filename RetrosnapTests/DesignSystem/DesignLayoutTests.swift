import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct DesignLayoutTests {
    @Test func theDesignsOwnFrameKeepsItsOffsets() {
        let layout = DesignLayout()
        #expect(layout.top(56) == 56)
        #expect(layout.bottom(40) == 40)
        #expect(layout.extraHeight == 0)
    }

    @Test func aTallerSafeAreaPushesContentInByTheDifference() {
        // A Dynamic Island phone: 59pt at the top where the design has 47.
        let layout = DesignLayout(size: CGSize(width: 393, height: 852), safeTop: 59, safeBottom: 34)
        #expect(layout.top(56) == 68)
        #expect(layout.bottom(40) == 40)
        #expect(layout.extraHeight == 8)
    }

    @Test func aShorterSafeAreaNeverPullsContentCloserToTheEdge() {
        // A phone with a home button: 20pt at the top and nothing at the bottom.
        let layout = DesignLayout(size: CGSize(width: 375, height: 667), safeTop: 20, safeBottom: 0)
        #expect(layout.top(56) == 56)
        #expect(layout.bottom(40) == 40)
        #expect(layout.extraHeight == 0)
    }
}

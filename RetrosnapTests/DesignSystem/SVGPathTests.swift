import CoreGraphics
import SwiftUI
import Testing
@testable import Retrosnap

@MainActor
struct SVGPathTests {
    /// The tight box around what the path data draws.
    private func bounds(_ d: String) -> CGRect {
        SVGPath.path(d).cgPath.boundingBoxOfPath
    }

    /// An arc is drawn as cubic curves, which miss a true circle by a fraction of a percent.
    private func matches(_ rect: CGRect, x: Double, y: Double, width: Double, height: Double) -> Bool {
        isClose(rect.minX, x, tolerance: 0.01) && isClose(rect.minY, y, tolerance: 0.01)
            && isClose(rect.width, width, tolerance: 0.01) && isClose(rect.height, height, tolerance: 0.01)
    }

    @Test func absoluteLinesMakeAClosedShape() {
        let path = SVGPath.path("M2 3L10 3L10 9Z")
        #expect(path.cgPath.boundingBoxOfPath == CGRect(x: 2, y: 3, width: 8, height: 6))
        #expect(path.contains(CGPoint(x: 9, y: 4)))
        #expect(!path.contains(CGPoint(x: 3, y: 8)))
    }

    @Test func relativeCommandsCountFromWhereThePenIs() {
        #expect(bounds("m2 3l8 0l0 6z") == CGRect(x: 2, y: 3, width: 8, height: 6))
    }

    @Test func horizontalAndVerticalLinesMoveOnOneAxis() {
        #expect(bounds("M1 1H11V6h-10z") == CGRect(x: 1, y: 1, width: 10, height: 5))
        #expect(bounds("M1 1h10v5H1V1") == CGRect(x: 1, y: 1, width: 10, height: 5))
    }

    @Test func pairsAfterAMoveAreLines() {
        #expect(bounds("M0 0 10 0 10 10") == CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(bounds("m1 1 2 0 0 2") == CGRect(x: 1, y: 1, width: 2, height: 2))
    }

    @Test func numbersNeedNoSeparatorWhereASignOrADotStartsTheNext() {
        #expect(bounds("M.5.5L1.5-1") == CGRect(x: 0.5, y: -1, width: 1, height: 1.5))
        #expect(bounds("M10,20,30,5") == CGRect(x: 10, y: 5, width: 20, height: 15))
    }

    @Test func theSweepFlagPicksTheSideAnArcBulgesTo() {
        // Left to right across a circle of radius 5 centred on (5, 5): over the top, or under the bottom.
        #expect(matches(bounds("M0 5A5 5 0 0 1 10 5"), x: 0, y: 0, width: 10, height: 5))
        #expect(matches(bounds("M0 5A5 5 0 0 0 10 5"), x: 0, y: 5, width: 10, height: 5))
    }

    @Test func theLargeArcFlagPicksTheLongWayRound() {
        // A quarter of a circle of radius 5 centred on (5, 5), and the other three quarters of it.
        #expect(matches(bounds("M0 5A5 5 0 0 1 5 0"), x: 0, y: 0, width: 5, height: 5))
        #expect(matches(bounds("M0 5A5 5 0 1 0 5 0"), x: 0, y: 0, width: 10, height: 10))
    }

    @Test func arcFlagsMayRunTogether() {
        #expect(matches(bounds("M0 5A5 5 0 01 10 5"), x: 0, y: 0, width: 10, height: 5))
    }

    @Test func twoHalvesMakeACircle() {
        #expect(matches(bounds("M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20"), x: 2, y: 2, width: 20, height: 20))
    }

    @Test func anArcTooSmallForItsEndsIsGrownToReachThem() {
        // Radius 1 cannot span 10: it becomes the half circle of radius 5.
        #expect(matches(bounds("M0 5A1 1 0 0 1 10 5"), x: 0, y: 0, width: 10, height: 5))
    }

    @Test func anArcWithNoRadiusIsALine() {
        #expect(bounds("M0 0A0 5 0 0 1 10 10") == CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    @Test func closingGoesBackToWhereTheShapeStarted() {
        // The second shape is placed from (2, 2), not from the corner the first one ended on.
        #expect(bounds("M2 2h4v4z m10 10h1") == CGRect(x: 2, y: 2, width: 11, height: 10))
    }

    @Test func whatCannotBeReadEndsThePathAndKeepsWhatWasDrawn() {
        #expect(bounds("M0 0L10 10Q5 5 1 1") == CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(bounds("M0 0L10 10L") == CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(SVGPath.path("").isEmpty)
        #expect(SVGPath.path("nonsense").isEmpty)
    }

    @Test(arguments: RSIcon.allCases)
    func everyIconDrawsInsideItsBox(icon: RSIcon) {
        let drawn = RSIconShape(icon: icon).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath.boundingBoxOfPath
        #expect(!drawn.isEmpty)
        #expect(CGRect(x: 0, y: 0, width: 24, height: 24).insetBy(dx: -0.01, dy: -0.01).contains(drawn))
    }
}

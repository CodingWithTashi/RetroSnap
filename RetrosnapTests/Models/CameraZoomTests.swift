import Testing
@testable import Retrosnap

@MainActor
struct CameraZoomTests {
    /// A phone with an ultra-wide beside its main lens.
    private func zoom(at factor: Double) -> CameraZoom {
        CameraZoom(factor: factor, range: 0.5...10, stops: [0.5, 1, 2])
    }

    @Test(arguments: [(1.0, "1×"), (0.5, "0.5×"), (2.0, "2×"), (1.44, "1.4×"), (1.96, "2×"), (10.0, "10×")])
    func theTitleShowsOneDecimalOnlyWhenItSaysSomething(factor: Double, title: String) {
        #expect(zoom(at: factor).title == title)
    }

    @Test func onlyTheMainLensesOwnViewIsAtRest() {
        #expect(zoom(at: 1).isAtRest)
        #expect(!zoom(at: 0.5).isAtRest)
        #expect(!zoom(at: 1.2).isAtRest)
    }

    @Test func theButtonStepsUpThroughTheStopsAndRoundAgain() {
        #expect(zoom(at: 0.5).nextStop == 1)
        #expect(zoom(at: 1).nextStop == 2)
        #expect(zoom(at: 2).nextStop == 0.5)
    }

    @Test func betweenStopsTheButtonGoesToTheNextOneUp() {
        #expect(zoom(at: 0.8).nextStop == 1)
        #expect(zoom(at: 1.5).nextStop == 2)
        #expect(zoom(at: 6).nextStop == 0.5)
        // All but on 2× already, so the next one is the first again.
        #expect(zoom(at: 1.97).nextStop == 0.5)
    }

    @Test func aLensWithOneStopStaysOnIt() {
        #expect(CameraZoom.fixed.nextStop == 1)
        #expect(CameraZoom(factor: 3, range: 1...5, stops: [1]).nextStop == 1)
    }

    @Test func aPinchStaysInsideTheRange() {
        #expect(zoom(at: 1).settled(0.2) == 0.5)
        #expect(zoom(at: 1).settled(40) == 10)
        #expect(zoom(at: 1).settled(3.3) == 3.3)
    }

    @Test func aPinchLandsOnAStopItIsAllButOn() {
        #expect(zoom(at: 1.5).settled(1.03) == 1)
        #expect(zoom(at: 1.5).settled(0.97) == 1)
        #expect(zoom(at: 1.5).settled(1.93) == 2)
        #expect(zoom(at: 1.5).settled(0.51) == 0.5)
        #expect(zoom(at: 1.5).settled(1.1) == 1.1)
    }

    @Test func aStopIsPassedOnTheWayUpOrDownOrByLandingOnIt() {
        #expect(zoom(at: 0.9).passesStop(goingTo: 1.2))
        #expect(zoom(at: 1.2).passesStop(goingTo: 0.9))
        #expect(zoom(at: 1.6).passesStop(goingTo: 2))
        #expect(!zoom(at: 1.2).passesStop(goingTo: 1.6))
    }

    @Test func leavingAStopIsNotPassingIt() {
        #expect(!zoom(at: 1).passesStop(goingTo: 1.3))
        #expect(!zoom(at: 1).passesStop(goingTo: 1))
        #expect(zoom(at: 1).passesStop(goingTo: 2.4))
    }
}

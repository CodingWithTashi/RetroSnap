import Testing
@testable import Retrosnap

@MainActor
struct LensZoomTests {
    @Test func aSingleLensIsShownAsItCounts() {
        let lens = LensZoom(limits: 1...123.75, switchOvers: [], mainLens: 0)
        #expect(lens.multiplier == 1)
        #expect(lens.range == 1...10)
        #expect(lens.stops == [1, 2])
    }

    @Test func anUltraWideBesideTheMainLensIsHalf() {
        let lens = LensZoom(limits: 1...123.75, switchOvers: [2], mainLens: 1)
        #expect(lens.multiplier == 0.5)
        #expect(lens.range == 0.5...10)
        #expect(lens.stops == [0.5, 1, 2])
    }

    @Test func aTelephotoAddsItsOwnStop() {
        #expect(LensZoom(limits: 1...90, switchOvers: [2, 6], mainLens: 1).stops == [0.5, 1, 2, 3])
        #expect(LensZoom(limits: 1...90, switchOvers: [2, 10], mainLens: 1).stops == [0.5, 1, 2, 5])
    }

    @Test func aTelephotoAtTwoIsNotListedTwice() {
        let lens = LensZoom(limits: 1...16, switchOvers: [2], mainLens: 0)
        #expect(lens.multiplier == 1)
        #expect(lens.stops == [1, 2])
    }

    @Test func aLensThatCannotReachTwoHasNoSuchStop() {
        let lens = LensZoom(limits: 1...1.5, switchOvers: [], mainLens: 0)
        #expect(lens.range == 1...1.5)
        #expect(lens.stops == [1])
    }

    @Test func aLensThatCannotZoomHasOneStop() {
        let lens = LensZoom(limits: 1...1, switchOvers: [], mainLens: 0)
        #expect(lens.range == 1...1)
        #expect(lens.stops == [1])
    }

    @Test func shownNumbersTurnIntoTheCamerasOwn() {
        let lens = LensZoom(limits: 1...123.75, switchOvers: [2], mainLens: 1)
        #expect(lens.cameraFactor(showing: 1) == 2)
        #expect(lens.cameraFactor(showing: 0.5) == 1)
        #expect(lens.cameraFactor(showing: 3) == 6)
        // Out of reach either way.
        #expect(lens.cameraFactor(showing: 0.1) == 1)
        #expect(lens.cameraFactor(showing: 50) == 20)
    }

    @Test func theScreenIsToldWhereTheCameraSits() {
        let lens = LensZoom(limits: 1...123.75, switchOvers: [2], mainLens: 1)
        #expect(lens.zoom(atCameraFactor: 2) == CameraZoom(factor: 1, range: 0.5...10, stops: [0.5, 1, 2]))
        #expect(lens.zoom(atCameraFactor: 1).factor == 0.5)
        #expect(lens.zoom(atCameraFactor: 100).factor == 10)
    }

    @Test func aMainLensThatIsNotAmongTheLensesCountsFromTheWidest() {
        let lens = LensZoom(limits: 1...8, switchOvers: [2], mainLens: 5)
        #expect(lens.multiplier == 1)
        #expect(lens.stops == [1, 2])
    }
}

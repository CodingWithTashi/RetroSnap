import SwiftUI
import Testing
@testable import Retrosnap

@MainActor
struct SharedControlTests {
    @Test func aDragIsASwipeOnlyPastFortyPoints() {
        #expect(SwipeDirection(translation: 40) == nil)
        #expect(SwipeDirection(translation: -40) == nil)
        #expect(SwipeDirection(translation: 0) == nil)
        #expect(SwipeDirection(translation: 40.5) == .right)
        #expect(SwipeDirection(translation: -41) == .left)
        #expect(SwipeDirection.left.step == 1)
        #expect(SwipeDirection.right.step == -1)
        #expect(SwipeDirection(.increment) == .left)
        #expect(SwipeDirection(.decrement) == .right)
    }

    @Test func photoActionsThatOpenAScreenRouteToIt() {
        #expect(PhotoAction.edit.route(for: "p") == .edit("p"))
        #expect(PhotoAction.print.route(for: "p") == .print("p"))
        #expect(PhotoAction.collage.route(for: "p") == .collage(seed: "p"))
        #expect(PhotoAction.share.route(for: "p") == nil)
        #expect(PhotoAction.delete.route(for: "p") == nil)
    }

    @Test func captureModesAreTitledPhotoAndVideo() {
        #expect(CaptureMode.allCases.map(\.title) == ["Photo", "Video"])
    }

    @Test func aPickTurnedDownIsDiscardedOnTheChosenCamera() {
        let world = TestWorld()
        world.importer.pickDraft(on: .digicam, accept: { _ in false }, failed: {})
        world.importer.deliver(.imported(world.draft("d1")))
        #expect(world.importer.discarded.map(\.camera) == [.digicam])
    }
}

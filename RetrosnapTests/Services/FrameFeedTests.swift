import CoreGraphics
import Testing
@testable import Retrosnap

@MainActor
struct FrameFeedTests {
    private let feed = FrameFeed()

    /// A one-pixel picture; each call makes a different object.
    private func frame() -> CGImage {
        makeCGImage(width: 1, height: 1)
    }

    /// Lets the main actor run what a submitted frame queued on it.
    private func settle() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    @Test func itStartsWithNoPicture() {
        #expect(feed.frame == nil)
        #expect(!feed.hasFrame)
    }

    @Test func showingAFrameDrawsItAtOnce() {
        let first = frame()
        feed.show(first)
        #expect(feed.frame === first)
        #expect(feed.hasFrame)
    }

    @Test func showingNothingClearsThePicture() {
        feed.show(frame())
        feed.show(nil)
        #expect(feed.frame == nil)
        #expect(!feed.hasFrame)
    }

    @Test func aSubmittedFrameReachesTheScreen() async {
        let first = frame()
        feed.submit(first)
        await settle()
        #expect(feed.frame === first)
        #expect(feed.hasFrame)
    }

    @Test func framesThatArriveFasterThanTheScreenTakesThemAreSkipped() async {
        let frames = [frame(), frame(), frame()]
        frames.forEach(feed.submit)
        // Nothing is drawn until the main actor gets to it, and then only the newest.
        #expect(feed.frame == nil)
        await settle()
        #expect(feed.frame === frames[2])
    }

    @Test func theFeedKeepsFollowingItsSource() async {
        feed.submit(frame())
        await settle()
        let next = frame()
        feed.submit(next)
        await settle()
        #expect(feed.frame === next)
    }
}

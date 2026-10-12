import Testing
@testable import Retrosnap

@MainActor
struct ToastCenterTests {
    private let scheduler = ManualScheduler()
    private let toasts: ToastCenter

    init() {
        toasts = ToastCenter(scheduler: scheduler)
    }

    @Test func startsEmpty() {
        #expect(toasts.current == nil)
    }

    @Test func showPresentsTheText() {
        toasts.show("Saved to Photos")
        #expect(toasts.current?.text == "Saved to Photos")
        #expect(toasts.current?.actionTitle == nil)
    }

    @Test func disappearsAfterTwoPointEightSeconds() {
        toasts.show("Saved to Photos")
        scheduler.advance(by: .milliseconds(2799))
        #expect(toasts.current != nil)
        scheduler.advance(by: .milliseconds(1))
        #expect(toasts.current == nil)
    }

    @Test func aNewToastReplacesTheOldOneAndRestartsTheClock() {
        toasts.show("First")
        scheduler.advance(by: .seconds(2))
        toasts.show("Second")
        scheduler.advance(by: .seconds(2))
        #expect(toasts.current?.text == "Second")
        scheduler.advance(by: .milliseconds(800))
        #expect(toasts.current == nil)
    }

    @Test func eachToastHasItsOwnIdentity() {
        toasts.show("Same")
        let first = toasts.current?.id
        toasts.show("Same")
        #expect(toasts.current?.id != first)
    }

    @Test func actionRunsOnceAndClearsTheToast() {
        var undone = 0
        toasts.show("Photo deleted", actionTitle: "Undo") { undone += 1 }
        #expect(toasts.current?.actionTitle == "Undo")

        toasts.performAction()
        #expect(undone == 1)
        #expect(toasts.current == nil)

        toasts.performAction()
        #expect(undone == 1)
    }

    @Test func actionIsGoneOnceTheToastTimesOut() {
        var undone = 0
        toasts.show("Photo deleted", actionTitle: "Undo") { undone += 1 }
        scheduler.advance(by: .seconds(3))
        toasts.performAction()
        #expect(undone == 0)
    }

    @Test func dismissClearsImmediatelyAndCancelsTheTimer() {
        toasts.show("Saved")
        toasts.dismiss()
        #expect(toasts.current == nil)
        #expect(scheduler.pendingCount == 0)
    }

    @Test func aReplacedToastsTimerCannotDismissItsSuccessor() {
        toasts.show("First")
        scheduler.advance(by: .milliseconds(2700))
        toasts.show("Second")
        scheduler.advance(by: .milliseconds(200))
        #expect(toasts.current?.text == "Second")
    }
}

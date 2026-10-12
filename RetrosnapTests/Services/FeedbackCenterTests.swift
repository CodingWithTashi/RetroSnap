import Testing
@testable import Retrosnap

@MainActor
struct FeedbackCenterTests {
    private let spy = FeedbackSpy()
    private let settings = InMemorySettingsStore()
    private let feedback: FeedbackCenter

    init() {
        feedback = FeedbackCenter(output: spy, settings: settings)
    }

    @Test func passesHapticsAndClicksThroughByDefault() {
        feedback.haptic(.firm)
        feedback.shutterClick()
        #expect(spy.haptics == [.firm])
        #expect(spy.clicks == 1)
    }

    @Test func hapticsSettingSilencesHapticsOnly() {
        settings.haptics = false
        feedback.haptic(.tick)
        feedback.shutterClick()
        #expect(spy.haptics.isEmpty)
        #expect(spy.clicks == 1)
    }

    @Test func shutterSoundSettingSilencesTheClickOnly() {
        settings.shutterSound = false
        feedback.haptic(.soft)
        feedback.shutterClick()
        #expect(spy.haptics == [.soft])
        #expect(spy.clicks == 0)
    }

    @Test func hapticsAndTheClickAreMadeReadyAhead() {
        feedback.prepare(click: true)
        #expect(spy.hapticPrepareCount == 1)
        #expect(spy.clickPrepareCount == 1)
    }

    @Test func theClickIsLeftAloneWhenNoneWillFollow() {
        feedback.prepare(click: false)
        #expect(spy.hapticPrepareCount == 1)
        #expect(spy.clickPrepareCount == 0)
    }

    @Test func nothingIsMadeReadyForWhatIsTurnedOff() {
        settings.haptics = false
        feedback.prepare(click: true)
        #expect(spy.hapticPrepareCount == 0)
        #expect(spy.clickPrepareCount == 1)

        settings.shutterSound = false
        feedback.prepare(click: true)
        #expect(spy.clickPrepareCount == 1)
    }
}

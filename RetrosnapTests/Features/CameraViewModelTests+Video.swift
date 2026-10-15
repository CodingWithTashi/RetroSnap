import Testing
@testable import Retrosnap

extension CameraViewModelTests {
    /// Recording a clip.
    @MainActor
    struct Video: CameraViewModelSuite {
        let world = TestWorld()

        // MARK: Video

        @Test func videoShutterStartsRecordingAndIgnoresTheTimer() {
            let vm = returning()
            vm.timerTapped()
            vm.chipTapped()
            vm.select(.video)
            vm.shutterTapped()
            #expect(vm.isRecording)
            #expect(vm.countdown == 0)
            #expect(vm.recordedSeconds == 0)
            #expect(vm.recordingClock == "00:00")
            #expect(vm.shutterAppearance == .recording)
            #expect(vm.shutterLabel == "Stop recording")
            #expect(!vm.isStripVisible)
            #expect(!vm.isChipVisible)
            #expect(world.feedbackSpy.haptics.last == .firm)
        }

        @Test func recordingClockTicksEverySecond() {
            let vm = returning()
            vm.select(.video)
            vm.shutterTapped()
            world.scheduler.advance(by: .seconds(3))
            #expect(vm.recordedSeconds == 3)
            #expect(vm.recordingClock == "00:03")
            world.scheduler.advance(by: .seconds(72))
            #expect(vm.recordingClock == "01:15")
        }

        @Test func stoppingSavesTheClipAndOpensTheResultStraightAway() throws {
            let vm = returning()
            vm.pick(.camcorder)
            vm.select(.video)
            vm.shutterTapped()
            world.scheduler.advance(by: .seconds(12))
            vm.shutterTapped()

            let clip = try #require(world.photos.photos.first)
            #expect(clip.isVideo)
            #expect(clip.videoDurationText == "0:12")
            #expect(clip.camera == .camcorder)
            #expect(!vm.isRecording)
            #expect(vm.shutterAppearance == .video)
            #expect(world.router.path == [.result(clip.id)])

            world.scheduler.advance(by: .seconds(5))
            #expect(vm.recordedSeconds == 12)
        }

        @Test func aClipIsAtLeastOneSecond() {
            let vm = returning()
            vm.select(.video)
            vm.shutterTapped()
            vm.shutterTapped()
            #expect(world.photos.photos.first?.videoDurationText == "0:01")
        }

        @Test func nothingElseCanBeChangedWhileRecording() {
            let vm = returning()
            vm.select(.video)
            vm.shutterTapped()

            vm.galleryTapped()
            vm.chipTapped()
            vm.viewfinderSwiped(.left)
            vm.select(.photo)
            vm.pick(.digicam)
            vm.flipTapped()

            #expect(world.router.path.isEmpty)
            #expect(!vm.isStripVisible)
            #expect(vm.style == .film)
            #expect(vm.mode == .video)
            #expect(vm.scene == .sceneBack)
            #expect(vm.isRecording)
        }

        @Test func recordingBoardPresetShowsTwelveSeconds() {
            let vm = returning(preset: .init(mode: .video, recordedSeconds: 12))
            #expect(vm.isRecording)
            #expect(vm.recordingClock == "00:12")
            #expect(vm.shutterAppearance == .recording)
        }
    }
}

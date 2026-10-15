import Testing
@testable import Retrosnap

@MainActor
struct CameraViewModelTests: CameraViewModelSuite {
    let world = TestWorld()

    // MARK: Opening state

    @Test func opensOnTheLastCameraWithDefaults() {
        world.settings.lastCamera = .instant
        let vm = returning()
        #expect(vm.style == .instant)
        #expect(vm.mode == .photo)
        #expect(vm.flash == .auto)
        #expect(vm.facing == .back)
        #expect(!vm.isTimerOn)
        #expect(vm.countdown == 0)
        #expect(!vm.isRecording)
        #expect(vm.scene == .sceneBack)
    }

    @Test func firstLaunchOpensTheStripWithItsOwnCopy() {
        let vm = make()
        #expect(vm.isFirstRun)
        #expect(vm.isStripVisible)
        #expect(!vm.isChipVisible)
        #expect(vm.stripTitle == "Choose a camera")
        #expect(vm.stripSubtitle == "D Classic is on. You can shoot right away.")
    }

    @Test func returningUserSeesTheChipNotTheStrip() {
        let vm = returning()
        #expect(!vm.isFirstRun)
        #expect(!vm.isStripVisible)
        #expect(vm.isChipVisible)
    }

    @Test func stripShowsTheCameraNameAndFirstSentenceAfterFirstRun() {
        let vm = returning()
        vm.chipTapped()
        #expect(vm.stripTitle == "D Classic")
        #expect(vm.stripSubtitle == "True, gently warm colour and a red date in the corner.")
    }

    // MARK: Choosing a camera

    @Test func pickingACameraSwitchesTheLookAndFoldsTheStrip() {
        let vm = make()
        vm.pick(.disposable)
        #expect(vm.style == .disposable)
        #expect(!vm.isStripVisible)
        #expect(vm.isChipVisible)
        #expect(!vm.isFirstRun)
        #expect(vm.styleChangeCount == 1)
        #expect(world.settings.lastCamera == .disposable)
        #expect(world.settings.hasSeenCameraIntro)
        #expect(world.feedbackSpy.haptics == [.soft])
    }

    @Test func pickingTheCurrentCameraOnlyFoldsTheStrip() {
        let vm = make()
        vm.pick(.film)
        #expect(vm.style == .film)
        #expect(!vm.isStripVisible)
        #expect(!vm.isFirstRun)
        #expect(vm.styleChangeCount == 0)
    }

    @Test func swipingTheViewfinderStepsThroughCamerasAndWraps() {
        let vm = returning()
        vm.viewfinderSwiped(.left)
        #expect(vm.style == .disposable)
        vm.viewfinderSwiped(.right)
        vm.viewfinderSwiped(.right)
        #expect(vm.style == CameraStyle.allCases.last)
        vm.viewfinderSwiped(.left)
        #expect(vm.style == .film)
        #expect(vm.styleChangeCount == 4)
    }

    @Test func chipOpensAndClosesTheStrip() {
        let vm = returning()
        vm.chipTapped()
        #expect(vm.isStripVisible)
        #expect(!vm.isChipVisible)
        vm.chipTapped()
        #expect(!vm.isStripVisible)
        #expect(world.feedbackSpy.haptics == [.tick, .tick])
    }

    @Test func tappingTheViewfinderFoldsTheStrip() {
        let vm = returning()
        vm.chipTapped()
        vm.viewfinderTapped()
        #expect(!vm.isStripVisible)
    }

    @Test func tappingTheViewfinderKeepsTheFirstRunStripOpen() {
        let vm = make()
        vm.viewfinderTapped()
        #expect(vm.isStripVisible)
        #expect(vm.isFirstRun)
    }

    @Test func closingTheStripEndsFirstRun() {
        let vm = make()
        vm.closeStripTapped()
        #expect(!vm.isStripVisible)
        #expect(!vm.isFirstRun)
        #expect(world.settings.hasSeenCameraIntro)
    }

    @Test func carouselSelectorOpensTheFullScreenPickerInstead() {
        let vm = returning(config: AppConfig(selector: .carousel))
        vm.chipTapped()
        #expect(world.router.path == [.cameraCarousel])
        #expect(!vm.isStripVisible)
    }

    @Test func pickingFromTheCarouselReturnsToTheCamera() {
        let vm = returning(config: AppConfig(selector: .carousel))
        vm.chipTapped()
        vm.pickFromCarousel(.digicam)
        #expect(vm.style == .digicam)
        #expect(world.router.path.isEmpty)
    }

    // MARK: Top controls

    @Test func flashCyclesAutoOnOff() {
        let vm = returning()
        #expect(vm.flashLabel == "Flash: auto")
        vm.flashTapped()
        #expect(vm.flash == .on)
        #expect(vm.flashLabel == "Flash: on")
        vm.flashTapped()
        #expect(vm.flash == .off)
        vm.flashTapped()
        #expect(vm.flash == .auto)
        #expect(world.feedbackSpy.haptics == [.tick, .tick, .tick])
    }

    @Test func timerToggles() {
        let vm = returning()
        #expect(vm.timerLabel == "Self-timer off")
        vm.timerTapped()
        #expect(vm.isTimerOn)
        #expect(vm.timerLabel == "Self-timer on, 3 seconds")
        vm.timerTapped()
        #expect(!vm.isTimerOn)
    }

    @Test func flashAndTimerOpenAsTheyWereLeft() {
        world.settings.flash = .off
        world.settings.isTimerOn = true
        let vm = returning()
        #expect(vm.flash == .off)
        #expect(vm.isTimerOn)
    }

    @Test func flashAndTimerAreRememberedAsTheyChange() {
        let vm = returning()
        vm.flashTapped()
        #expect(world.settings.flash == .on)
        vm.timerTapped()
        #expect(world.settings.isTimerOn)
        vm.timerTapped()
        #expect(!world.settings.isTimerOn)
    }

    @Test func theMicrophoneIsAskedForWhenVideoIsFirstChosen() {
        let permissions = PermissionSpy()
        let vm = returning(permissions: permissions)
        vm.flashTapped()
        vm.shutterTapped()
        #expect(permissions.microphoneRequestCount == 0)

        vm.select(.video)
        #expect(permissions.microphoneRequestCount == 1)
        vm.select(.photo)
        #expect(permissions.microphoneRequestCount == 1)
    }

    @Test func modeSwitchChangesTheShutter() {
        let vm = returning()
        #expect(vm.shutterAppearance == .photo)
        #expect(vm.shutterLabel == "Take photo")
        vm.select(.video)
        #expect(vm.mode == .video)
        #expect(vm.shutterAppearance == .video)
        #expect(vm.shutterLabel == "Start recording")
    }

    @Test func flipSwitchesTheLensAndTheScene() {
        let vm = returning()
        vm.flipTapped()
        #expect(vm.facing == .front)
        #expect(vm.scene == .sceneFront)
        vm.flipTapped()
        #expect(vm.facing == .back)
        #expect(world.feedbackSpy.haptics == [.soft, .soft])
    }

    @Test func chipDescribesTheCameraForVoiceOver() {
        #expect(returning().chipLabel == "Camera: D Classic. Change camera")
    }

    @Test func closingTheCarouselReturnsToTheCamera() {
        let vm = returning(config: AppConfig(selector: .carousel))
        vm.chipTapped()
        vm.closeCarouselTapped()
        #expect(world.router.path.isEmpty)
        #expect(vm.style == .film)
    }

    // MARK: VoiceOver labels

    @Test func viewfinderRecordingAndTimerDescribeThemselves() {
        #expect(returning().viewfinderLabel == "Viewfinder, D Classic")
        #expect(returning(preset: .init(mode: .video, recordedSeconds: 12)).recordingLabel == "Recording, 00:12")
        #expect(returning().timerBadge == "3s")
        #expect(CameraStyle.film.cardAccessibilityLabel(isSelected: true).hasSuffix(" Selected."))
        #expect(!CameraStyle.film.cardAccessibilityLabel(isSelected: false).hasSuffix(" Selected."))
    }

    // MARK: Gallery button

    @Test func galleryButtonOpensTheGalleryAndShowsTheNewestShot() {
        let vm = returning()
        #expect(vm.lastPhoto?.id == "s1")
        vm.galleryTapped()
        #expect(world.router.path == [.gallery])
    }

    @Test func galleryButtonIsEmptyWithNoPhotos() {
        let vm = make(in: TestWorld(photos: []))
        #expect(vm.lastPhoto == nil)
    }
}

import Testing
@testable import Retrosnap

@MainActor
struct CameraViewModelTests {
    private let world = TestWorld()

    /// A camera for someone who has been here before: no first-run strip, first photo already taken.
    private func returning(config: AppConfig = AppConfig(), preset: CameraViewModel.Preset = .init()) -> CameraViewModel {
        world.settings.hasSeenCameraIntro = true
        world.settings.hasTakenFirstPhoto = true
        return make(config: config, preset: preset)
    }

    private func make(config: AppConfig = AppConfig(), preset: CameraViewModel.Preset = .init()) -> CameraViewModel {
        CameraViewModel(
            config: config, photos: world.photos, camera: world.camera, permissions: world.permissions,
            storage: world.storage, settings: world.settings, feedback: world.feedback,
            router: world.router, toasts: world.toasts, scheduler: world.scheduler, preset: preset
        )
    }

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
        #expect(vm.stripSubtitle == "35mm Film is on. You can shoot right away.")
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
        #expect(vm.stripTitle == "35mm Film")
        #expect(vm.stripSubtitle == "Golden tones, fine grain and soft edges.")
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
        #expect(vm.style == .camcorder)
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
        #expect(returning().chipLabel == "Camera: 35mm Film. Change camera")
    }

    // MARK: Taking a photo

    @Test func firstPhotoIsSavedThenOpensTheResult() throws {
        let vm = make()
        vm.pick(.instant)
        vm.shutterTapped()

        let photo = try #require(world.photos.photos.first)
        #expect(world.photos.photos.count == 14)
        #expect(photo.camera == .instant)
        #expect(photo.image == .sceneBack)
        #expect(photo.isJustCaptured)
        #expect(!photo.isVideo)
        #expect(vm.lastPhoto == photo)
        #expect(vm.shotCount == 1)
        #expect(world.feedbackSpy.haptics.last == .firm)
        #expect(world.feedbackSpy.clicks == 1)
        #expect(world.settings.hasTakenFirstPhoto)
        #expect(world.toasts.current == nil)

        #expect(world.router.path.isEmpty)
        world.scheduler.advance(by: .milliseconds(419))
        #expect(world.router.path.isEmpty)
        world.scheduler.advance(by: .milliseconds(1))
        #expect(world.router.path == [.result(photo.id)])
    }

    @Test func shootingFromTheFirstRunStripClosesIt() {
        let vm = make()
        vm.shutterTapped()
        #expect(!vm.isStripVisible)
        #expect(!vm.isFirstRun)
        #expect(world.settings.hasSeenCameraIntro)
    }

    @Test func laterPhotosStayInTheCameraWithAToast() {
        let vm = returning()
        vm.shutterTapped()
        world.scheduler.advance(by: .seconds(1))
        #expect(world.router.path.isEmpty)
        #expect(world.toasts.current?.text == "Saved · 35mm Film")
        #expect(vm.shotCount == 1)
    }

    @Test func alwaysRuleOpensTheResultEveryTime() {
        let vm = returning(config: AppConfig(reviewRule: .always))
        vm.shutterTapped()
        world.scheduler.advance(by: .milliseconds(420))
        #expect(world.router.path.count == 1)
        #expect(world.toasts.current == nil)
    }

    @Test func neverRuleKeepsEvenTheFirstPhotoInTheCamera() {
        let vm = make(config: AppConfig(reviewRule: .never))
        vm.shutterTapped()
        world.scheduler.advance(by: .seconds(1))
        #expect(world.router.path.isEmpty)
        #expect(world.toasts.current?.text == "Saved · 35mm Film")
    }

    @Test func resultIsSkippedIfTheUserAlreadyOpenedTheGallery() {
        let vm = make()
        vm.shutterTapped()
        vm.galleryTapped()
        world.scheduler.advance(by: .seconds(1))
        #expect(world.router.path == [.gallery])
    }

    @Test func frontLensPhotosUseTheFrontScene() {
        let vm = returning()
        vm.flipTapped()
        vm.shutterTapped()
        #expect(world.photos.photos.first?.image == .sceneFront)
    }

    @Test func shutterSoundSettingMutesTheClick() {
        world.settings.shutterSound = false
        let vm = returning()
        vm.shutterTapped()
        #expect(world.feedbackSpy.clicks == 0)
        #expect(world.feedbackSpy.haptics == [.firm])
    }

    // MARK: Self-timer

    @Test func timerCountsThreeTwoOneThenShoots() {
        let vm = returning()
        vm.timerTapped()
        vm.shutterTapped()
        #expect(vm.countdown == 3)
        #expect(world.photos.photos.count == 13)

        world.scheduler.advance(by: .milliseconds(700))
        #expect(vm.countdown == 2)
        world.scheduler.advance(by: .milliseconds(700))
        #expect(vm.countdown == 1)
        world.scheduler.advance(by: .milliseconds(699))
        #expect(world.photos.photos.count == 13)
        world.scheduler.advance(by: .milliseconds(1))
        #expect(vm.countdown == 0)
        #expect(world.photos.photos.count == 14)
        // One tick for the timer button, one per beat, then the capture.
        #expect(world.feedbackSpy.haptics == [.tick, .tick, .tick, .tick, .firm])
    }

    @Test func shutterIsIgnoredWhileCountingDown() {
        let vm = returning()
        vm.timerTapped()
        vm.shutterTapped()
        vm.shutterTapped()
        world.scheduler.advance(by: .seconds(5))
        #expect(world.photos.photos.count == 14)
    }

    @Test func leavingForTheGalleryCancelsTheCountdown() {
        let vm = returning()
        vm.timerTapped()
        vm.shutterTapped()
        vm.galleryTapped()
        world.scheduler.advance(by: .seconds(5))
        #expect(vm.countdown == 0)
        #expect(world.photos.photos.count == 13)
        #expect(world.router.path == [.gallery])
    }

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

        #expect(world.router.path.isEmpty)
        #expect(!vm.isStripVisible)
        #expect(vm.style == .film)
        #expect(vm.mode == .video)
        #expect(vm.isRecording)
    }

    @Test func recordingBoardPresetShowsTwelveSeconds() {
        let vm = returning(preset: .init(mode: .video, recordedSeconds: 12))
        #expect(vm.isRecording)
        #expect(vm.recordingClock == "00:12")
        #expect(vm.shutterAppearance == .recording)
    }

    // MARK: Banners

    @Test func photosAccessOffShowsABannerThatCanAllowIt() throws {
        world.permissions.declinePhotoLibraryAccess()
        let vm = returning()
        let banner = try #require(vm.bannerContent)
        #expect(vm.banner == .library)
        #expect(banner.title == "Saving inside RetroSnap only")
        #expect(banner.message == "Allow Photos access to also save to your library.")
        #expect(banner.actionTitle == "Allow")

        vm.bannerActionTapped()
        #expect(vm.banner == nil)
        #expect(world.permissions.photoLibraryAccess == .granted)
        #expect(world.toasts.current?.text == "Saving to Photos")
    }

    @Test func lowStorageShowsABannerThatCanBeDismissedByManaging() throws {
        world.storage.isLow = true
        let vm = returning()
        let banner = try #require(vm.bannerContent)
        #expect(vm.banner == .storage)
        #expect(banner.title == "Your phone is almost full")
        #expect(banner.message == "About 40 photos left. Free up space to keep shooting.")
        #expect(banner.actionTitle == "Manage")

        vm.bannerActionTapped()
        #expect(vm.banner == nil)
        #expect(world.toasts.current?.text == "Opening Storage")
    }

    @Test func photosBannerComesBeforeStorage() {
        world.permissions.declinePhotoLibraryAccess()
        world.storage.isLow = true
        let vm = returning()
        #expect(vm.banner == .library)
        vm.bannerActionTapped()
        #expect(vm.banner == .storage)
    }

    @Test func shootingStillWorksUnderABanner() {
        world.storage.isLow = true
        let vm = returning()
        vm.shutterTapped()
        #expect(world.photos.photos.count == 14)
    }

    // MARK: Blocked camera

    @Test func deniedCameraBlocksShootingAndOffersSettings() throws {
        let world = TestWorld()
        world.settings.hasSeenCameraIntro = true
        let camera = MockCameraService(clock: world.clock, availability: .denied)
        world.storage.isLow = true
        let vm = CameraViewModel(
            config: AppConfig(), photos: world.photos, camera: camera, permissions: world.permissions,
            storage: world.storage, settings: world.settings, feedback: world.feedback,
            router: world.router, toasts: world.toasts, scheduler: world.scheduler
        )
        let block = try #require(vm.blockContent)
        #expect(vm.block == .denied)
        #expect(block.title == "Camera access is off")
        #expect(block.message == "Turn on Camera for RetroSnap in\nSettings to start shooting.")
        #expect(block.actionTitle == "Open Settings")
        #expect(!vm.isShutterEnabled)
        #expect(vm.banner == nil)

        vm.chipTapped()
        #expect(!vm.isStripVisible)

        vm.shutterTapped()
        vm.viewfinderSwiped(.left)
        #expect(world.photos.photos.count == 13)
        #expect(vm.style == .film)

        vm.blockActionTapped()
        #expect(vm.block == nil)
        #expect(vm.isShutterEnabled)
        #expect(world.toasts.current?.text == "Camera is on")
        #expect(vm.banner == .storage)
    }

    @Test func busyCameraOffersTryAgain() throws {
        let world = TestWorld()
        let camera = MockCameraService(clock: world.clock, availability: .busy)
        let vm = CameraViewModel(
            config: AppConfig(), photos: world.photos, camera: camera, permissions: world.permissions,
            storage: world.storage, settings: world.settings, feedback: world.feedback,
            router: world.router, toasts: world.toasts, scheduler: world.scheduler
        )
        let block = try #require(vm.blockContent)
        #expect(block.title == "Camera is busy")
        #expect(block.message == "Another app is using the camera.\nClose it, then try again.")
        #expect(block.actionTitle == "Try again")

        vm.blockActionTapped()
        #expect(vm.block == nil)
        #expect(world.toasts.current?.text == "Camera ready")
    }

    // MARK: Gallery button

    @Test func galleryButtonOpensTheGalleryAndShowsTheNewestShot() {
        let vm = returning()
        #expect(vm.lastPhoto?.id == "s1")
        vm.galleryTapped()
        #expect(world.router.path == [.gallery])
    }

    @Test func galleryButtonIsEmptyWithNoPhotos() {
        let world = TestWorld(photos: [])
        let vm = CameraViewModel(
            config: AppConfig(), photos: world.photos, camera: world.camera, permissions: world.permissions,
            storage: world.storage, settings: world.settings, feedback: world.feedback,
            router: world.router, toasts: world.toasts, scheduler: world.scheduler
        )
        #expect(vm.lastPhoto == nil)
    }
}

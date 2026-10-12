import Testing
@testable import Retrosnap

@MainActor
struct CameraViewModelTests {
    private let world = TestWorld()

    /// A camera for someone who has been here before: no first-run strip, first photo already taken.
    private func returning(
        config: AppConfig = AppConfig(), preset: CameraViewModel.Preset = .init(),
        camera: (any CameraServicing)? = nil, permissions: (any PermissionServicing)? = nil,
        location: (any LocationProviding)? = nil, storage: (any StorageMonitoring)? = nil
    ) -> CameraViewModel {
        world.settings.hasSeenCameraIntro = true
        world.settings.hasTakenFirstPhoto = true
        return make(
            config: config, preset: preset, camera: camera, permissions: permissions, location: location,
            storage: storage
        )
    }

    private func make(
        config: AppConfig = AppConfig(), preset: CameraViewModel.Preset = .init(),
        camera: (any CameraServicing)? = nil, permissions: (any PermissionServicing)? = nil,
        location: (any LocationProviding)? = nil, storage: (any StorageMonitoring)? = nil
    ) -> CameraViewModel {
        CameraViewModel(
            config: config, photos: world.photos, camera: camera ?? world.camera,
            permissions: permissions ?? world.permissions,
            storage: storage ?? world.storage, settings: world.settings, feedback: world.feedback, saver: world.saver,
            location: location ?? world.location,
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
        #expect(returning().chipLabel == "Camera: 35mm Film. Change camera")
    }

    // MARK: Zoom

    @Test func theCameraOpensOnTheMainLens() {
        let vm = returning()
        #expect(vm.zoomTitle == "1×")
        #expect(vm.zoomLabel == "Zoom: 1×")
        #expect(!vm.isZoomed)
        #expect(vm.isZoomVisible)
        #expect(vm.sceneMagnification == 1)
    }

    @Test func theZoomButtonStepsThroughTheLensesAndRoundAgain() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.zoomTapped()
        #expect(vm.zoomTitle == "2×")
        #expect(vm.isZoomed)
        vm.zoomTapped()
        #expect(vm.zoomTitle == "0.5×")
        #expect(vm.isZoomed)
        vm.zoomTapped()
        #expect(vm.zoomTitle == "1×")
        #expect(!vm.isZoomed)
        #expect(camera.zooms == [
            .init(factor: 2, smoothly: true), .init(factor: 0.5, smoothly: true), .init(factor: 1, smoothly: true),
        ])
        #expect(world.feedbackSpy.haptics == [.tick, .tick, .tick])
    }

    @Test func aPinchZoomsFromWhereItStarted() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.viewfinderPinched(1.5)
        #expect(camera.zoom.factor == 1.5)
        // Still the same pinch: measured from where the fingers came down, not from the last report.
        vm.viewfinderPinched(1.8)
        #expect(camera.zoom.factor == 1.8)
        #expect(vm.zoomLabel == "Zoom: 1.8×")
        #expect(camera.zooms.allSatisfy { !$0.smoothly })

        vm.viewfinderPinchEnded()
        vm.viewfinderPinched(0.5)
        #expect(camera.zoom.factor == 0.9)
    }

    @Test func aPinchStopsAtTheEndsOfTheRange() {
        let vm = returning(camera: CameraSpy())
        vm.viewfinderPinched(40)
        #expect(vm.zoomTitle == "10×")
        vm.viewfinderPinchEnded()
        vm.viewfinderPinched(0.001)
        #expect(vm.zoomTitle == "0.5×")
    }

    @Test func aPinchLandsOnALensItIsAllButOnWithATick() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.viewfinderPinched(1.5)
        #expect(world.feedbackSpy.haptics.isEmpty)
        vm.viewfinderPinched(1.97)
        #expect(camera.zoom.factor == 2)
        #expect(world.feedbackSpy.haptics == [.tick])

        // Staying there asks the camera for nothing more.
        vm.viewfinderPinched(1.98)
        #expect(world.feedbackSpy.haptics == [.tick])
        #expect(camera.zooms.count == 2)
    }

    @Test func pinchingThroughALensTicksOnce() {
        let vm = returning(camera: CameraSpy())
        vm.viewfinderPinched(0.8)
        #expect(world.feedbackSpy.haptics.isEmpty)
        vm.viewfinderPinched(1.3)
        #expect(world.feedbackSpy.haptics == [.tick])
        vm.viewfinderPinched(1.4)
        #expect(world.feedbackSpy.haptics == [.tick])
    }

    @Test func theZoomButtonHidesBehindTheStrip() {
        let vm = returning()
        vm.chipTapped()
        #expect(!vm.isZoomVisible)
        vm.chipTapped()
        #expect(vm.isZoomVisible)
    }

    @Test func thereIsNoZoomWithoutACamera() {
        let camera = CameraSpy()
        camera.availability = .busy
        let vm = returning(camera: camera)
        #expect(!vm.isZoomVisible)
        vm.zoomTapped()
        vm.viewfinderPinched(2)
        #expect(camera.zooms.isEmpty)
        #expect(world.feedbackSpy.haptics.isEmpty)
    }

    @Test func zoomStaysWhileRecording() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.select(.video)
        vm.shutterTapped()
        #expect(vm.isRecording)
        #expect(vm.isZoomVisible)
        vm.viewfinderPinched(3)
        #expect(camera.zoom.factor == 3)
    }

    @Test func aStillSceneIsEnlargedToShowTheZoomAndALiveOneIsNot() {
        let still = returning()
        still.zoomTapped()
        #expect(still.zoomTitle == "2×")
        #expect(still.sceneMagnification == 2)

        let live = returning(camera: CameraSpy())
        live.zoomTapped()
        #expect(live.sceneMagnification == 1)
    }

    @Test func theOtherLensStartsAtItsOwnOne() {
        let vm = returning()
        vm.zoomTapped()
        vm.flipTapped()
        #expect(vm.zoomTitle == "1×")
        #expect(vm.sceneMagnification == 1)
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

    // MARK: A real camera takes its time

    @Test func aPhotoLandsInTheLibraryWhenTheCameraDeliversIt() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.shutterTapped()

        // The shutter has reacted, but there is no photo yet.
        #expect(vm.shutterCount == 1)
        #expect(world.photos.photos.count == 13)
        #expect(world.toasts.current == nil)
        #expect(world.feedbackSpy.haptics == [.firm])

        camera.deliver(world.photo("fresh"))
        #expect(world.photos.photos.first?.id == "fresh")
        #expect(world.toasts.current?.text == "Saved · 35mm Film")
    }

    @Test func theShotCarriesTheLookTheLensAndTheFlash() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.pick(.digicam)
        vm.flipTapped()
        vm.flashTapped()
        vm.shutterTapped()
        #expect(camera.shots == [Shot(style: .digicam, facing: .front, flash: .on, location: nil)])
    }

    @Test func theShutterWaitsForThePhotoBeingTaken() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.shutterTapped()
        vm.shutterTapped()
        #expect(camera.shots.count == 1)

        camera.deliver(world.photo("first"))
        vm.shutterTapped()
        #expect(camera.shots.count == 2)
    }

    @Test func aPhotoThatCouldNotBeTakenSaysSoAndAddsNothing() {
        let camera = CameraSpy()
        let vm = make(camera: camera)
        vm.shutterTapped()
        camera.fail()

        #expect(world.photos.photos.count == 13)
        #expect(world.toasts.current?.text == "Couldn’t save the photo")
        #expect(!world.settings.hasTakenFirstPhoto)
        world.scheduler.advance(by: .seconds(1))
        #expect(world.router.path.isEmpty)

        // The shutter works again.
        vm.shutterTapped()
        #expect(camera.shots.count == 2)
    }

    @Test func theFirstPhotoStillOpensTheResultWhenItArrivesLate() {
        let camera = CameraSpy()
        let vm = make(camera: camera)
        vm.shutterTapped()
        world.scheduler.advance(by: .seconds(2))
        #expect(world.router.path.isEmpty)

        camera.deliver(world.photo("fresh"))
        world.scheduler.advance(by: CameraViewModel.reviewDelay)
        #expect(world.router.path == [.result("fresh")])
    }

    @Test func theShotIsOnItsWayUntilTheCameraDeliversIt() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.pick(.disposable)
        #expect(vm.pendingShot == nil)

        vm.shutterTapped()
        #expect(vm.pendingShot == .disposable)
        // It keeps the look it was taken with, whatever is picked meanwhile.
        vm.pick(.digicam)
        #expect(vm.pendingShot == .disposable)

        camera.deliver(world.photo("fresh", camera: .disposable))
        #expect(vm.pendingShot == nil)
    }

    @Test func aShotThatCouldNotBeTakenIsNoLongerOnItsWay() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.shutterTapped()
        camera.fail()
        #expect(vm.pendingShot == nil)
    }

    @Test func aFirstPhotoThatTakesLongerThanTheFlyInOpensTheResultAsItLands() {
        let camera = CameraSpy()
        let vm = make(camera: camera)
        vm.shutterTapped()
        world.scheduler.advance(by: CameraViewModel.reviewDelay)
        #expect(world.router.path.isEmpty)

        camera.deliver(world.photo("fresh"))
        #expect(world.router.path == [.result("fresh")])
    }

    @Test func aFirstPhotoThatLandsSoonerWaitsForTheFlyIn() {
        let camera = CameraSpy()
        let vm = make(camera: camera)
        vm.shutterTapped()
        world.scheduler.advance(by: .milliseconds(100))
        camera.deliver(world.photo("fresh"))
        world.scheduler.advance(by: .milliseconds(319))
        #expect(world.router.path.isEmpty)
        world.scheduler.advance(by: .milliseconds(1))
        #expect(world.router.path == [.result("fresh")])
    }

    @Test func aFirstPhotoThatLandsAfterTheGalleryWasOpenedIsNotReviewed() {
        let camera = CameraSpy()
        let vm = make(camera: camera)
        vm.shutterTapped()
        vm.galleryTapped()
        camera.deliver(world.photo("fresh"))
        world.scheduler.advance(by: .seconds(1))
        #expect(world.router.path == [.gallery])
        #expect(world.photos.photos.first?.id == "fresh")
    }

    @Test func aReviewThatWasWalkedAwayFromIsNotShownForTheNextShot() {
        let camera = CameraSpy()
        let vm = make(camera: camera)
        vm.shutterTapped()
        vm.galleryTapped()
        camera.deliver(world.photo("first"))
        world.router.back()

        vm.shutterTapped()
        world.scheduler.advance(by: CameraViewModel.reviewDelay)
        #expect(world.router.path.isEmpty)
    }

    @Test func feedbackIsMadeReadyBeforeItIsWanted() {
        let vm = returning()
        vm.appeared()
        #expect(world.feedbackSpy.hapticPrepareCount == 1)
        #expect(world.feedbackSpy.clickPrepareCount == 1)
        vm.shutterPressed()
        #expect(world.feedbackSpy.hapticPrepareCount == 2)
        #expect(world.feedbackSpy.clickPrepareCount == 2)
        #expect(world.feedbackSpy.haptics.isEmpty)
        #expect(world.feedbackSpy.clicks == 0)
    }

    @Test func theClickIsMadeReadyForPhotosAndNotForVideo() {
        // Whether iOS clicks instead is not known before the camera runs, so the app's click is readied anyway.
        let camera = CameraSpy()
        camera.playsSystemShutterSound = true
        let photo = returning(camera: camera)
        photo.shutterPressed()
        #expect(world.feedbackSpy.clickPrepareCount == 1)

        let video = returning()
        video.select(.video)
        video.shutterPressed()
        #expect(world.feedbackSpy.clickPrepareCount == 1)
        #expect(world.feedbackSpy.hapticPrepareCount == 2)
    }

    @Test func theAppsClickStaysSilentWhereIOSMakesItsOwn() {
        let camera = CameraSpy()
        camera.playsSystemShutterSound = true
        let vm = returning(camera: camera)
        vm.shutterTapped()
        #expect(world.feedbackSpy.clicks == 0)
        #expect(world.feedbackSpy.haptics == [.firm])
    }

    @Test func recordingStartsOnTheCameraWithTheLookTheLensAndTheFlash() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.pick(.camcorder)
        vm.flashTapped()
        vm.select(.video)
        vm.shutterTapped()
        #expect(camera.recordings == [Shot(style: .camcorder, facing: .back, flash: .on, location: nil)])
        #expect(camera.shots.isEmpty)
    }

    @Test func stoppingHandsTheCameraTheLengthTheClockShowed() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.select(.video)
        vm.shutterTapped()
        world.scheduler.advance(by: .seconds(12))
        vm.shutterTapped()
        #expect(camera.finishedSeconds == [12])
        #expect(!vm.isRecording)
        #expect(world.photos.photos.count == 13)

        camera.deliver(world.photo("clip", camera: .film, video: 12))
        #expect(world.photos.photos.first?.id == "clip")
        #expect(world.router.path == [.result("clip")])
    }

    @Test func aClipIsSavedToPhotosLikeAPhoto() throws {
        let storage = StorageSpy()
        let vm = returning(storage: storage)
        vm.select(.video)
        vm.shutterTapped()
        vm.shutterTapped()
        let clip = try #require(world.photos.photos.first)
        #expect(clip.isVideo)
        #expect(world.exporter.savedIDs == [clip.id])
        #expect(storage.refreshCount == 1)
    }

    @Test func aClipIsTaggedWithThePlaceWhileLocationIsOn() {
        world.settings.locationOnPhotos = true
        let camera = CameraSpy()
        let vm = returning(camera: camera, location: LocationSpy(isAllowed: true, current: kathmandu))
        vm.select(.video)
        vm.shutterTapped()
        #expect(camera.recordings.first?.location == kathmandu)
    }

    @Test func aClipThatCouldNotBeSavedSaysSo() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.select(.video)
        vm.shutterTapped()
        world.scheduler.advance(by: .seconds(3))
        vm.shutterTapped()
        #expect(!vm.isRecording)
        camera.fail()
        #expect(world.photos.photos.count == 13)
        #expect(world.router.path.isEmpty)
        #expect(world.toasts.current?.text == "Couldn’t save the video")
    }

    // MARK: Running the camera

    @Test func theCameraRunsWhileItsScreenIsShowing() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        #expect(camera.startedFacings.isEmpty)

        vm.appeared()
        #expect(camera.startedFacings == [.back])
        vm.disappeared()
        #expect(camera.stopCount == 1)
        vm.appeared()
        #expect(camera.startedFacings == [.back, .back])
    }

    @Test func flippingSwitchesTheRunningCameraToTheOtherLens() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.appeared()
        vm.flipTapped()
        #expect(camera.startedFacings == [.back, .front])
        vm.disappeared()
        vm.appeared()
        #expect(camera.startedFacings == [.back, .front, .front])
    }

    @Test func choosingVideoRunsTheCameraForVideoOnceTheMicrophoneIsAnswered() {
        let camera = CameraSpy()
        let permissions = PermissionSpy()
        let vm = returning(camera: camera, permissions: permissions)
        vm.appeared()
        #expect(camera.startedModes == [.photo])

        vm.select(.video)
        #expect(camera.startedModes == [.photo])
        permissions.answerMicrophonePrompt()
        #expect(camera.startedModes == [.photo, .video])

        vm.select(.photo)
        #expect(camera.startedModes == [.photo, .video, .photo])
    }

    @Test func goingBackToPhotoBeforeTheMicrophoneIsAnsweredStaysOnPhoto() {
        let camera = CameraSpy()
        let permissions = PermissionSpy()
        let vm = returning(camera: camera, permissions: permissions)
        vm.select(.video)
        vm.select(.photo)
        permissions.answerMicrophonePrompt()
        #expect(camera.startedModes == [.photo])
    }

    @Test func theCameraComesBackInTheModeItWasLeftIn() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        vm.select(.video)
        vm.disappeared()
        vm.appeared()
        #expect(camera.startedModes == [.video, .video])
    }

    @Test func theViewfinderShowsWhatTheCameraSees() {
        #expect(returning(camera: CameraSpy()).scene == .live)
    }

    @Test func theViewfinderIsSettlingWhileTheCameraChangesLensOrMode() {
        let camera = CameraSpy()
        let vm = returning(camera: camera)
        #expect(!vm.isViewfinderSettling)
        camera.isSwitching = true
        #expect(vm.isViewfinderSettling)
    }

    @Test func comingBackToTheAppChecksPermissionsAgain() {
        let permissions = PermissionSpy()
        let vm = returning(permissions: permissions)
        vm.becameActive()
        #expect(permissions.refreshCount == 1)
    }

    // MARK: Location on photos

    private var kathmandu: PhotoLocation {
        PhotoLocation(latitude: 27.7172, longitude: 85.324, altitude: 1400)
    }

    @Test func aShotIsTaggedWithThePlaceWhileLocationIsOn() {
        world.settings.locationOnPhotos = true
        let vm = returning(location: LocationSpy(isAllowed: true, current: kathmandu))
        vm.shutterTapped()
        #expect(world.photos.photos.count == 14)
        #expect(world.photos.photos.first?.location == kathmandu)
    }

    @Test func aShotCarriesNoPlaceWhileLocationIsOff() {
        let camera = CameraSpy()
        let vm = returning(camera: camera, location: LocationSpy(isAllowed: true, current: kathmandu))
        vm.shutterTapped()
        #expect(camera.shots.first?.location == nil)
    }

    @Test func aShotIsStillTakenWhenThereIsNoFixYet() {
        world.settings.locationOnPhotos = true
        let vm = returning(location: LocationSpy(isAllowed: true, current: nil))
        vm.shutterTapped()
        #expect(world.photos.photos.count == 14)
        #expect(world.photos.photos.first?.location == nil)
    }

    @Test func locationIsFollowedOnlyWhileTheCameraShowsAndTheSettingIsOn() {
        let location = LocationSpy(isAllowed: true)
        let vm = returning(location: location)
        vm.appeared()
        #expect(!location.isRunning)
        vm.disappeared()

        world.settings.locationOnPhotos = true
        vm.appeared()
        #expect(location.isRunning)
        vm.disappeared()
        #expect(!location.isRunning)
    }

    // MARK: Saving to Photos

    @Test func aShotIsAlsoSavedToPhotosOnceAccessIsGiven() throws {
        let vm = returning()
        vm.shutterTapped()
        let photo = try #require(world.photos.photos.first)
        #expect(world.exporter.savedIDs == [photo.id])
    }

    @Test func aShotStaysInsideTheAppWhileSaveToPhotosIsOff() {
        world.settings.saveToPhotos = false
        let vm = returning()
        vm.shutterTapped()
        #expect(world.photos.photos.count == 14)
        #expect(world.exporter.savedIDs.isEmpty)
        #expect(world.toasts.current?.text == "Saved · 35mm Film")
    }

    @Test func aShotStaysInsideTheAppWithoutPhotosAccess() {
        world.permissions.declinePhotoLibraryAccess()
        let vm = returning()
        vm.shutterTapped()
        #expect(world.photos.photos.count == 14)
        #expect(world.exporter.savedIDs.isEmpty)
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
        #expect(world.router.path == [.gallery])
        #expect(world.toasts.current == nil)
    }

    @Test func theStorageBannerCountsThePhotosThatStillFit() throws {
        let storage = StorageSpy()
        storage.isLow = true
        storage.photosLeft = 12
        let vm = returning(storage: storage)
        #expect(try #require(vm.bannerContent).message == "About 12 photos left. Free up space to keep shooting.")
    }

    @Test func storageIsMeasuredAgainAfterEveryShotAndOnComingBack() {
        let storage = StorageSpy()
        let vm = returning(storage: storage)
        #expect(storage.refreshCount == 0)
        vm.shutterTapped()
        #expect(storage.refreshCount == 1)
        vm.becameActive()
        #expect(storage.refreshCount == 2)
    }

    @Test func thePhotosBannerStaysAwayOnceSavingIsTurnedOff() {
        world.permissions.declinePhotoLibraryAccess()
        world.settings.saveToPhotos = false
        let vm = returning()
        #expect(vm.banner == nil)
    }

    @Test func allowOnTheBannerConfirmsOnlyOnceAccessIsGiven() {
        let permissions = PermissionSpy(photoLibraryAccess: .denied)
        let vm = returning(permissions: permissions)
        #expect(vm.banner == .library)

        vm.bannerActionTapped()
        #expect(permissions.photoLibraryRequestCount == 1)
        #expect(vm.banner == nil)
        #expect(world.toasts.current == nil)

        permissions.answerPhotoLibraryPrompt(.granted)
        #expect(world.toasts.current?.text == "Saving to Photos")
    }

    @Test func allowOnTheBannerSaysNothingWhenAccessIsRefused() {
        let permissions = PermissionSpy(photoLibraryAccess: .denied)
        let vm = returning(permissions: permissions)
        vm.bannerActionTapped()
        permissions.answerPhotoLibraryPrompt(.denied)
        #expect(world.toasts.current == nil)
        #expect(vm.banner == nil)
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
            storage: world.storage, settings: world.settings, feedback: world.feedback, saver: world.saver,
            location: world.location,
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
            storage: world.storage, settings: world.settings, feedback: world.feedback, saver: world.saver,
            location: world.location,
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

    @Test func tryAgainConfirmsOnlyOnceTheCameraIsBack() {
        let camera = CameraSpy()
        camera.availability = .busy
        let vm = returning(camera: camera)
        vm.blockActionTapped()
        #expect(camera.recoverCount == 1)
        #expect(vm.block == .busy)
        #expect(world.toasts.current == nil)

        camera.comeBack()
        #expect(vm.block == nil)
        #expect(world.toasts.current?.text == "Camera ready")
    }

    @Test func openSettingsIsLeftToTheCameraAndSaysNothingByItself() {
        let camera = CameraSpy()
        camera.availability = .denied
        let vm = returning(camera: camera)
        vm.blockActionTapped()
        #expect(camera.recoverCount == 1)
        #expect(vm.block == .denied)
        #expect(world.toasts.current == nil)
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
            storage: world.storage, settings: world.settings, feedback: world.feedback, saver: world.saver,
            location: world.location,
            router: world.router, toasts: world.toasts, scheduler: world.scheduler
        )
        #expect(vm.lastPhoto == nil)
    }
}

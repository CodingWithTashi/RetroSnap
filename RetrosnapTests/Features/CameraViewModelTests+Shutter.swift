import Testing
@testable import Retrosnap

extension CameraViewModelTests {
    /// Taking a photo: the shutter, the self-timer, and a real camera that takes its time.
    @MainActor
    struct Shutter: CameraViewModelSuite {
        let world = TestWorld()

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
            #expect(world.toasts.current?.text == "Saved · D Classic")
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
            #expect(world.toasts.current?.text == "Saved · D Classic")
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
            #expect(world.toasts.current?.text == "Saved · D Classic")
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
            let vm = returning(camera: camera, location: LocationSpy(isAllowed: true, current: PhotoLocation.kathmandu))
            vm.select(.video)
            vm.shutterTapped()
            #expect(camera.recordings.first?.location == PhotoLocation.kathmandu)
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
    }
}

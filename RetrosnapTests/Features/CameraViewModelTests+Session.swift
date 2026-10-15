import Testing
@testable import Retrosnap

extension CameraViewModelTests {
    /// Running the camera, tagging shots with a place, and saving to Photos.
    @MainActor
    struct Session: CameraViewModelSuite {
        let world = TestWorld()

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

        @Test func aShotIsTaggedWithThePlaceWhileLocationIsOn() {
            world.settings.locationOnPhotos = true
            let vm = returning(location: LocationSpy(isAllowed: true, current: PhotoLocation.kathmandu))
            vm.shutterTapped()
            #expect(world.photos.photos.count == 14)
            #expect(world.photos.photos.first?.location == PhotoLocation.kathmandu)
        }

        @Test func aShotCarriesNoPlaceWhileLocationIsOff() {
            let camera = CameraSpy()
            let vm = returning(camera: camera, location: LocationSpy(isAllowed: true, current: PhotoLocation.kathmandu))
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
            #expect(world.toasts.current?.text == "Saved · D Classic")
        }

        @Test func aShotStaysInsideTheAppWithoutPhotosAccess() {
            world.permissions.declinePhotoLibraryAccess()
            let vm = returning()
            vm.shutterTapped()
            #expect(world.photos.photos.count == 14)
            #expect(world.exporter.savedIDs.isEmpty)
        }
    }
}

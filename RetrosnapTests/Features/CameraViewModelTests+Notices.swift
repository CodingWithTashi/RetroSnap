import Testing
@testable import Retrosnap

extension CameraViewModelTests {
    /// The banners and the blocked camera.
    @MainActor
    struct Notices: CameraViewModelSuite {
        let world = TestWorld()

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
            world.settings.hasSeenCameraIntro = true
            world.storage.isLow = true
            let vm = make(camera: MockCameraService(clock: world.clock, availability: .denied))
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
            let vm = make(camera: MockCameraService(clock: world.clock, availability: .busy))
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
    }
}

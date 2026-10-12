import Testing
@testable import Retrosnap

@MainActor
struct PhotosSaverTests {
    private let world = TestWorld()
    private let exporter = MockPhotoExporter()

    private func saver(_ access: PhotoLibraryAccess) -> PhotosSaver {
        PhotosSaver(
            exporter: exporter, permissions: MockPermissionService(photoLibraryAccess: access), settings: world.settings,
            toasts: world.toasts
        )
    }

    @Test func aShotGoesToPhotosOnceAccessIsGiven() {
        let saver = saver(.granted)
        #expect(saver.isSaving)
        saver.save(world.photo("a"))
        #expect(exporter.savedIDs == ["a"])
    }

    @Test func aShotStaysInTheAppBeforeAccessIsAsked() {
        let saver = saver(.notDetermined)
        #expect(!saver.isSaving)
        saver.save(world.photo("a"))
        #expect(exporter.savedIDs.isEmpty)
    }

    @Test func aShotStaysInTheAppAfterNotNow() {
        let saver = saver(.denied)
        saver.save(world.photo("a"))
        #expect(exporter.savedIDs.isEmpty)
    }

    @Test func aShotStaysInTheAppWhileSaveToPhotosIsOff() {
        world.settings.saveToPhotos = false
        let saver = saver(.granted)
        #expect(!saver.isSaving)
        saver.save(world.photo("a"))
        #expect(exporter.savedIDs.isEmpty)
        #expect(saver.savedText == "Saved in RetroSnap")

        world.settings.saveToPhotos = true
        saver.save(world.photo("b"))
        #expect(exporter.savedIDs == ["b"])
    }

    @Test func aShotThatReachesPhotosSaysNothingMore() {
        saver(.granted).save(world.photo("a"))
        #expect(world.toasts.current == nil)
    }

    @Test func aShotPhotosDoesNotTakeSaysSo() {
        let exporter = ExporterSpy()
        exporter.savesToPhotos = false
        let saver = PhotosSaver(
            exporter: exporter, permissions: MockPermissionService(photoLibraryAccess: .granted),
            settings: world.settings, toasts: world.toasts
        )
        saver.save(world.photo("a"))
        #expect(exporter.savedIDs == ["a"])
        #expect(world.toasts.current?.text == "Couldn’t save to Photos")
    }

    @Test func theConfirmationSaysWhereTheShotWent() {
        #expect(saver(.granted).savedText == "Saved to Photos")
        #expect(saver(.denied).savedText == "Saved in RetroSnap")
        #expect(saver(.notDetermined).savedText == "Saved in RetroSnap")
    }
}

import Foundation
import Testing
@testable import Retrosnap

@MainActor
final class DiskPhotoStoreTests {
    private static let undoWindow = Duration.seconds(4)

    private let folder = PhotoLibraryFolder(
        url: FileManager.default.temporaryDirectory.appendingPathComponent("DiskPhotoStoreTests-\(UUID().uuidString)")
    )
    private let scheduler = ManualScheduler()
    private let clock = FixedClock.design

    deinit {
        try? FileManager.default.removeItem(at: folder.url)
    }

    /// A store as the next launch would create it.
    private func relaunched() -> DiskPhotoStore {
        DiskPhotoStore(folder: folder, scheduler: scheduler, undoWindow: Self.undoWindow)
    }

    private func photo(_ id: String, camera: CameraStyle = .film) -> Photo {
        Photo(id: id, image: .photo(1011), camera: camera, capturedAt: clock.now)
    }

    /// A shot with its original and thumbnail on disk, as the camera leaves it.
    private func shot(_ id: String) throws -> Photo {
        let image = PhotoImage.file(full: "\(id).heic", thumbnail: "\(id)-thumb.jpg")
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        for name in image.fileNames {
            try Data(id.utf8).write(to: folder.url(for: name))
        }
        return Photo(id: id, image: image, camera: .instant, capturedAt: clock.now)
    }

    private func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.url(for: fileName).path)
    }

    // MARK: Surviving a relaunch

    @Test func aFirstLaunchHasNoPhotos() {
        #expect(relaunched().photos.isEmpty)
    }

    @Test func photosSurviveARelaunchNewestFirst() throws {
        let store = relaunched()
        store.add(photo("a"))
        store.add(try shot("b"))

        let next = relaunched()
        #expect(next.photos.map(\.id) == ["b", "a"])
        #expect(next.photo(id: "b")?.image == .file(full: "b.heic", thumbnail: "b-thumb.jpg"))
        #expect(next.photo(id: "b")?.camera == .instant)
        #expect(next.photo(id: "a")?.image == .photo(1011))
        #expect(next.photo(id: "a")?.capturedAt == clock.now)
    }

    @Test func editsSurviveARelaunch() {
        let store = relaunched()
        store.add(photo("a"))
        let edited = PhotoAdjustments(intensity: 80, grain: 64, exposure: 10, contrast: -12, warmth: 18)
        store.setAdjustments(edited, for: "a")
        #expect(relaunched().photo(id: "a")?.adjustments == edited)
    }

    @Test func locationAndClipLengthSurviveARelaunch() {
        let store = relaunched()
        var clip = photo("v", camera: .camcorder)
        clip.videoSeconds = 24
        clip.videoFile = "v.mov"
        clip.location = PhotoLocation(latitude: 27.7172, longitude: 85.324, altitude: 1400)
        store.add(clip)

        let saved = relaunched().photo(id: "v")
        #expect(saved?.videoSeconds == 24)
        #expect(saved?.videoFile == "v.mov")
        #expect(saved?.location == PhotoLocation(latitude: 27.7172, longitude: 85.324, altitude: 1400))
    }

    @Test func aCollageIsRememberedAsOne() {
        let store = relaunched()
        var collage = photo("c")
        collage.isCollage = true
        store.add(collage)
        store.add(photo("a"))
        let next = relaunched()
        #expect(next.photo(id: "c")?.isCollage == true)
        #expect(next.photo(id: "a")?.isCollage == false)
    }

    @Test func aLibrarySavedBeforeCollagesExistedStillOpens() throws {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let saved = #"""
        {"version":1,"photos":[{"id":"old","image":{"file":{"full":"old.heic","thumbnail":"old-thumb.jpg"}},
        "camera":"vhs","capturedAt":813400000,"adjustments":{"intensity":100,"grain":50,"exposure":0,"contrast":0,"warmth":0}}]}
        """#
        try Data(saved.utf8).write(to: folder.indexURL)
        let photo = try #require(relaunched().photo(id: "old"))
        #expect(photo.camera == .camcorder)
        #expect(!photo.isCollage)
        #expect(!photo.isVideo)
    }

    @Test func justNowDoesNotOutliveTheSession() {
        let store = relaunched()
        var fresh = photo("a")
        fresh.isJustCaptured = true
        store.add(fresh)
        #expect(store.photo(id: "a")?.isJustCaptured == true)
        #expect(relaunched().photo(id: "a")?.isJustCaptured == false)
    }

    @Test func aDeletedPhotoStaysDeletedAfterARelaunch() {
        let store = relaunched()
        store.add(photo("a"))
        store.add(photo("b"))
        store.delete(id: "a")
        #expect(relaunched().photos.map(\.id) == ["b"])
    }

    @Test func undoPutsThePhotoBackWhereItWasAndThatSurvivesARelaunch() throws {
        let store = relaunched()
        ["c", "b", "a"].forEach { store.add(photo($0)) }
        let deleted = try #require(store.delete(id: "b"))
        store.add(photo("new"))
        store.restore(deleted)
        #expect(store.photos.map(\.id) == ["new", "a", "b", "c"])
        #expect(relaunched().photos.map(\.id) == ["new", "a", "b", "c"])
    }

    // MARK: Files

    @Test func aDeletedShotKeepsItsFilesWhileUndoCanStillArrive() throws {
        let store = relaunched()
        store.add(try shot("a"))
        store.delete(id: "a")

        scheduler.advance(by: Self.undoWindow - .milliseconds(1))
        #expect(exists("a.heic") && exists("a-thumb.jpg"))
        scheduler.advance(by: .milliseconds(1))
        #expect(!exists("a.heic") && !exists("a-thumb.jpg"))
    }

    @Test func aDeletedClipLosesItsMovieWithItsPictures() throws {
        let store = relaunched()
        var clip = try shot("v")
        clip.videoSeconds = 12
        clip.videoFile = "v.mov"
        try Data("movie".utf8).write(to: folder.url(for: "v.mov"))
        store.add(clip)

        // A relaunch keeps the movie: it belongs to a clip in the library.
        _ = relaunched()
        #expect(exists("v.mov"))

        store.delete(id: "v")
        scheduler.advance(by: Self.undoWindow)
        #expect(!exists("v.mov") && !exists("v.heic") && !exists("v-thumb.jpg"))
    }

    @Test func undoKeepsTheFiles() throws {
        let store = relaunched()
        store.add(try shot("a"))
        let deleted = try #require(store.delete(id: "a"))
        store.restore(deleted)

        scheduler.advance(by: .seconds(60))
        #expect(exists("a.heic") && exists("a-thumb.jpg"))
        #expect(store.photos.map(\.id) == ["a"])
    }

    @Test func undoAfterTheFilesAreGoneBringsNothingBack() throws {
        let store = relaunched()
        store.add(try shot("a"))
        let deleted = try #require(store.delete(id: "a"))
        scheduler.advance(by: Self.undoWindow)

        store.restore(deleted)
        #expect(store.photos.isEmpty)
        #expect(relaunched().photos.isEmpty)
    }

    @Test func deletingOnePhotoLeavesTheOthersFilesAlone() throws {
        let store = relaunched()
        store.add(try shot("a"))
        store.add(try shot("b"))
        store.delete(id: "a")
        scheduler.advance(by: .seconds(60))
        #expect(exists("b.heic") && exists("b-thumb.jpg"))
    }

    @Test func filesLeftBehindByAnInterruptedDeleteAreClearedAtLaunch() throws {
        let store = relaunched()
        store.add(try shot("kept"))
        store.add(try shot("gone"))
        store.delete(id: "gone")

        // The app is closed before the files were removed.
        _ = relaunched()
        #expect(!exists("gone.heic") && !exists("gone-thumb.jpg"))
        #expect(exists("kept.heic") && exists("kept-thumb.jpg"))
        #expect(relaunched().photos.map(\.id) == ["kept"])
    }

    @Test func anUnreadableIndexStartsEmptyWithoutTouchingTheFiles() throws {
        _ = try shot("a")
        try Data("not json".utf8).write(to: folder.indexURL)

        let store = relaunched()
        #expect(store.photos.isEmpty)
        #expect(exists("a.heic") && exists("a-thumb.jpg"))
    }

    @Test func thePhotosOfAnUnreadableIndexOutliveLaterSavesAndLaunches() throws {
        _ = try shot("a")
        try Data("not json".utf8).write(to: folder.indexURL)

        // The library opens empty; a new shot starts a new index, and the old one is kept beside it.
        let store = relaunched()
        store.add(try shot("b"))
        #expect(try Data(contentsOf: folder.url(for: DiskPhotoStore.unreadableIndexFileName)) == Data("not json".utf8))

        // The launch after that would take "a" for a leftover: no photo in the new index owns it.
        let next = relaunched()
        #expect(next.photos.map(\.id) == ["b"])
        #expect(exists("a.heic") && exists("a-thumb.jpg"))
        #expect(exists("b.heic") && exists("b-thumb.jpg"))
    }

    @Test func leftoversAreStillClearedInALibraryThatWasAlwaysReadable() throws {
        let store = relaunched()
        store.add(try shot("a"))
        _ = try shot("stray")

        _ = relaunched()
        #expect(exists("a.heic"))
        #expect(!exists("stray.heic") && !exists("stray-thumb.jpg"))
    }
}

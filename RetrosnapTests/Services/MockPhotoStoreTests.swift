import Foundation
import Testing
@testable import Retrosnap

@MainActor
struct MockPhotoStoreTests {
    private let clock = FixedClock.design

    private func photo(_ id: String) -> Photo {
        Photo(id: id, image: .photo(1011), camera: .film, capturedAt: clock.now)
    }

    private func store(_ ids: String...) -> MockPhotoStore {
        MockPhotoStore(photos: ids.map(photo))
    }

    @Test func seedMatchesThePrototype() {
        let photos = SeedData.photos(clock: clock)
        #expect(photos.map(\.id) == (1...13).map { "s\($0)" })
        #expect(photos.prefix(4).map(\.camera) == [.film, .disposable, .instant, .camcorder])
        #expect(photos.allSatisfy { !$0.isVideo && !$0.isJustCaptured })

        let labeler = DayLabeler(clock: clock)
        #expect(photos.map { labeler.label(for: $0.capturedAt) } ==
            Array(repeating: "Today", count: 4) + Array(repeating: "Yesterday", count: 5) + Array(repeating: "October 4", count: 4))
    }

    @Test func newPhotosGoToTheFront() {
        let store = store("a", "b")
        store.add(photo("new"))
        #expect(store.photos.map(\.id) == ["new", "a", "b"])
    }

    @Test func findsAPhotoById() {
        let store = store("a", "b")
        #expect(store.photo(id: "b")?.id == "b")
        #expect(store.photo(id: "missing") == nil)
    }

    @Test func deleteRemovesAndReportsWhereItWas() {
        let store = store("a", "b", "c")
        let deleted = store.delete(id: "b")
        #expect(store.photos.map(\.id) == ["a", "c"])
        #expect(deleted?.photo.id == "b")
        #expect(deleted?.index == 1)
    }

    @Test func deletingAnUnknownPhotoDoesNothing() {
        let store = store("a")
        #expect(store.delete(id: "zzz") == nil)
        #expect(store.photos.count == 1)
    }

    @Test func restorePutsThePhotoBackWhereItWas() throws {
        let store = store("a", "b", "c")
        let deleted = try #require(store.delete(id: "b"))
        store.restore(deleted)
        #expect(store.photos.map(\.id) == ["a", "b", "c"])
    }

    @Test func restoreKeepsOrderWhenANewerPhotoArrivedMeanwhile() throws {
        let store = store("a", "b", "c")
        let deleted = try #require(store.delete(id: "a"))
        store.add(photo("new"))
        store.restore(deleted)
        #expect(store.photos.map(\.id) == ["new", "a", "b", "c"])
    }

    @Test func restoreOfTheLastPhotoGoesBackToTheEnd() throws {
        let store = store("a", "b")
        let deleted = try #require(store.delete(id: "b"))
        store.add(photo("new"))
        store.restore(deleted)
        #expect(store.photos.map(\.id) == ["new", "a", "b"])
    }

    @Test func restoreIntoAnEmptiedLibrary() throws {
        let store = store("only")
        let deleted = try #require(store.delete(id: "only"))
        store.restore(deleted)
        #expect(store.photos.map(\.id) == ["only"])
    }

    @Test func restoringTwiceDoesNotDuplicate() throws {
        let store = store("a", "b")
        let deleted = try #require(store.delete(id: "a"))
        store.restore(deleted)
        store.restore(deleted)
        #expect(store.photos.map(\.id) == ["a", "b"])
    }

    @Test func adjustmentsAreSavedOnThatPhotoOnly() {
        let store = store("a", "b")
        var edited = PhotoAdjustments.neutral
        edited.warmth = 18
        store.setAdjustments(edited, for: "b")
        #expect(store.photo(id: "b")?.adjustments == edited)
        #expect(store.photo(id: "a")?.adjustments == .neutral)
    }
}

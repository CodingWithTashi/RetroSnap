import Foundation
import Testing
@testable import Retrosnap

@MainActor
final class LiveStorageMonitorTests {
    private let folder = PhotoLibraryFolder(
        url: FileManager.default.temporaryDirectory.appendingPathComponent("LiveStorageMonitorTests-\(UUID().uuidString)")
    )

    init() throws {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder.url)
    }

    private func write(_ name: String, megabytes: Double) throws {
        try Data(count: Int(megabytes * 1_000_000)).write(to: folder.url(for: name))
    }

    // MARK: Space the library takes

    @Test func usedIsTheSizeOfEverythingInTheLibrary() async throws {
        try write("a.heic", megabytes: 2.5)
        try write("a-thumb.jpg", megabytes: 0.5)
        try write("b.heic", megabytes: 3)
        let monitor = LiveStorageMonitor(folder: folder)
        await monitor.measure()
        #expect(monitor.usedText == LiveStorageMonitor.text(forBytes: 6_000_000))
    }

    @Test func anEmptyLibraryTakesNothing() async {
        let monitor = LiveStorageMonitor(folder: folder)
        await monitor.measure()
        #expect(monitor.usedText == LiveStorageMonitor.text(forBytes: 0))
    }

    @Test func measuringAgainSeesWhatChanged() async throws {
        let monitor = LiveStorageMonitor(folder: folder)
        await monitor.measure()
        try write("a.heic", megabytes: 4)
        await monitor.measure()
        #expect(monitor.usedText == LiveStorageMonitor.text(forBytes: 4_000_000))
    }

    @Test func sizesReadAsTheDesignWritesThem() {
        #expect(LiveStorageMonitor.text(forBytes: 1_200_000_000) == "1.2 GB")
        #expect(LiveStorageMonitor.text(forBytes: 356_000_000) == "356 MB")
        #expect(LiveStorageMonitor.text(forBytes: 0) == "0 MB")
    }

    // MARK: Room left on the phone

    @Test func photosLeftIsFreeSpaceInPhotos() {
        #expect(LiveStorageMonitor.photosLeft(freeBytes: 120_000_000) == 40)
        #expect(LiveStorageMonitor.photosLeft(freeBytes: 64_000_000_000) == 21_333)
        #expect(LiveStorageMonitor.photosLeft(freeBytes: 0) == 0)
        #expect(LiveStorageMonitor.photosLeft(freeBytes: -5) == 0)
    }

    @Test func thePhoneIsAlmostFullWhenFewPhotosFit() {
        #expect(LiveStorageMonitor.isLow(photosLeft: 40))
        #expect(LiveStorageMonitor.isLow(photosLeft: 99))
        #expect(!LiveStorageMonitor.isLow(photosLeft: 100))
        #expect(!LiveStorageMonitor.isLow(photosLeft: 20_000))
    }

    @Test func thisPhoneHasRoomAndSaysHowMuch() async {
        let monitor = LiveStorageMonitor(folder: folder)
        await monitor.measure()
        #expect(monitor.photosLeft > 0)
        #expect(monitor.isLow == LiveStorageMonitor.isLow(photosLeft: monitor.photosLeft))
    }
}

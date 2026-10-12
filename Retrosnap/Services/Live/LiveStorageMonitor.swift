import Foundation
import Observation

/// How much room is left on the phone and how much the library takes, measured from the file system.
@Observable
final class LiveStorageMonitor: StorageMonitoring {
    /// What one more shot is taken to cost: a full-size original and its thumbnail.
    private nonisolated static let bytesPerPhoto: Int64 = 3_000_000
    /// With room for fewer photos than this, the phone counts as almost full.
    private nonisolated static let lowPhotoCount = 100

    private(set) var isLow = false
    private(set) var photosLeft = 0
    private(set) var usedText = LiveStorageMonitor.text(forBytes: 0)

    @ObservationIgnored private let folder: PhotoLibraryFolder

    init(folder: PhotoLibraryFolder) {
        self.folder = folder
        refresh()
    }

    func refresh() {
        Task {
            await measure()
        }
    }

    /// Reads the sizes off the main actor, then publishes them.
    func measure() async {
        let sizes = await Self.sizes(of: folder)
        usedText = Self.text(forBytes: sizes.used)
        photosLeft = Self.photosLeft(freeBytes: sizes.free)
        isLow = Self.isLow(photosLeft: photosLeft)
    }

    /// "1.2 GB", as the Settings row shows it.
    nonisolated static func text(forBytes bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }

    nonisolated static func photosLeft(freeBytes: Int64) -> Int {
        Int(max(0, freeBytes) / bytesPerPhoto)
    }

    nonisolated static func isLow(photosLeft: Int) -> Bool {
        photosLeft < lowPhotoCount
    }

    @concurrent
    private nonisolated static func sizes(of folder: PhotoLibraryFolder) async -> (used: Int64, free: Int64) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder.url, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        let used = files.reduce(into: Int64(0)) { total, file in
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        let volume = try? folder.url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return (used, volume?.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}

import Foundation
import Observation
import os

/// The photo library on disk: a JSON index, newest first, beside the photos' own files.
@Observable
final class DiskPhotoStore: PhotoStoring {
    /// The index file. The version lets a later format tell itself apart.
    private nonisolated struct Index: Codable {
        var version = 1
        var photos: [Photo]
    }

    private static let log = Logger.retroSnap("library")
    /// Where an index that could not be read is kept, so that nothing is written over it.
    static let unreadableIndexFileName = "library-unreadable.json"

    private var list: PhotoList

    @ObservationIgnored private let folder: PhotoLibraryFolder
    @ObservationIgnored private let scheduler: any Scheduling
    @ObservationIgnored private let undoWindow: Duration
    /// Deleted photos whose files are still on disk in case Undo brings them back.
    @ObservationIgnored private var pendingRemovals: [Photo.ID: any ScheduledWork] = [:]

    /// - Parameter undoWindow: How long a deleted photo's files are kept, so that Undo can still restore it.
    init(folder: PhotoLibraryFolder, scheduler: any Scheduling, undoWindow: Duration) {
        self.folder = folder
        self.scheduler = scheduler
        self.undoWindow = undoWindow

        let files = FileManager.default
        try? files.createDirectory(at: folder.url, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: folder.indexURL) else {
            list = PhotoList()
            return
        }
        do {
            list = PhotoList(try JSONDecoder().decode(Index.self, from: data).photos)
            removeFilesNoPhotoOwns()
        } catch {
            // Start empty, but leave every file in place: nothing here can say which ones are still wanted.
            Self.log.error("The library index could not be read: \(error.localizedDescription)")
            list = PhotoList()
            // Set aside, the index is not written over by the next save, and while it is there no later
            // launch takes its photos for leftovers.
            do {
                try files.moveItem(at: folder.indexURL, to: folder.url(for: Self.unreadableIndexFileName))
            } catch {
                Self.log.error("The unreadable index could not be set aside: \(error.localizedDescription)")
            }
        }
    }

    var photos: [Photo] {
        list.photos
    }

    func photo(id: Photo.ID) -> Photo? {
        list.photo(id: id)
    }

    func add(_ photo: Photo) {
        list.add(photo)
        saveIndex()
    }

    @discardableResult
    func delete(id: Photo.ID) -> DeletedPhoto? {
        guard let deleted = list.delete(id: id) else { return nil }
        saveIndex()
        pendingRemovals[id] = scheduler.after(undoWindow) { [weak self] in
            self?.removeFiles(of: deleted.photo)
        }
        return deleted
    }

    /// Does nothing once the photo's files are gone.
    func restore(_ deleted: DeletedPhoto) {
        guard let removal = pendingRemovals.removeValue(forKey: deleted.photo.id) else { return }
        removal.cancel()
        list.restore(deleted)
        saveIndex()
    }

    func setAdjustments(_ adjustments: PhotoAdjustments, for id: Photo.ID) {
        list.setAdjustments(adjustments, for: id)
        saveIndex()
    }

    // MARK: Disk

    private func saveIndex() {
        do {
            try JSONEncoder().encode(Index(photos: list.photos)).write(to: folder.indexURL, options: .atomic)
        } catch {
            Self.log.error("The library index could not be saved: \(error.localizedDescription)")
        }
    }

    private func removeFiles(of photo: Photo) {
        pendingRemovals[photo.id] = nil
        folder.removeFiles(named: photo.fileNames)
    }

    /// Clears what a delete or a capture left behind when the app closed before it finished.
    private func removeFilesNoPhotoOwns() {
        let files = FileManager.default
        guard !files.fileExists(atPath: folder.url(for: Self.unreadableIndexFileName).path) else { return }
        let owned = Set(list.photos.flatMap(\.fileNames)).union([PhotoLibraryFolder.indexFileName])
        let present = (try? files.contentsOfDirectory(atPath: folder.url.path)) ?? []
        folder.removeFiles(named: present.filter { !owned.contains($0) })
    }
}

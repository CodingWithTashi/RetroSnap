import Foundation
@testable import Retrosnap

/// An exporter whose collages are finished only when the test says so.
@MainActor
final class ExporterSpy: PhotoExporting {
    let progress: [Photo.ID: Double] = [:]
    private(set) var savedIDs: [Photo.ID] = []
    /// Whether Photos takes what it is given.
    var savesToPhotos = true
    private(set) var collages: [Collage] = []
    private var collageCompletion: (@MainActor (Photo?) -> Void)?

    func saveToPhotos(_ photo: Photo, completion: @escaping @MainActor (Bool) -> Void) {
        savedIDs.append(photo.id)
        completion(savesToPhotos)
    }

    func export(_ photo: Photo, completion: @escaping @MainActor (URL?) -> Void) {
        completion(nil)
    }

    func exportPrint(_ job: PrintJob, completion: @escaping @MainActor (URL?) -> Void) {
        completion(nil)
    }

    func exportCollage(_ collage: Collage, completion: @escaping @MainActor (URL?) -> Void) {
        completion(nil)
    }

    func makeCollage(_ collage: Collage, completion: @escaping @MainActor (Photo?) -> Void) {
        collages.append(collage)
        collageCompletion = completion
    }

    /// The pending collage is filed, or could not be made when nil.
    func deliver(_ photo: Photo?) {
        collageCompletion?(photo)
        collageCompletion = nil
    }
}

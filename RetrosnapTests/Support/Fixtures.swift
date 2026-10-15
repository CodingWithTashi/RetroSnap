import Foundation
@testable import Retrosnap

extension PhotoLocation {
    static let kathmandu = PhotoLocation(latitude: 27.7172, longitude: 85.324, altitude: 1400)
}

extension Photo {
    /// A plain shot of the seed picture, taken at `date`; a clip when `seconds` is given.
    static func fixture(_ id: Photo.ID, camera: CameraStyle = .film, at date: Date, video seconds: Int? = nil) -> Photo {
        Photo(id: id, image: .photo(1011), camera: camera, capturedAt: date, videoSeconds: seconds)
    }
}

extension PhotoLibraryFolder {
    /// A folder of its own in the temporary directory, for a suite that writes real files.
    static func temporary(for suite: String) -> PhotoLibraryFolder {
        PhotoLibraryFolder(url: FileManager.default.temporaryDirectory.appendingPathComponent("\(suite)-\(UUID().uuidString)"))
    }

    func removeFromDisk() {
        try? FileManager.default.removeItem(at: url)
    }
}

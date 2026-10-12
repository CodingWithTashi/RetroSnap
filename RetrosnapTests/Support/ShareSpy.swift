import Foundation
@testable import Retrosnap

/// A share sheet that only remembers which shots it was asked to share.
@MainActor
final class ShareSpy: PhotoSharing {
    private(set) var sharedIDs: [Photo.ID] = []
    private(set) var sharedCollages: [Collage] = []

    func share(_ photo: Photo) {
        sharedIDs.append(photo.id)
    }

    func share(_ collage: Collage) {
        sharedCollages.append(collage)
    }
}

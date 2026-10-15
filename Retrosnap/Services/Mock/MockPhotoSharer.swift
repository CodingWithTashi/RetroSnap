#if DEBUG
import Foundation

/// Stands in for the system share sheet by naming it, as the prototype does.
final class MockPhotoSharer: PhotoSharing {
    private static let message = "Share sheet opens here"

    private let toasts: ToastCenter

    init(toasts: ToastCenter) {
        self.toasts = toasts
    }

    func share(_ photo: Photo) {
        toasts.show(Self.message)
    }

    func share(_ collage: Collage) {
        toasts.show(Self.message)
    }
}
#endif

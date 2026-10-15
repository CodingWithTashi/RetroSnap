import Foundation

/// The onboarding steps, shown in order before the camera exists.
nonisolated enum OnboardingStep: Hashable, CaseIterable, Sendable {
    case welcome
    case howItWorks
    case cameraPermission
    case photosPermission
}

/// Every screen that can sit on top of the camera.
nonisolated enum Route: Hashable, Sendable {
    /// The full-screen camera picker (design option 1b).
    case cameraCarousel
    case result(Photo.ID)
    case gallery
    /// The photo the viewer opens on; paging happens inside the viewer.
    case viewer(Photo.ID)
    case edit(Photo.ID)
    case print(Photo.ID)
    /// The three collage steps are state inside the screen, not routes.
    case collage(seed: Photo.ID?)
    case settings
    /// A pick from the Photos library getting its look. The photo is a draft that is not in the library yet,
    /// so the screen carries it whole.
    case develop(Photo)
}

extension PhotoAction {
    /// The screen the action opens on the photo; nil for share and delete, which act in place.
    nonisolated func route(for id: Photo.ID) -> Route? {
        switch self {
        case .edit: .edit(id)
        case .print: .print(id)
        case .collage: .collage(seed: id)
        case .share, .delete: nil
        }
    }
}

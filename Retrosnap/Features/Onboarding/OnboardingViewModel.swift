import Foundation
import Observation

/// What one permission screen says.
nonisolated struct PermissionContent: Hashable, Sendable {
    let icon: RSIcon
    let title: String
    /// Line breaks are the design's.
    let message: String
    let actionTitle: String
    let offersNotNow: Bool
}

@Observable
final class OnboardingViewModel {
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let permissions: any PermissionServicing

    init(router: AppRouter, permissions: any PermissionServicing) {
        self.router = router
        self.permissions = permissions
    }

    private var step: OnboardingStep? {
        if case .onboarding(let step) = router.root { step } else { nil }
    }

    /// Continue on Welcome and How it works.
    func continueTapped() {
        guard step == .welcome || step == .howItWorks else { return }
        router.advanceOnboarding()
    }

    /// The amber button on a permission screen.
    func allowTapped() {
        switch step {
        case .cameraPermission:
            permissions.requestCameraAccess()
            router.advanceOnboarding()
        case .photosPermission:
            permissions.requestPhotoLibraryAccess()
            router.finishOnboarding()
        default:
            break
        }
    }

    /// "Not now" on the Photos screen: the camera still opens, photos stay inside the app.
    func notNowTapped() {
        guard step == .photosPermission else { return }
        permissions.declinePhotoLibraryAccess()
        router.finishOnboarding()
    }

    func permission(for step: OnboardingStep) -> PermissionContent {
        if step == .photosPermission {
            PermissionContent(
                icon: .photos,
                title: "Save to your photos",
                message: "Every shot is saved to your photo\nlibrary automatically. Nothing\nis ever uploaded.",
                actionTitle: "Allow Photos",
                offersNotNow: true
            )
        } else {
            PermissionContent(
                icon: .camera,
                title: "Allow camera access",
                message: "RetroSnap uses your camera\nto show the vintage look live\nand take your photos.",
                actionTitle: "Allow Camera",
                offersNotNow: false
            )
        }
    }
}

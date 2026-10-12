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
    @ObservationIgnored private let settings: any SettingsStoring
    /// A system prompt is up; the buttons wait for its answer.
    @ObservationIgnored private var isAsking = false

    init(router: AppRouter, permissions: any PermissionServicing, settings: any SettingsStoring) {
        self.router = router
        self.permissions = permissions
        self.settings = settings
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
        guard !isAsking else { return }
        switch step {
        case .cameraPermission:
            isAsking = true
            permissions.requestCameraAccess { [weak self] in
                self?.isAsking = false
                self?.router.advanceOnboarding()
            }
        case .photosPermission:
            isAsking = true
            permissions.requestPhotoLibraryAccess { [weak self] in
                self?.isAsking = false
                self?.finish()
            }
        default:
            break
        }
    }

    /// "Not now" on the Photos screen: the camera still opens, photos stay inside the app.
    func notNowTapped() {
        guard step == .photosPermission, !isAsking else { return }
        permissions.declinePhotoLibraryAccess()
        finish()
    }

    /// Opens the camera and remembers it, so onboarding is shown only once.
    private func finish() {
        settings.hasCompletedOnboarding = true
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

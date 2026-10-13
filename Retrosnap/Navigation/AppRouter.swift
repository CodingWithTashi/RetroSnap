import Foundation
import Observation

/// The single source of navigation state: which root is showing and what is stacked on the camera.
@Observable
final class AppRouter {
    nonisolated enum Root: Hashable, Sendable {
        case onboarding(OnboardingStep)
        case camera
    }

    private(set) var root: Root
    /// Bound to the one `NavigationStack`. Every method assigns it at most once.
    var path: [Route]

    init(root: Root = .onboarding(.welcome), path: [Route] = []) {
        self.root = root
        self.path = root == .camera ? path : []
    }

    /// An ordinary launch: onboarding until it has been finished once, the camera from then on.
    convenience init(hasCompletedOnboarding: Bool) {
        self.init(root: hasCompletedOnboarding ? .camera : .onboarding(.welcome))
    }

    var topRoute: Route? {
        path.last
    }

    // MARK: Onboarding

    func advanceOnboarding() {
        guard case .onboarding(let step) = root else { return }
        let steps = OnboardingStep.allCases
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        root = .onboarding(steps[index + 1])
    }

    func finishOnboarding() {
        root = .camera
        path = []
    }

    // MARK: Stack

    /// Pushes a screen. A repeat of the screen already on top (a double tap) is ignored.
    func push(_ route: Route) {
        guard root == .camera, path.last != route else { return }
        path.append(route)
    }

    func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func returnToCamera() {
        guard !path.isEmpty else { return }
        path = []
    }

    /// Goes to the gallery from anywhere: back to it when it is already open, otherwise straight to it.
    func returnToGallery() {
        if let index = path.firstIndex(of: .gallery) {
            path = Array(path.prefix(through: index))
        } else {
            path = [.gallery]
        }
    }

    /// Opens the result for a photo just taken. Dropped if the user has already left the camera.
    @discardableResult
    func showResult(_ id: Photo.ID) -> Bool {
        guard root == .camera, path.isEmpty else { return false }
        path = [.result(id)]
        return true
    }

    // MARK: Developing a pick from the library

    /// A result sits on the gallery when its photo was brought in from the library, and on the camera alone
    /// when it was just taken.
    var isResultOverGallery: Bool {
        path.contains(.gallery)
    }

    /// Leaves a result for where it came from: the gallery, or the camera.
    func closeResult() {
        if isResultOverGallery {
            returnToGallery()
        } else {
            returnToCamera()
        }
    }

    /// Opens the result for a pick just developed, in place of its develop screen. Dropped if that screen is gone.
    @discardableResult
    func showDevelopedResult(_ id: Photo.ID) -> Bool {
        guard case .develop = path.last else { return false }
        path[path.count - 1] = .result(id)
        return true
    }

    /// Opens the develop screen for the next pick, in place of the result it was asked for from.
    @discardableResult
    func showNextDevelop(_ draft: Photo) -> Bool {
        guard case .result = path.last else { return false }
        path[path.count - 1] = .develop(draft)
        return true
    }
}

import Foundation
@testable import Retrosnap

/// A location service whose prompt stays up until the test answers it, and whose fix the test sets.
@MainActor
final class LocationSpy: LocationProviding {
    var isAllowed: Bool
    var current: PhotoLocation?
    private(set) var requestCount = 0
    private(set) var isRunning = false
    private var completion: (@MainActor (Bool) -> Void)?

    init(isAllowed: Bool = false, current: PhotoLocation? = nil) {
        self.isAllowed = isAllowed
        self.current = current
    }

    func requestAccess(completion: @escaping @MainActor (Bool) -> Void) {
        requestCount += 1
        self.completion = completion
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    /// The location prompt is dismissed with this answer.
    func answerPrompt(_ allowed: Bool) {
        isAllowed = allowed
        completion?(allowed)
        completion = nil
    }
}

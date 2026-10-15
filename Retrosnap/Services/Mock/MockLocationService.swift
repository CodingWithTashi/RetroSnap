#if DEBUG
import Foundation
import Observation

/// Location that is allowed as soon as it is asked for and never has a fix.
@Observable
final class MockLocationService: LocationProviding {
    private(set) var isAllowed = false
    let current: PhotoLocation? = nil

    func requestAccess(completion: @escaping @MainActor (Bool) -> Void) {
        isAllowed = true
        completion(true)
    }

    func start() {}

    func stop() {}
}
#endif

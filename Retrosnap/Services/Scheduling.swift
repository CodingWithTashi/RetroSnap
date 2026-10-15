import Foundation

/// A piece of delayed or repeating work that can be called off.
protocol ScheduledWork: AnyObject {
    func cancel()
}

/// Delayed work, behind a protocol so view models can be driven with virtual time in tests.
protocol Scheduling: AnyObject {
    @discardableResult
    func after(_ delay: Duration, _ work: @escaping @MainActor () -> Void) -> any ScheduledWork

    @discardableResult
    func every(_ interval: Duration, _ work: @escaping @MainActor () -> Void) -> any ScheduledWork
}

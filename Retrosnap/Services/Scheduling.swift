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

/// Real time, on the main actor.
final class TaskScheduler: Scheduling {
    private final class Handle: ScheduledWork {
        var task: Task<Void, Never>?

        func cancel() {
            task?.cancel()
        }
    }

    @discardableResult
    func after(_ delay: Duration, _ work: @escaping @MainActor () -> Void) -> any ScheduledWork {
        let handle = Handle()
        handle.task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
        return handle
    }

    @discardableResult
    func every(_ interval: Duration, _ work: @escaping @MainActor () -> Void) -> any ScheduledWork {
        let handle = Handle()
        handle.task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                work()
            }
        }
        return handle
    }
}

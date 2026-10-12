import Foundation
@testable import Retrosnap

/// Virtual time for tests: nothing runs until `advance(by:)`, which fires due work in deadline order,
/// including work scheduled by the work it fires.
@MainActor
final class ManualScheduler: Scheduling {
    private final class Item: ScheduledWork {
        var deadline: Duration
        let interval: Duration?
        let order: Int
        let work: @MainActor () -> Void
        var isCancelled = false

        init(deadline: Duration, interval: Duration?, order: Int, work: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.interval = interval
            self.order = order
            self.work = work
        }

        func cancel() {
            isCancelled = true
        }
    }

    private var items: [Item] = []
    private var nextOrder = 0
    private(set) var now = Duration.zero

    var pendingCount: Int {
        items.filter { !$0.isCancelled }.count
    }

    @discardableResult
    func after(_ delay: Duration, _ work: @escaping @MainActor () -> Void) -> any ScheduledWork {
        enqueue(delay: delay, interval: nil, work)
    }

    @discardableResult
    func every(_ interval: Duration, _ work: @escaping @MainActor () -> Void) -> any ScheduledWork {
        enqueue(delay: interval, interval: interval, work)
    }

    func advance(by duration: Duration) {
        let target = now + duration
        while let next = nextDue(before: target) {
            now = next.deadline
            if let interval = next.interval {
                next.deadline += interval
            } else {
                items.removeAll { $0 === next }
            }
            next.work()
        }
        items.removeAll { $0.isCancelled }
        now = target
    }

    private func enqueue(delay: Duration, interval: Duration?, _ work: @escaping @MainActor () -> Void) -> Item {
        let item = Item(deadline: now + delay, interval: interval, order: nextOrder, work: work)
        nextOrder += 1
        items.append(item)
        return item
    }

    private func nextDue(before target: Duration) -> Item? {
        items
            .filter { !$0.isCancelled && $0.deadline <= target }
            .min { ($0.deadline, $0.order) < ($1.deadline, $1.order) }
    }
}

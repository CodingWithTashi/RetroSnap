import Foundation
import Testing
@testable import Retrosnap

/// The real scheduler runs on real time, so these wait for it, with room to spare on a busy machine.
@MainActor
struct TaskSchedulerTests {
    private let scheduler = TaskScheduler()

    /// Counts how often work ran.
    private final class Counter {
        var count = 0
    }

    private func wait(upTo limit: Duration = .seconds(5), until isDone: () -> Bool) async {
        let clock = ContinuousClock()
        let deadline = clock.now + limit
        while !isDone(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func delayedWorkRunsOnceAfterItsDelay() async {
        let counter = Counter()
        let started = ContinuousClock().now
        scheduler.after(.milliseconds(40)) { counter.count += 1 }
        #expect(counter.count == 0)

        await wait { counter.count > 0 }
        #expect(counter.count == 1)
        #expect(ContinuousClock().now - started >= .milliseconds(40))

        try? await Task.sleep(for: .milliseconds(80))
        #expect(counter.count == 1)
    }

    @Test func cancelledWorkNeverRuns() async {
        let counter = Counter()
        let work = scheduler.after(.milliseconds(30)) { counter.count += 1 }
        work.cancel()
        try? await Task.sleep(for: .milliseconds(120))
        #expect(counter.count == 0)
    }

    @Test func repeatingWorkRunsUntilItIsCancelled() async {
        let counter = Counter()
        let work = scheduler.every(.milliseconds(20)) { counter.count += 1 }
        await wait { counter.count >= 3 }
        #expect(counter.count >= 3)

        work.cancel()
        let stoppedAt = counter.count
        try? await Task.sleep(for: .milliseconds(120))
        #expect(counter.count <= stoppedAt + 1)
    }
}

#if DEBUG
import Foundation

/// A clock stopped at one moment.
struct FixedClock: DateProviding {
    let now: Date
    let calendar: Calendar

    /// 11 October 2026, 4:12 PM: the moment every stamp in the design shows.
    static var design: FixedClock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 16, minute: 12)) ?? Date()
        return FixedClock(now: now, calendar: calendar)
    }
}
#endif

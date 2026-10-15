import Foundation

/// The current time and calendar, injectable so mock data and tests get a fixed "now".
protocol DateProviding {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemClock: DateProviding {
    var now: Date { Date() }
    var calendar: Calendar { .current }
}

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

/// Turns dates into the words and stamps the design uses.
struct DayLabeler {
    private let clock: any DateProviding
    private let dayFormatter: DateFormatter
    private let stampFormatter: DateFormatter
    private let tapeDateFormatter: DateFormatter
    private let tapeTimeFormatter: DateFormatter

    init(clock: any DateProviding) {
        self.clock = clock
        let calendar = clock.calendar
        func formatter(_ format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            return formatter
        }
        dayFormatter = formatter("MMMM d")
        stampFormatter = formatter("''yy MM dd")
        tapeDateFormatter = formatter("MMM d yyyy")
        tapeTimeFormatter = formatter("h:mm a")
    }

    func startOfDay(_ date: Date) -> Date {
        clock.calendar.startOfDay(for: date)
    }

    /// "Today", "Yesterday", or the date written out ("October 4").
    func label(for date: Date) -> String {
        let calendar = clock.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: clock.now)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return dayFormatter.string(from: date)
        }
    }

    /// The text burned into a photo taken at `date`.
    func stamp(for date: Date) -> PhotoStampText {
        let parts = clock.calendar.dateComponents([.year, .month, .day], from: date)
        let year = (parts.year ?? 2000) % 100
        return PhotoStampText(
            date: stampFormatter.string(from: date),
            dateBack: String(format: "'%02d年 %d月%d日", year, parts.month ?? 1, parts.day ?? 1),
            dateBackPlain: String(format: "%2d %2d '%02d", parts.month ?? 1, parts.day ?? 1, year),
            tapeDate: tapeDateFormatter.string(from: date).uppercased(),
            tapeTime: tapeTimeFormatter.string(from: date)
        )
    }
}

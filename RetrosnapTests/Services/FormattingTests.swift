import Foundation
import Testing
@testable import Retrosnap

@MainActor
struct FormattingTests {
    private let clock = FixedClock.design

    private func date(daysAgo: Int, hour: Int = 16, minute: Int = 12) -> Date {
        let day = clock.calendar.date(byAdding: .day, value: -daysAgo, to: clock.now)!
        return clock.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    @Test func theMockClockIsTheDateDrawnInTheDesign() {
        let parts = clock.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: clock.now)
        #expect(parts.year == 2026 && parts.month == 10 && parts.day == 11)
        #expect(parts.hour == 16 && parts.minute == 12)
    }

    @Test func dayLabels() {
        let labeler = DayLabeler(clock: clock)
        #expect(labeler.label(for: clock.now) == "Today")
        #expect(labeler.label(for: date(daysAgo: 0, hour: 0, minute: 1)) == "Today")
        #expect(labeler.label(for: date(daysAgo: 1)) == "Yesterday")
        #expect(labeler.label(for: date(daysAgo: 1, hour: 23, minute: 59)) == "Yesterday")
        #expect(labeler.label(for: date(daysAgo: 7)) == "October 4")
        #expect(labeler.label(for: date(daysAgo: 2)) == "October 9")
    }

    @Test func stampsUseThePhotosOwnDate() {
        let labeler = DayLabeler(clock: clock)
        let today = labeler.stamp(for: clock.now)
        #expect(today.date == "'26 10 11")
        #expect(today.tapeDate == "OCT 11 2026")
        #expect(today.tapeTime == "4:12 PM")

        let earlier = labeler.stamp(for: date(daysAgo: 7, hour: 9, minute: 5))
        #expect(earlier.date == "'26 10 04")
        #expect(earlier.tapeDate == "OCT 4 2026")
        #expect(earlier.tapeTime == "9:05 AM")
    }

    @Test(arguments: [(1, "0:01"), (12, "0:12"), (24, "0:24"), (60, "1:00"), (75, "1:15"), (600, "10:00")])
    func clipLength(seconds: Int, text: String) {
        let photo = Photo(id: "v", image: .sceneBack, camera: .camcorder, capturedAt: clock.now, videoSeconds: seconds)
        #expect(photo.videoDurationText == text)
        #expect(photo.isVideo)
    }

    @Test func stillsHaveNoClipLength() {
        let photo = Photo(id: "p", image: .sceneBack, camera: .film, capturedAt: clock.now)
        #expect(photo.videoDurationText == nil)
        #expect(!photo.isVideo)
    }

    @Test func cameraStepsWrapAroundBothEnds() {
        #expect(CameraStyle.film.stepped(by: 1) == .disposable)
        #expect(CameraStyle.camcorder.stepped(by: 1) == .negative)
        #expect(CameraStyle.tlr.stepped(by: 1) == .film)
        #expect(CameraStyle.film.stepped(by: -1) == .tlr)
        #expect(CameraStyle.instant.stepped(by: -1) == .disposable)
    }

    @Test func stripSubtitleIsTheFirstSentence() {
        #expect(CameraStyle.film.shortSummary == "Golden tones, fine grain and soft edges.")
        #expect(CameraStyle.disposable.shortSummary == "Bright on-camera flash, warm grain, a little overexposed.")
        #expect(CameraStyle.instant.shortSummary == "Soft, faded square prints in a white frame, like they just slid out of the camera.")
    }
}

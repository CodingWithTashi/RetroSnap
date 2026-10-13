import Foundation
import ImageIO
import Testing
@testable import Retrosnap

/// A picture brought in from the library is stamped with the date it was taken, as its file says.
@MainActor
struct PhotoDateTests {
    @Test func theStampDateIsWhenThePictureWasTakenWhenKnown() {
        var photo = Photo(id: "a", image: .live, camera: .plastic35, capturedAt: FixedClock.design.now)
        #expect(photo.stampDate == FixedClock.design.now)
        let taken = Date(timeIntervalSince1970: 1_759_900_000)
        photo.takenAt = taken
        #expect(photo.stampDate == taken)
    }

    @Test func theTakenDateSurvivesTheIndex() throws {
        var photo = Photo(id: "a", image: .file(full: "a.jpg", thumbnail: "a-thumb.jpg"), camera: .plastic35, capturedAt: FixedClock.design.now)
        photo.takenAt = Date(timeIntervalSince1970: 1_759_900_000)
        let data = try JSONEncoder().encode(photo)
        let back = try JSONDecoder().decode(Photo.self, from: data)
        #expect(back.takenAt == photo.takenAt)
        // An index written before the field existed reads with no taken date.
        let old = try JSONDecoder().decode(Photo.self, from: Data(#"{"id":"b","image":{"live":{}},"camera":"film","capturedAt":0,"adjustments":{"intensity":100,"grain":50,"exposure":0,"contrast":0,"warmth":0}}"#.utf8))
        #expect(old.takenAt == nil)
        #expect(old.stampDate == old.capturedAt)
    }

    @Test func theExifDateIsReadWithItsZone() {
        let exif: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: "2026:10:08 12:32:41",
            kCGImagePropertyExifOffsetTimeOriginal: "+02:00",
        ]
        let date = PhotoImporter.takenAt(of: [kCGImagePropertyExifDictionary: exif])
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 8; components.hour = 10; components.minute = 32; components.second = 41
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(date == utc.date(from: components))
        #expect(PhotoImporter.takenAt(of: [:]) == nil)
        #expect(TimeZone(iso8601: "-07:00")?.secondsFromGMT() == -7 * 3600)
        #expect(TimeZone(iso8601: "bogus") == nil)
    }

    @Test func theDateBackWritesTheYearMonthAndDayWithTheirMarks() {
        let labeler = DayLabeler(clock: FixedClock.design)
        let stamp = labeler.stamp(for: FixedClock.design.now)
        #expect(stamp.date == "'26 10 11")
        #expect(stamp.dateBack == "'26年 10月11日")
        let eighth = FixedClock.design.calendar.date(byAdding: .day, value: -3, to: FixedClock.design.now)!
        #expect(labeler.stamp(for: eighth).dateBack == "'26年 10月8日")
        // The plain date back: month, day and year each in two places, with a tick before the year.
        #expect(stamp.dateBackPlain == "10 11 '26")
        #expect(labeler.stamp(for: eighth).dateBackPlain == "10  8 '26")
        let july = FixedClock.design.calendar.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12))!
        #expect(labeler.stamp(for: july).dateBackPlain == " 7 23 '26")
    }

    @Test func theDotMatrixHasAGlyphForEveryMarkTheDateBackPrints() {
        for character in "0123456789'年月日 " {
            let glyph = DotMatrixFont.glyph(for: character)
            #expect(glyph.rows.count == 7)
            #expect(glyph.rows.allSatisfy { $0.count == glyph.width })
        }
        #expect(DotMatrixFont.glyphs(for: "'26年 10月8日").count == 10)
    }
}

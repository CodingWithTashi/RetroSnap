import Foundation

/// The text burned into a photo: the orange date for film-style cameras, the date as a compact's date back
/// writes it, and the tape overlay for the camcorder.
nonisolated struct PhotoStampText: Hashable, Sendable {
    /// "'26 10 11": the design's date stamp.
    let date: String
    /// "'26年 10月8日": the year, month and day with their marks, as a Japanese date back prints them.
    let dateBack: String
    let tapeDate: String
    let tapeTime: String

    init(date: String, dateBack: String = "", tapeDate: String, tapeTime: String) {
        self.date = date
        self.dateBack = dateBack
        self.tapeDate = tapeDate
        self.tapeTime = tapeTime
    }
}

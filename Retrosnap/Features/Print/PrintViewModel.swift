import CoreGraphics
import Foundation
import Observation

@Observable
final class PrintViewModel {
    static let copyRange = 1...20

    let photoID: Photo.ID
    private(set) var size = PrintSize.fourBySix
    private(set) var copies = 1
    private(set) var hasBorder = true
    private(set) var isMoreExpanded = false
    let printerName = "Living Room Printer"
    let paperName = "Glossy photo"

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let feedback: FeedbackCenter
    @ObservationIgnored private let dayLabeler: DayLabeler

    init(
        photoID: Photo.ID,
        photos: any PhotoStoring,
        router: AppRouter,
        toasts: ToastCenter,
        feedback: FeedbackCenter,
        dayLabeler: DayLabeler
    ) {
        self.photoID = photoID
        self.photos = photos
        self.router = router
        self.toasts = toasts
        self.feedback = feedback
        self.dayLabeler = dayLabeler
    }

    var photo: Photo? {
        photos.photo(id: photoID)
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.capturedAt) }
    }

    var paperSize: CGSize {
        size.paperSize
    }

    /// The white border around the photo on the paper; none when the border is off.
    var paperPadding: CGFloat {
        hasBorder ? size.borderWidth : 0
    }

    var actionTitle: String {
        copies > 1 ? "Print \(copies) copies" : "Print"
    }

    func select(_ newSize: PrintSize) {
        size = newSize
    }

    func increaseCopies() {
        copies = min(Self.copyRange.upperBound, copies + 1)
    }

    func decreaseCopies() {
        copies = max(Self.copyRange.lowerBound, copies - 1)
    }

    func toggleBorder() {
        hasBorder.toggle()
    }

    func toggleMore() {
        isMoreExpanded.toggle()
    }

    func cancelTapped() {
        router.back()
    }

    func printTapped() {
        feedback.haptic(.firm)
        router.back()
        toasts.show("Sent to \(printerName)")
    }
}

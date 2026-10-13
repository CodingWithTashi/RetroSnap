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

    @ObservationIgnored private let photos: any PhotoStoring
    @ObservationIgnored private let printing: any PhotoPrinting
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let feedback: FeedbackCenter
    @ObservationIgnored private let dayLabeler: DayLabeler
    /// A job has been handed to the printer and has not ended yet.
    @ObservationIgnored private var isSending = false

    init(
        photoID: Photo.ID,
        photos: any PhotoStoring,
        printing: any PhotoPrinting,
        router: AppRouter,
        toasts: ToastCenter,
        feedback: FeedbackCenter,
        dayLabeler: DayLabeler
    ) {
        self.photoID = photoID
        self.photos = photos
        self.printing = printing
        self.router = router
        self.toasts = toasts
        self.feedback = feedback
        self.dayLabeler = dayLabeler
    }

    var photo: Photo? {
        photos.photo(id: photoID)
    }

    var stamp: PhotoStampText? {
        photo.map { dayLabeler.stamp(for: $0.stampDate) }
    }

    var paperSize: CGSize {
        size.paperSize
    }

    /// The white border around the photo on the paper; none when the border is off.
    var paperPadding: CGFloat {
        hasBorder ? size.borderWidth : 0
    }

    var printerName: String {
        printing.printerName ?? "Not chosen yet"
    }

    var paperName: String {
        printing.paperName
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

    /// The Printer row under More options: pick, or change, the printer.
    func printerTapped() {
        printing.choosePrinter()
    }

    func printTapped() {
        guard let photo, !isSending else { return }
        feedback.haptic(.firm)
        isSending = true
        let job = PrintJob(photo: photo, size: size, hasBorder: hasBorder, copies: copies)
        printing.print(job) { [weak self] outcome in
            guard let self else { return }
            isSending = false
            switch outcome {
            case .sent:
                router.back()
                toasts.show("Sent to \(printing.printerName ?? "the printer")")
            case .cancelled:
                break
            case .failed:
                toasts.show("Couldn’t reach the printer")
            }
        }
    }
}

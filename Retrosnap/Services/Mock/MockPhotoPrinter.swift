#if DEBUG
import Foundation

/// The prototype's printer: always there, and every job reaches it at once.
final class MockPhotoPrinter: PhotoPrinting {
    let printerName: String? = "Living Room Printer"
    let paperName = "Glossy photo"

    func print(_ job: PrintJob, completion: @escaping @MainActor (PrintOutcome) -> Void) {
        completion(.sent)
    }

    func choosePrinter() {}
}
#endif

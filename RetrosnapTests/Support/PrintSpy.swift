import Foundation
@testable import Retrosnap

/// A printer whose jobs finish only when the test says so.
@MainActor
final class PrintSpy: PhotoPrinting {
    var printerName: String?
    let paperName = "Photo paper"
    private(set) var jobs: [PrintJob] = []
    private(set) var choosePrinterCount = 0
    private var completion: (@MainActor (PrintOutcome) -> Void)?

    init(printerName: String? = "Office Printer") {
        self.printerName = printerName
    }

    func print(_ job: PrintJob, completion: @escaping @MainActor (PrintOutcome) -> Void) {
        jobs.append(job)
        self.completion = completion
    }

    func choosePrinter() {
        choosePrinterCount += 1
    }

    /// The pending job ends this way.
    func finish(_ outcome: PrintOutcome) {
        completion?(outcome)
        completion = nil
    }
}

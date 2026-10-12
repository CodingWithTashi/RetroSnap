import Foundation

/// A print as the Print screen sets it up.
nonisolated struct PrintJob: Hashable, Sendable {
    var photo: Photo
    var size: PrintSize
    var hasBorder: Bool
    var copies: Int
}

nonisolated enum PrintOutcome: Hashable, Sendable {
    case sent
    /// The user backed out of choosing a printer.
    case cancelled
    case failed
}

/// A printer the user picked, kept so that later jobs go straight to it.
nonisolated struct SavedPrinter: Hashable, Sendable, Codable {
    var name: String
    var url: URL
}

/// Prints photos with their look, stamp and edits baked in.
protocol PhotoPrinting: AnyObject {
    /// The printer jobs go to; nil until one has been chosen.
    var printerName: String? { get }
    var paperName: String { get }
    /// Sends the job. With no printer chosen yet it asks for one first. The completion says how it ended.
    func print(_ job: PrintJob, completion: @escaping @MainActor (PrintOutcome) -> Void)
    /// Asks which printer to use from now on.
    func choosePrinter()
}

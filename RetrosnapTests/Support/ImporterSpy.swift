import Foundation
@testable import Retrosnap

/// A picker that stays open until the test closes it, and remembers which drafts were thrown away.
@MainActor
final class ImporterSpy: PhotoImporting {
    var isImporting = false
    private(set) var pickCount = 0
    private(set) var discarded: [Photo] = []
    private var completion: (@MainActor (ImportOutcome) -> Void)?

    /// The picker is up.
    var isPicking: Bool {
        completion != nil
    }

    func pick(completion: @escaping @MainActor (ImportOutcome) -> Void) {
        pickCount += 1
        self.completion = completion
    }

    func discard(_ draft: Photo) {
        discarded.append(draft)
    }

    /// The picker closes with this outcome.
    func deliver(_ outcome: ImportOutcome) {
        let completion = completion
        self.completion = nil
        completion?(outcome)
    }
}

import Foundation
@testable import Retrosnap

/// Storage whose numbers the test sets, and that counts how often it is asked to measure again.
@MainActor
final class StorageSpy: StorageMonitoring {
    var isLow = false
    var photosLeft = 40
    var usedText = "1.2 GB"
    private(set) var refreshCount = 0

    func refresh() {
        refreshCount += 1
    }
}

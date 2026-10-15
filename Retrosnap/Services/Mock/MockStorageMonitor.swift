#if DEBUG
import Foundation
import Observation

@Observable
final class MockStorageMonitor: StorageMonitoring {
    var isLow: Bool
    let photosLeft = 40
    let usedText = "1.2 GB"

    init(isLow: Bool = false) {
        self.isLow = isLow
    }

    func refresh() {}
}
#endif

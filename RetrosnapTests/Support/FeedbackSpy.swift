import Foundation
@testable import Retrosnap

/// Records feedback instead of buzzing or clicking.
@MainActor
final class FeedbackSpy: FeedbackProviding {
    private(set) var haptics: [HapticKind] = []
    private(set) var clicks = 0
    private(set) var hapticPrepareCount = 0
    private(set) var clickPrepareCount = 0

    func prepareHaptics() {
        hapticPrepareCount += 1
    }

    func prepareClick() {
        clickPrepareCount += 1
    }

    func haptic(_ kind: HapticKind) {
        haptics.append(kind)
    }

    func shutterClick() {
        clicks += 1
    }
}

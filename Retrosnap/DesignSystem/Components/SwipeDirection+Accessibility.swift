import SwiftUI

extension SwipeDirection {
    /// VoiceOver's adjust gesture as a swipe: increment goes on, as a swipe left does.
    init(_ adjustment: AccessibilityAdjustmentDirection) {
        self = adjustment == .increment ? .left : .right
    }
}

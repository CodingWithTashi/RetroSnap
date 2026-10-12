import SwiftUI

/// 8pt grid.
enum RSSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 48
}

enum RSRadius {
    static let card: CGFloat = 16
    static let group: CGFloat = 20
    static let sheet: CGFloat = 28
}

/// Motion runs 200 to 300ms on a soft spring; the curves are the prototype's cubic-beziers.
nonisolated enum RSMotion {
    /// Camera look cross-fade.
    static let crossFade = Animation.easeInOut(duration: 0.28)
    /// Chip and strip folding in and out.
    static let strip = Animation.timingCurve(0.3, 1.25, 0.5, 1, duration: 0.28)
    static let chip = Animation.timingCurve(0.3, 1.3, 0.5, 1, duration: 0.26)
    static let fade = Animation.easeInOut(duration: 0.22)
    /// Shutter inner shape morphing between photo, video and stop.
    static let shutterMorph = Animation.timingCurve(0.3, 1.4, 0.5, 1, duration: 0.22)
    /// Toggle knob.
    static let knob = Animation.timingCurve(0.3, 1.3, 0.5, 1, duration: 0.22)
    static let selection = Animation.easeInOut(duration: 0.2)
    static let press = Animation.easeInOut(duration: 0.12)
    static let paper = Animation.timingCurve(0.3, 1.2, 0.5, 1, duration: 0.26)
    static let toast = Animation.timingCurve(0.3, 1.3, 0.5, 1, duration: 0.22)

    static let flashDuration: TimeInterval = 0.24
    static let flyDuration: TimeInterval = 0.46
    static let flyDelay: TimeInterval = 0.06
    static let nameLabelDuration: TimeInterval = 1.1
    static let developDuration: TimeInterval = 0.9
}

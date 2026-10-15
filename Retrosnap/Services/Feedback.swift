import AVFoundation
import Foundation
import UIKit

nonisolated enum HapticKind: Hashable, Sendable {
    /// Small state changes: flash, timer, chip, each countdown beat.
    case tick
    /// A choice landing: picking a camera, flipping the lens, swapping collage photos.
    case soft
    /// The main event: capture, record, print, save.
    case firm
}

/// Raw haptics and sound.
protocol FeedbackProviding: AnyObject {
    /// Wakes the Taptic Engine for a moment, so that the haptic that follows comes with no delay.
    func prepareHaptics()
    /// Builds and loads the click ahead of the shot, instead of during it.
    func prepareClick()
    func haptic(_ kind: HapticKind)
    func shutterClick()
}

/// What view models call. Applies the Haptics and Shutter sound settings before anything reaches the hardware.
final class FeedbackCenter {
    private let output: any FeedbackProviding
    private let settings: any SettingsStoring

    init(output: any FeedbackProviding, settings: any SettingsStoring) {
        self.output = output
        self.settings = settings
    }

    /// Called when feedback is about to be wanted: the camera has come up, or a finger is on the shutter.
    /// - Parameter click: The shutter click may follow, and not only a haptic.
    func prepare(click: Bool) {
        if settings.haptics {
            output.prepareHaptics()
        }
        if click, settings.shutterSound {
            output.prepareClick()
        }
    }

    func haptic(_ kind: HapticKind) {
        guard settings.haptics else { return }
        output.haptic(kind)
    }

    func shutterClick() {
        guard settings.shutterSound else { return }
        output.shutterClick()
    }
}

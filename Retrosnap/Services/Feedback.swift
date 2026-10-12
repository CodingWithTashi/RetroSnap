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

    func haptic(_ kind: HapticKind) {
        guard settings.haptics else { return }
        output.haptic(kind)
    }

    func shutterClick() {
        guard settings.shutterSound else { return }
        output.shutterClick()
    }
}

/// Taptic Engine haptics and a synthesized shutter click.
final class SystemFeedback: FeedbackProviding {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private lazy var clickPlayer: AVAudioPlayer? = Self.makeClickPlayer()

    func haptic(_ kind: HapticKind) {
        switch kind {
        case .tick: light.impactOccurred(intensity: 0.6)
        case .soft: light.impactOccurred()
        case .firm: medium.impactOccurred()
        }
    }

    func shutterClick() {
        guard let clickPlayer else { return }
        clickPlayer.currentTime = 0
        clickPlayer.play()
    }

    /// The prototype's click: 70ms of noise with a fast decay and a short dip, band-passed around 2.2kHz.
    /// Played in the ambient category, so the silent switch mutes it and the haptic remains.
    private static func makeClickPlayer() -> AVAudioPlayer? {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

        let sampleRate = 44_100.0
        let count = Int(sampleRate * 0.07)
        var seed: UInt32 = 0x2F6E_2B1D
        var noise = [Double](repeating: 0, count: count)
        for index in 0..<count {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let white = Double(seed >> 8) / Double(1 << 24) * 2 - 1
            let t = Double(index) / Double(count)
            noise[index] = white * pow(1 - t, 4) * (t < 0.35 || t > 0.5 ? 1 : 0.3)
        }

        // Biquad band-pass (constant 0 dB peak gain), 2200 Hz, Q 0.8.
        let omega = 2 * Double.pi * 2200 / sampleRate
        let alpha = sin(omega) / (2 * 0.8)
        let a0 = 1 + alpha
        let b0 = alpha / a0, b2 = -alpha / a0
        let a1 = -2 * cos(omega) / a0, a2 = (1 - alpha) / a0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var samples = [Int16](repeating: 0, count: count)
        for index in 0..<count {
            let x = noise[index]
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            samples[index] = Int16(max(-1, min(1, y * 0.35)) * Double(Int16.max))
        }

        var wav = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) }
        }
        let dataSize = UInt32(count * 2)
        wav.append(contentsOf: Array("RIFF".utf8)); append(36 + dataSize)
        wav.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate) * 2); append(UInt16(2)); append(UInt16(16))
        wav.append(contentsOf: Array("data".utf8)); append(dataSize)
        samples.forEach { append($0) }

        let player = try? AVAudioPlayer(data: wav)
        player?.prepareToPlay()
        return player
    }
}

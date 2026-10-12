import Foundation

/// The five cameras. Raw values are the ids used by the design prototype.
nonisolated enum CameraStyle: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case film
    case disposable = "disp"
    case instant = "inst"
    case digicam = "digi"
    case camcorder = "vhs"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .film: "35mm Film"
        case .disposable: "Disposable"
        case .instant: "Instant"
        case .digicam: "Digicam"
        case .camcorder: "Camcorder"
        }
    }

    var badge: String {
        switch self {
        case .film: "Golden"
        case .disposable: "Flash"
        case .instant: "Square"
        case .digicam: "Date stamp"
        case .camcorder: "Home video"
        }
    }

    var summary: String {
        switch self {
        case .film: "Golden tones, fine grain and soft edges. The classic everyday look."
        case .disposable: "Bright on-camera flash, warm grain, a little overexposed. Made for nights out."
        case .instant: "Soft, faded square prints in a white frame, like they just slid out of the camera."
        case .digicam: "Crisp early-2000s digital with a cool cast and an orange date in the corner."
        case .camcorder: "Fuzzy home-video color with scanlines and an on-screen timestamp."
        }
    }

    /// First sentence of the summary, shown under the name in the camera strip.
    var shortSummary: String {
        let first = summary.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return first + "."
    }

    /// Accent used only on this camera's card bar, badge and chip ring.
    var accentHex: UInt32 {
        switch self {
        case .film: 0xF2A33A
        case .disposable: 0xF5C84B
        case .instant: 0xF4A99B
        case .digicam: 0x6FA8FF
        case .camcorder: 0xFF5A4E
        }
    }

    /// `color-mix(in oklab, accent 14%, #1B1916)` from the carousel cards, precomputed.
    var cardTintHex: UInt32 {
        switch self {
        case .film: 0x352A1E
        case .disposable: 0x342E1F
        case .instant: 0x352B26
        case .digicam: 0x262B32
        case .camcorder: 0x37231E
        }
    }

    var sample: SampleImage {
        switch self {
        case .film: .photo(1015)
        case .disposable: .photo(237)
        case .instant: .photo(1027)
        case .digicam: .photo(1069)
        case .camcorder: .photo(1039)
        }
    }

    /// The camera `offset` steps away, wrapping around both ends.
    func stepped(by offset: Int) -> CameraStyle {
        let all = CameraStyle.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[((index + offset) % all.count + all.count) % all.count]
    }
}

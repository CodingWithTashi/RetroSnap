import Foundation

/// The cameras, in carousel order. Raw values are the ids used by the design prototype and `docs/camera-lineup.md`;
/// they are written to disk, so they never change.
nonisolated enum CameraStyle: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case film
    case disposable = "disp"
    case instant = "inst"
    case digicam = "digi"
    case camcorder = "vhs"
    case negative
    case plastic35
    case slide
    case mediumFormat
    case tlr
    case compactPro
    case classicSLR
    case instSquare

    /// The camera a first launch opens on, and the one used wherever no camera is known.
    static let `default` = CameraStyle.film

    var id: String { rawValue }

    // MARK: Profile

    /// Everything the camera chooser shows for this camera, in one place.
    var profile: CameraProfile {
        switch self {
        case .film:
            CameraProfile(
                name: "D Classic", badge: "Everyday",
                summary: "True, gently warm colour and a red date in the corner. The everyday 35mm point-and-shoot.",
                accentHex: 0xF2A33A, cardTintHex: 0x352A1E, sample: .photo(1015)
            )
        case .disposable:
            CameraProfile(
                name: "Disposable", badge: "Flash",
                summary: "Bright on-camera flash, warm grain, a little overexposed. Made for nights out.",
                accentHex: 0xF5C84B, cardTintHex: 0x342E1F, sample: .photo(237)
            )
        case .instant:
            CameraProfile(
                name: "Inst C", badge: "Mini print",
                summary: "Soft, cool pastels on a mini print in a white frame. Like it just slid out of the camera.",
                accentHex: 0xF4A99B, cardTintHex: 0x352B26, sample: .photo(1027)
            )
        case .digicam:
            CameraProfile(
                name: "Digicam", badge: "Date stamp",
                summary: "Crisp early-2000s digital with a cool cast and an orange date in the corner.",
                accentHex: 0x6FA8FF, cardTintHex: 0x262B32, sample: .photo(1069)
            )
        case .camcorder:
            CameraProfile(
                name: "Camcorder", badge: "Home video",
                summary: "Fuzzy home-video color with scanlines and an on-screen timestamp.",
                accentHex: 0xFF5A4E, cardTintHex: 0x37231E, sample: .photo(1039)
            )
        case .negative:
            CameraProfile(
                name: "135 NE", badge: "Sprockets",
                summary: "Colour negative on the scanned strip, sprocket holes and all. Warm, grainy and honest.",
                accentHex: 0xF28C38, cardTintHex: 0x35281D, sample: .photo(1043)
            )
        case .plastic35:
            CameraProfile(
                name: "CPM35", badge: "Hazy",
                summary: "A cheap plastic point-and-shoot: hazy, flat and a little green. Nothing is punchy and everything is nice.",
                accentHex: 0xB8C9B4, cardTintHex: 0x2E2E29, sample: .photo(42)
            )
        case .slide:
            CameraProfile(
                name: "D Slide", badge: "Mounted",
                summary: "Slide film in a cardboard mount. Rich colour, deep shadows and a tiny picture to hold up to the light.",
                accentHex: 0x5FC7B8, cardTintHex: 0x262E29, sample: .photo(110)
            )
        case .mediumFormat:
            CameraProfile(
                name: "S 67", badge: "6×7",
                summary: "Medium format at 6×7: a big negative with fine grain and smooth tones. Portraits love it.",
                accentHex: 0xD9C3A5, cardTintHex: 0x312D27, sample: .photo(1074)
            )
        case .tlr:
            CameraProfile(
                name: "S Classic", badge: "1:1",
                summary: "A twin-lens reflex shooting square frames. Fine grain, creamy skin and a black rebate.",
                accentHex: 0xA7B4C2, cardTintHex: 0x2C2C2A, sample: .photo(1025)
            )
        case .compactPro:
            CameraProfile(
                name: "CT2F", badge: "Premium",
                summary: "A premium 1990s compact: rich colour, deep contrast, fine grain and a red date in the corner.",
                accentHex: 0xC9B79C, cardTintHex: 0x302C26, sample: .photo(1011)
            )
        case .classicSLR:
            CameraProfile(
                name: "Classic U", badge: "SLR",
                summary: "A classic 35mm SLR on consumer colour film: natural tones, honest grain and a dotted date in the corner.",
                accentHex: 0xD6553F, cardTintHex: 0x32221C, sample: .photo(1016)
            )
        case .instSquare:
            CameraProfile(
                name: "Inst SQC", badge: "Square print",
                summary: "A square instant print in a coloured frame. Gentle colour and a wide border to write on.",
                accentHex: 0x7FB8D6, cardTintHex: 0x282C2D, sample: .photo(1080)
            )
        }
    }

    /// Cameras matched to the reference app are named exactly as it names them (D6 in `docs/camera-lineup.md`);
    /// the three still on the design's looks keep the design's names until their references arrive.
    var name: String { profile.name }

    var badge: String { profile.badge }

    var summary: String { profile.summary }

    /// Accent used only on this camera's card bar, badge and chip ring.
    var accentHex: UInt32 { profile.accentHex }

    /// `color-mix(in oklab, accent 14%, #1B1916)` from the carousel cards, precomputed.
    var cardTintHex: UInt32 { profile.cardTintHex }

    var sample: SampleImage { profile.sample }

    // MARK: Derived

    /// First sentence of the summary, shown under the name in the camera strip.
    var shortSummary: String {
        let first = summary.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return first + "."
    }

    /// Whether the camera's pictures come out as the mini instant print, which the result and edit screens show
    /// smaller (and the result tilted). Both the mini print (`inst`) and the square print (`instSquare`) are.
    var isInstantPrint: Bool { look.frame == .instantPrint || look.frame == .squarePrint }

    /// The VoiceOver label of this camera's card in the strip and the carousel.
    func cardAccessibilityLabel(isSelected: Bool) -> String {
        "\(name). \(summary)\(isSelected ? " Selected." : "")"
    }

    /// The picture's width over its height when this camera shows it framed; nil when it is the whole photo.
    var pictureRatio: CGFloat? {
        look.frame?.pictureRatio
    }

    /// The camera `offset` steps away, wrapping around both ends.
    func stepped(by offset: Int) -> CameraStyle {
        let all = CameraStyle.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[((index + offset) % all.count + all.count) % all.count]
    }
}

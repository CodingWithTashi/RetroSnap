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

    var id: String { rawValue }

    /// Cameras matched to the reference app are named exactly as it names them (D6 in `docs/camera-lineup.md`);
    /// the three still on the design's looks keep the design's names until their references arrive.
    var name: String {
        switch self {
        case .film: "D Classic"
        case .disposable: "Disposable"
        case .instant: "Inst C"
        case .digicam: "Digicam"
        case .camcorder: "Camcorder"
        case .negative: "135 NE"
        case .plastic35: "CPM35"
        case .slide: "D Slide"
        case .mediumFormat: "S 67"
        case .tlr: "S Classic"
        case .compactPro: "CT2F"
        case .classicSLR: "Classic U"
        case .instSquare: "Inst SQC"
        }
    }

    var badge: String {
        switch self {
        case .film: "Everyday"
        case .disposable: "Flash"
        case .instant: "Mini print"
        case .digicam: "Date stamp"
        case .camcorder: "Home video"
        case .negative: "Sprockets"
        case .plastic35: "Hazy"
        case .slide: "Mounted"
        case .mediumFormat: "6×7"
        case .tlr: "1:1"
        case .compactPro: "Premium"
        case .classicSLR: "SLR"
        case .instSquare: "Square print"
        }
    }

    var summary: String {
        switch self {
        case .film: "True, gently warm colour and a red date in the corner. The everyday 35mm point-and-shoot."
        case .disposable: "Bright on-camera flash, warm grain, a little overexposed. Made for nights out."
        case .instant: "Soft, cool pastels on a mini print in a white frame. Like it just slid out of the camera."
        case .digicam: "Crisp early-2000s digital with a cool cast and an orange date in the corner."
        case .camcorder: "Fuzzy home-video color with scanlines and an on-screen timestamp."
        case .negative: "Colour negative on the scanned strip, sprocket holes and all. Warm, grainy and honest."
        case .plastic35: "A cheap plastic point-and-shoot: hazy, flat and a little green. Nothing is punchy and everything is nice."
        case .slide: "Slide film in a cardboard mount. Rich colour, deep shadows and a tiny picture to hold up to the light."
        case .mediumFormat: "Medium format at 6×7: a big negative with fine grain and smooth tones. Portraits love it."
        case .tlr: "A twin-lens reflex shooting square frames. Fine grain, creamy skin and a black rebate."
        case .compactPro: "A premium 1990s compact: rich colour, deep contrast, fine grain and a red date in the corner."
        case .classicSLR: "A classic 35mm SLR on consumer colour film: natural tones, honest grain and a dotted date in the corner."
        case .instSquare: "A square instant print in a coloured frame. Gentle colour and a wide border to write on."
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
        case .negative: 0xF28C38
        case .plastic35: 0xB8C9B4
        case .slide: 0x5FC7B8
        case .mediumFormat: 0xD9C3A5
        case .tlr: 0xA7B4C2
        case .compactPro: 0xC9B79C
        case .classicSLR: 0xD6553F
        case .instSquare: 0x7FB8D6
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
        case .negative: 0x35281D
        case .plastic35: 0x2E2E29
        case .slide: 0x262E29
        case .mediumFormat: 0x312D27
        case .tlr: 0x2C2C2A
        case .compactPro: 0x302C26
        case .classicSLR: 0x32221C
        case .instSquare: 0x282C2D
        }
    }

    var sample: SampleImage {
        switch self {
        case .film: .photo(1015)
        case .disposable: .photo(237)
        case .instant: .photo(1027)
        case .digicam: .photo(1069)
        case .camcorder: .photo(1039)
        case .negative: .photo(1043)
        case .plastic35: .photo(42)
        case .slide: .photo(110)
        case .mediumFormat: .photo(1074)
        case .tlr: .photo(1025)
        case .compactPro: .photo(1011)
        case .classicSLR: .photo(1016)
        case .instSquare: .photo(1080)
        }
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

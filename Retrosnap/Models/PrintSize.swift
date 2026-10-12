import CoreGraphics
import Foundation

nonisolated enum PrintSize: String, CaseIterable, Identifiable, Hashable, Sendable {
    case fourBySix = "4x6"
    case square = "sq"
    case strip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fourBySix: "4×6"
        case .square: "Square"
        case .strip: "Strip"
        }
    }

    /// The paper as drawn in the preview.
    var paperSize: CGSize {
        switch self {
        case .fourBySix: CGSize(width: 240, height: 360)
        case .square: CGSize(width: 290, height: 290)
        case .strip: CGSize(width: 130, height: 330)
        }
    }

    /// The real print in points (72 to the inch): 4x6, 4x4 and a 2x6 strip.
    var pageSize: CGSize {
        switch self {
        case .fourBySix: CGSize(width: 288, height: 432)
        case .square: CGSize(width: 288, height: 288)
        case .strip: CGSize(width: 144, height: 432)
        }
    }

    var borderWidth: CGFloat {
        self == .strip ? 8 : 14
    }
}

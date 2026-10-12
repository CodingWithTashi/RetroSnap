import Foundation

/// The five edit sliders. Raw values are the prototype's keys.
nonisolated enum EditTool: String, CaseIterable, Identifiable, Hashable, Sendable {
    case effect = "intensity"
    case grain
    case light = "exposure"
    case contrast
    case warmth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .effect: "Effect"
        case .grain: "Grain"
        case .light: "Light"
        case .contrast: "Contrast"
        case .warmth: "Warmth"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .effect, .grain: 0...100
        case .light, .contrast, .warmth: -50...50
        }
    }

    /// Sliders centred on zero show a plus sign for positive values.
    var isBipolar: Bool {
        range.lowerBound < 0
    }

    var keyPath: WritableKeyPath<PhotoAdjustments, Int> {
        switch self {
        case .effect: \.intensity
        case .grain: \.grain
        case .light: \.exposure
        case .contrast: \.contrast
        case .warmth: \.warmth
        }
    }
}

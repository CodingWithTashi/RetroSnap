import CoreGraphics
import Foundation

/// A collage layout. Raw values are the prototype's keys; cells are percentages of the frame.
nonisolated enum CollageTemplate: String, CaseIterable, Identifiable, Hashable, Sendable {
    case feature = "three"
    case stacked = "two"
    case sideBySide = "side"
    case grid
    case strip
    case trio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feature: "Feature"
        case .stacked: "Stacked"
        case .sideBySide: "Side by side"
        case .grid: "Grid"
        case .strip: "Photo strip"
        case .trio: "Trio"
        }
    }

    var cells: [CGRect] {
        func cell(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
        return switch self {
        case .feature: [cell(0, 0, 100, 60), cell(0, 60, 50, 40), cell(50, 60, 50, 40)]
        case .stacked: [cell(0, 0, 100, 50), cell(0, 50, 100, 50)]
        case .sideBySide: [cell(0, 0, 50, 100), cell(50, 0, 50, 100)]
        case .grid: [cell(0, 0, 50, 50), cell(50, 0, 50, 50), cell(0, 50, 50, 50), cell(50, 50, 50, 50)]
        case .strip: [cell(0, 0, 100, 25), cell(0, 25, 100, 25), cell(0, 50, 100, 25), cell(0, 75, 100, 25)]
        case .trio: [cell(0, 0, 33.34, 100), cell(33.33, 0, 33.34, 100), cell(66.66, 0, 33.34, 100)]
        }
    }

    var photoCount: Int {
        cells.count
    }
}

nonisolated enum CollageBorder: String, CaseIterable, Identifiable, Hashable, Sendable {
    case cream
    case black
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cream: "Cream"
        case .black: "Black"
        case .none: "No border"
        }
    }

    /// The frame colour, also shown as the chip's dot.
    var hex: UInt32 {
        switch self {
        case .cream: 0xF4EEE6
        case .black: 0x0A0908
        case .none: 0x26231F
        }
    }
}

nonisolated enum CollageStep: Int, Hashable, Sendable {
    case layout = 1
    case pick
    case arrange
}

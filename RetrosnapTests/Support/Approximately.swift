import Foundation

/// Floating-point comparison for values derived from the design's decimal constants.
func isClose(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

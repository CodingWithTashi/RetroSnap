import Foundation

/// One step of a CSS `filter` chain.
nonisolated enum LookFilter: Hashable, Sendable {
    case sepia(Double)
    case saturate(Double)
    case contrast(Double)
    case brightness(Double)
    case hueRotate(degrees: Double)
}

nonisolated enum LookStamp: Hashable, Sendable {
    case none
    case date
    case vhs
}

/// A camera's recipe, transcribed from the `LOOKS` table in the design's Photo component.
nonisolated struct CameraLook: Hashable, Sendable {
    let filters: [LookFilter]
    let blurRadius: Double
    let tintHex: UInt32
    let tint: Double
    let flash: Double
    let fade: Double
    let chroma: Double
    let scan: Double
    let vignette: Double
    let grain: Double
    let stamp: LookStamp
}

extension CameraStyle {
    nonisolated var look: CameraLook {
        switch self {
        case .film:
            CameraLook(
                filters: [.sepia(0.34), .saturate(1.3), .contrast(1.06), .brightness(1.03), .hueRotate(degrees: -8)],
                blurRadius: 0, tintHex: 0xFF9A2E, tint: 0.2, flash: 0, fade: 0, chroma: 0, scan: 0,
                vignette: 0.6, grain: 0.26, stamp: .date
            )
        case .disposable:
            CameraLook(
                filters: [.contrast(1.22), .saturate(1.35), .sepia(0.16), .brightness(1.13)],
                blurRadius: 0, tintHex: 0xFFCF5A, tint: 0.18, flash: 0.7, fade: 0, chroma: 0, scan: 0,
                vignette: 0.4, grain: 0.42, stamp: .date
            )
        case .instant:
            CameraLook(
                filters: [.contrast(0.8), .saturate(0.74), .sepia(0.22), .brightness(1.12)],
                blurRadius: 0, tintHex: 0xFFB9A0, tint: 0.22, flash: 0, fade: 0.16, chroma: 0, scan: 0,
                vignette: 0.22, grain: 0.14, stamp: .none
            )
        case .digicam:
            CameraLook(
                filters: [.contrast(1.16), .saturate(0.86), .brightness(1.06)],
                blurRadius: 0, tintHex: 0x3D7DFF, tint: 0.28, flash: 0.15, fade: 0, chroma: 0, scan: 0,
                vignette: 0.08, grain: 0.08, stamp: .date
            )
        case .camcorder:
            CameraLook(
                filters: [.saturate(1.5), .contrast(0.9), .brightness(1.06)],
                blurRadius: 0.6, tintHex: 0x20D0C0, tint: 0.14, flash: 0, fade: 0.05, chroma: 0.5, scan: 0.4,
                vignette: 0.32, grain: 0.22, stamp: .vhs
            )
        }
    }
}

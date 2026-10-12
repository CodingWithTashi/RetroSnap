import Foundation

/// The five quiet actions under a photo, in the design's order.
nonisolated enum PhotoAction: CaseIterable, Identifiable, Hashable, Sendable {
    case share, edit, print, collage, delete

    var id: Self { self }

    var label: String {
        switch self {
        case .share: "Share"
        case .edit: "Edit"
        case .print: "Print"
        case .collage: "Collage"
        case .delete: "Delete"
        }
    }

    var icon: RSIcon {
        switch self {
        case .share: .share
        case .edit: .sliders
        case .print: .printer
        case .collage: .collage
        case .delete: .trash
        }
    }

    var isDestructive: Bool {
        self == .delete
    }
}

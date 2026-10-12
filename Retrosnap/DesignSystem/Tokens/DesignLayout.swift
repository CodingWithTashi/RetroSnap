import SwiftUI

/// Maps the design's absolute offsets (measured on a 390x844 frame, status bar and home indicator included)
/// onto the real screen. Exact on that frame; on taller safe areas, edge-anchored content keeps its clearance.
nonisolated struct DesignLayout: Equatable, Sendable {
    static let referenceSize = CGSize(width: 390, height: 844)
    static let referenceSafeTop: CGFloat = 47
    static let referenceSafeBottom: CGFloat = 34

    var size = DesignLayout.referenceSize
    var safeTop = DesignLayout.referenceSafeTop
    var safeBottom = DesignLayout.referenceSafeBottom

    /// Distance from the top screen edge for something the design places `y` from the top.
    func top(_ y: CGFloat) -> CGFloat {
        y + max(0, safeTop - DesignLayout.referenceSafeTop)
    }

    /// Distance from the bottom screen edge for something the design places `y` from the bottom.
    func bottom(_ y: CGFloat) -> CGFloat {
        y + max(0, safeBottom - DesignLayout.referenceSafeBottom)
    }

    /// Extra height the real screen has over the design frame.
    var extraHeight: CGFloat {
        max(0, size.height - DesignLayout.referenceSize.height)
    }
}

private nonisolated struct DesignLayoutKey: EnvironmentKey {
    static let defaultValue = DesignLayout()
}

extension EnvironmentValues {
    nonisolated var designLayout: DesignLayout {
        get { self[DesignLayoutKey.self] }
        set { self[DesignLayoutKey.self] = newValue }
    }
}

/// Reads the screen size and safe area once and publishes them to the screens below, which draw edge to edge.
struct DesignLayoutReader<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            content
                .environment(\.designLayout, DesignLayout(
                    size: CGSize(
                        width: proxy.size.width + insets.leading + insets.trailing,
                        height: proxy.size.height + insets.top + insets.bottom
                    ),
                    safeTop: insets.top,
                    safeBottom: insets.bottom
                ))
        }
    }
}

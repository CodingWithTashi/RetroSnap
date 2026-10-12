import SwiftUI

/// A control that floats over the viewfinder as "blurred ink".
/// The control draws only its tint; `GlassContainer` supplies the blur behind it.
nonisolated struct GlassRegion: Equatable {
    let bounds: Anchor<CGRect>
    let cornerRadius: CGFloat
    let visibility: Double
}

nonisolated struct GlassRegionsKey: PreferenceKey {
    static var defaultValue: [GlassRegion] { [] }

    static func reduce(value: inout [GlassRegion], nextValue: () -> [GlassRegion]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Tinted glass behind this view. `visibility` should follow the view's own opacity when it fades.
    nonisolated func glass(cornerRadius: CGFloat, tint: Color = RSColor.glass(), visibility: Double = 1) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .circular).fill(tint)
        }
        .anchorPreference(key: GlassRegionsKey.self, value: .bounds) { anchor in
            [GlassRegion(bounds: anchor, cornerRadius: cornerRadius, visibility: visibility)]
        }
    }
}

/// CSS `backdrop-filter: blur()` for content we draw ourselves: the backdrop is rendered a second time,
/// blurred, and shown only through the shapes of the glass controls above it.
struct GlassContainer<Backdrop: View, Content: View>: View {
    var blurRadius: CGFloat = 20
    @ViewBuilder var backdrop: Backdrop
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            backdrop
            content
                .backgroundPreferenceValue(GlassRegionsKey.self) { regions in
                    GeometryReader { proxy in
                        backdrop
                            // Flatten first: blur otherwise runs per layer and turns translucent ones opaque.
                            .compositingGroup()
                            .blur(radius: blurRadius, opaque: true)
                            .mask {
                                ZStack(alignment: .topLeading) {
                                    Color.clear
                                    ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                                        let rect = proxy[region.bounds]
                                        RoundedRectangle(cornerRadius: region.cornerRadius, style: .circular)
                                            .frame(width: rect.width, height: rect.height)
                                            .offset(x: rect.minX, y: rect.minY)
                                            .opacity(region.visibility)
                                    }
                                }
                            }
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

import Foundation

/// The numbers the Metal look functions take, worked out once from a render model.
/// The SwiftUI shaders and the Core Image kernels both read them from here.
nonisolated struct LookUniforms: Hashable, Sendable {
    /// One CSS filter step as the shader reads it.
    struct Operation: Hashable, Sendable {
        /// 0 none, 1 sepia, 2 saturate, 3 contrast, 4 brightness, 5 hue-rotate.
        let kind: Double
        /// The filter's amount; radians for hue-rotate.
        let amount: Double

        static let none = Operation(kind: 0, amount: 0)
    }

    /// Raw sRGB components and an opacity, so the shader sees the same numbers CSS does.
    struct Color: Hashable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double

        init(hex: UInt32, opacity: Double) {
            (red, green, blue) = rgbComponents(hex: hex)
            self.opacity = opacity
        }
    }

    /// The length of the filter chain in the shader.
    static let operationCount = 5

    let operations: [Operation]
    let tint: Color
    let warm: Color
    let flash: Double
    let fade: Double
    let chroma: Double
    let scan: Double
    let vignette: Double
    let grain: Double
    let brightness: Double
    let contrast: Double

    init(_ model: LookRenderModel) {
        operations = Self.operations(model.filters)
        tint = Color(hex: model.tintHex, opacity: model.tintOpacity)
        warm = Color(hex: model.warmHex, opacity: model.warmOpacity)
        flash = model.flashOpacity
        fade = model.fadeOpacity
        chroma = model.chromaOpacity
        scan = model.scanOpacity
        vignette = model.vignetteOpacity
        grain = model.grainOpacity
        brightness = model.brightness
        contrast = model.contrast
    }

    /// A filter chain as exactly `operationCount` steps, padded with steps that do nothing.
    static func operations(_ filters: [LookFilter]) -> [Operation] {
        let steps = filters.prefix(operationCount).map { filter in
            switch filter {
            case .sepia(let amount): Operation(kind: 1, amount: amount)
            case .saturate(let amount): Operation(kind: 2, amount: amount)
            case .contrast(let amount): Operation(kind: 3, amount: amount)
            case .brightness(let amount): Operation(kind: 4, amount: amount)
            case .hueRotate(let degrees): Operation(kind: 5, amount: degrees * .pi / 180)
            }
        }
        return steps + Array(repeating: .none, count: operationCount - steps.count)
    }
}

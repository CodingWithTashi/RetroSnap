import SwiftUI

/// The only place the Metal look shaders are called, so names and argument order live in one spot.
nonisolated enum LookShaders {
    static func filterChain(_ filters: [LookFilter]) -> Shader {
        var operations = filters.prefix(5).map(argument)
        while operations.count < 5 {
            operations.append(.float2(0, 0))
        }
        return ShaderLibrary.rsFilterChain(operations[0], operations[1], operations[2], operations[3], operations[4])
    }

    static func overlays(_ model: LookRenderModel) -> Shader {
        ShaderLibrary.rsOverlays(
            .boundingRect,
            color(model.tintHex, model.tintOpacity),
            color(model.warmHex, model.warmOpacity),
            .float4(model.flashOpacity, model.fadeOpacity, model.chromaOpacity, model.scanOpacity),
            .float2(model.vignetteOpacity, model.grainOpacity)
        )
    }

    static func adjust(brightness: Double, contrast: Double) -> Shader {
        ShaderLibrary.rsAdjust(.float(brightness), .float(contrast))
    }

    private static func argument(_ filter: LookFilter) -> Shader.Argument {
        switch filter {
        case .sepia(let amount): .float2(1, amount)
        case .saturate(let amount): .float2(2, amount)
        case .contrast(let amount): .float2(3, amount)
        case .brightness(let amount): .float2(4, amount)
        case .hueRotate(let degrees): .float2(5, degrees * .pi / 180)
        }
    }

    /// Raw sRGB components, so the shader sees the same numbers CSS does.
    private static func color(_ hex: UInt32, _ opacity: Double) -> Shader.Argument {
        .float4(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255,
            opacity
        )
    }
}

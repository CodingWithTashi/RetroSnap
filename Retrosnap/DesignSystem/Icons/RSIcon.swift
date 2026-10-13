import SwiftUI

/// The design's icons, as their original 24x24 SVG data.
nonisolated enum RSIcon: CaseIterable, Sendable {
    case bolt, boltSlash, timer
    case chevronUp, chevronDown, chevronLeft, chevronRight
    case check, close, flip, plus
    case camera, cameraSlash, photos, gear
    case share, sliders, printer, collage, trash
    case play

    fileprivate enum Element {
        case path(String)
        case circle(cx: CGFloat, cy: CGFloat, r: CGFloat)
        case roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat)
    }

    private static let cameraBody = "M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"

    fileprivate var elements: [Element] {
        switch self {
        case .bolt:
            [.path("M13 2 4.5 13.5H11l-1 8.5 8.5-11.5H12z")]
        case .boltSlash:
            [.path("M13 2 4.5 13.5H11l-1 8.5 8.5-11.5H12z"), .path("M3.5 3.5l17 17")]
        case .timer:
            [.circle(cx: 12, cy: 13, r: 8), .path("M12 9v4l2.5 2M9.5 2.5h5")]
        case .chevronUp:
            [.path("m6 15 6-6 6 6")]
        case .chevronDown:
            [.path("m6 9 6 6 6-6")]
        case .chevronLeft:
            [.path("m15 6-6 6 6 6")]
        case .chevronRight:
            [.path("m9 6 6 6-6 6")]
        case .check:
            [.path("m5 12 5 5 9-10")]
        case .close:
            [.path("M6 6l12 12M18 6 6 18")]
        case .flip:
            [.path("M4.5 10a8 8 0 0 1 14-3.5L20 8M19.5 14a8 8 0 0 1-14 3.5L4 16"), .path("M20 3.5V8h-4.5M4 20.5V16h4.5")]
        case .plus:
            [.path("M12 5v14M5 12h14")]
        case .camera:
            [.path(Self.cameraBody), .circle(cx: 12, cy: 13.5, r: 3.6)]
        case .cameraSlash:
            [.path(Self.cameraBody), .circle(cx: 12, cy: 13.5, r: 3.6), .path("M3 3l18 18")]
        case .photos:
            [.roundedRect(x: 3, y: 4, width: 18, height: 16, radius: 3), .path("m3 16 5-5 4 4 3-3 6 6"),
             .circle(cx: 16, cy: 9, r: 1.5)]
        case .gear:
            [.circle(cx: 12, cy: 12, r: 3),
             .path("M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1")]
        case .share:
            [.path("M12 3v12M7.5 7.5 12 3l4.5 4.5M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7")]
        case .sliders:
            [.path("M4 7h9M17 7h3M4 17h3M11 17h9M15 5v4M9 15v4")]
        case .printer:
            [.path("M7 9V3h10v6M5 17H4a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-1M7 14h10v7H7z")]
        case .collage:
            [.path("M4 3h6a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 3h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 13h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1z")]
        case .trash:
            [.path("M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v5M14 11v5")]
        case .play:
            [.path("M7 4.5v15l12.5-7.5z")]
        }
    }
}

/// An icon's outline scaled from its 24-unit view box to the given rectangle.
nonisolated struct RSIconShape: Shape {
    let icon: RSIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for element in icon.elements {
            switch element {
            case .path(let data):
                path.addPath(SVGPath.path(data))
            case .circle(let cx, let cy, let r):
                path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            case .roundedRect(let x, let y, let width, let height, let radius):
                path.addRoundedRect(
                    in: CGRect(x: x, y: y, width: width, height: height),
                    cornerSize: CGSize(width: radius, height: radius), style: .circular
                )
            }
        }
        let scale = min(rect.width, rect.height) / 24
        return path.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}

/// A stroked (or filled) icon. `lineWidth` is in the icon's own 24-unit space, like SVG `stroke-width`.
struct RSIconView: View {
    let icon: RSIcon
    var size: CGFloat = 24
    var lineWidth: CGFloat = 1.8
    var filled = false

    init(_ icon: RSIcon, size: CGFloat = 24, lineWidth: CGFloat = 1.8, filled: Bool = false) {
        self.icon = icon
        self.size = size
        self.lineWidth = lineWidth
        self.filled = filled
    }

    var body: some View {
        Group {
            if filled {
                RSIconShape(icon: icon).fill()
            } else {
                RSIconShape(icon: icon)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

import SwiftUI

/// Turns the `d` attribute of an SVG `<path>` into a `Path`, so icons are drawn from the design's own data.
/// Supports the commands the design uses: M, L, H, V, A and Z, absolute and relative.
nonisolated enum SVGPath {
    static func path(_ d: String) -> Path {
        var path = Path()
        var scanner = Scanner(d)
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var command: Character = "M"

        while let next = scanner.nextCommand(defaultingTo: command) {
            command = next
            let relative = command.isLowercase
            let origin = relative ? current : .zero

            switch command.uppercased() {
            case "M":
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                current = CGPoint(x: origin.x + x, y: origin.y + y)
                subpathStart = current
                path.move(to: current)
                // Coordinate pairs after the first are implicit line-tos.
                command = relative ? "l" : "L"
            case "L":
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                current = CGPoint(x: origin.x + x, y: origin.y + y)
                path.addLine(to: current)
            case "H":
                guard let x = scanner.number() else { return path }
                current = CGPoint(x: (relative ? current.x : 0) + x, y: current.y)
                path.addLine(to: current)
            case "V":
                guard let y = scanner.number() else { return path }
                current = CGPoint(x: current.x, y: (relative ? current.y : 0) + y)
                path.addLine(to: current)
            case "A":
                guard let rx = scanner.number(), let ry = scanner.number(), let rotation = scanner.number(),
                      let largeArc = scanner.flag(), let sweep = scanner.flag(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let end = CGPoint(x: origin.x + x, y: origin.y + y)
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry,
                       rotation: rotation * .pi / 180, largeArc: largeArc, sweep: sweep)
                current = end
            case "Z":
                path.closeSubpath()
                current = subpathStart
            default:
                return path
            }
        }
        return path
    }

    /// SVG endpoint arc, converted to its centre form and drawn as cubic segments of at most 90 degrees.
    private static func addArc(
        to path: inout Path, from start: CGPoint, to end: CGPoint,
        rx: CGFloat, ry: CGFloat, rotation: CGFloat, largeArc: Bool, sweep: Bool
    ) {
        guard start != end else { return }
        var rx = abs(rx), ry = abs(ry)
        guard rx > 0, ry > 0 else {
            path.addLine(to: end)
            return
        }
        let cosR = cos(rotation), sinR = sin(rotation)
        let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
        let x1 = cosR * dx + sinR * dy
        let y1 = -sinR * dx + cosR * dy

        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let scale = (largeArc != sweep ? 1 : -1) * max(0, numerator / denominator).squareRoot()
        let cxp = scale * rx * y1 / ry
        let cyp = -scale * ry * x1 / rx
        let center = CGPoint(
            x: cosR * cxp - sinR * cyp + (start.x + end.x) / 2,
            y: sinR * cxp + cosR * cyp + (start.y + end.y) / 2
        )

        let startAngle = atan2((y1 - cyp) / ry, (x1 - cxp) / rx)
        let endAngle = atan2((-y1 - cyp) / ry, (-x1 - cxp) / rx)
        var delta = endAngle - startAngle
        if sweep, delta < 0 { delta += 2 * .pi }
        if !sweep, delta > 0 { delta -= 2 * .pi }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(segments)
        let handle = 4 / 3 * tan(step / 4)

        func point(_ angle: CGFloat, _ tangent: CGFloat = 0) -> CGPoint {
            let ex = rx * (cos(angle) - tangent * sin(angle))
            let ey = ry * (sin(angle) + tangent * cos(angle))
            return CGPoint(x: center.x + cosR * ex - sinR * ey, y: center.y + sinR * ex + cosR * ey)
        }

        var angle = startAngle
        for _ in 0..<segments {
            let next = angle + step
            path.addCurve(to: point(next), control1: point(angle, handle), control2: point(next, -handle))
            angle = next
        }
    }

    private struct Scanner {
        private let characters: [Character]
        private var index = 0

        init(_ string: String) {
            characters = Array(string)
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index].isWhitespace || characters[index] == "," {
                index += 1
            }
        }

        /// The next command letter, or the previous command again when the data continues with numbers.
        mutating func nextCommand(defaultingTo previous: Character) -> Character? {
            skipSeparators()
            guard index < characters.count else { return nil }
            let character = characters[index]
            if character.isLetter {
                index += 1
                return character
            }
            return previous.uppercased() == "Z" ? nil : previous
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            var text = ""
            var seenDot = false
            if index < characters.count, characters[index] == "-" || characters[index] == "+" {
                text.append(characters[index])
                index += 1
            }
            while index < characters.count {
                let character = characters[index]
                if character.isNumber {
                    text.append(character)
                } else if character == ".", !seenDot {
                    seenDot = true
                    text.append(character)
                } else {
                    break
                }
                index += 1
            }
            return Double(text).map { CGFloat($0) }
        }

        /// Arc flags are single digits and may be written without separators.
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < characters.count, characters[index] == "0" || characters[index] == "1" else { return nil }
            defer { index += 1 }
            return characters[index] == "1"
        }
    }
}

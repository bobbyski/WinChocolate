/// A minimal SVG path-data (`d` attribute) parser producing an `NSBezierPath`.
///
/// Framework-internal: covers the command grammar Tabler outline icons use —
/// `M/m L/l H/h V/v C/c S/s Q/q A/a Z/z` with implicit command repetition —
/// so the framework can render its stock glyph artwork (see
/// `WinTablerIcons`) as crisp strokes at any size. Elliptical arcs convert to
/// cubic Béziers with the standard endpoint-to-center parameterization.
enum WinSVGPath {
    /// Parses one `d` string into a bezier path (24×24 icon space).
    static func path(from d: String) -> NSBezierPath {
        let path = NSBezierPath()
        var scanner = Scanner(text: d)
        var state = PathState(path: path)

        while let command = scanner.nextCommand() {
            var cmd = command
            repeat {
                let applied: Bool
                if "MmLlHhVv".contains(cmd) {
                    applied = applyLinearCommand(&cmd, scanner: &scanner, state: &state)
                } else if "CcSsQq".contains(cmd) {
                    applied = applyCurveCommand(cmd, scanner: &scanner, state: &state)
                } else if cmd == "A" || cmd == "a" {
                    applied = applyArcCommand(cmd, scanner: &scanner, state: &state)
                } else if cmd == "Z" || cmd == "z" {
                    state.path.close()
                    state.current = state.subpathStart
                    state.lastControl = nil
                    applied = true
                } else {
                    applied = false
                }
                guard applied else { return path }
                state.lastCommand = cmd
            } while scanner.hasMoreNumbers() && cmd != "Z" && cmd != "z"
        }

        return path
    }

    private struct PathState {
        let path: NSBezierPath
        var current = NSPoint(x: 0, y: 0)
        var subpathStart = NSPoint(x: 0, y: 0)
        var lastControl: NSPoint?
        var lastCommand: Character = " "
    }

    private static func applyLinearCommand(
        _ command: inout Character, scanner: inout Scanner, state: inout PathState
    ) -> Bool {
        switch command {
        case "M", "m":
            guard let point = scanner.nextPoint() else { return false }
            state.current = absolutePoint(point, relative: command == "m", from: state.current)
            state.path.move(to: state.current)
            state.subpathStart = state.current
            command = command == "m" ? "l" : "L"
        case "L", "l":
            guard let point = scanner.nextPoint() else { return false }
            state.current = absolutePoint(point, relative: command == "l", from: state.current)
            state.path.line(to: state.current)
        case "H", "h":
            guard let x = scanner.nextNumber() else { return false }
            state.current.x = command == "h" ? state.current.x + x : x
            state.path.line(to: state.current)
        case "V", "v":
            guard let y = scanner.nextNumber() else { return false }
            state.current.y = command == "v" ? state.current.y + y : y
            state.path.line(to: state.current)
        default:
            return false
        }
        state.lastControl = nil
        return true
    }

    private static func applyCurveCommand(
        _ command: Character, scanner: inout Scanner, state: inout PathState
    ) -> Bool {
        switch command {
        case "C", "c": return applyCubicCommand(command, scanner: &scanner, state: &state)
        case "S", "s": return applySmoothCommand(command, scanner: &scanner, state: &state)
        case "Q", "q": return applyQuadraticCommand(command, scanner: &scanner, state: &state)
        default: return false
        }
    }

    private static func applyCubicCommand(
        _ command: Character, scanner: inout Scanner, state: inout PathState
    ) -> Bool {
        guard let first = scanner.nextPoint(), let second = scanner.nextPoint(), let endpoint = scanner.nextPoint() else {
            return false
        }
        let relative = command == "c"
        let control1 = absolutePoint(first, relative: relative, from: state.current)
        let control2 = absolutePoint(second, relative: relative, from: state.current)
        let end = absolutePoint(endpoint, relative: relative, from: state.current)
        state.path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
        state.lastControl = control2
        state.current = end
        return true
    }

    private static func applySmoothCommand(
        _ command: Character, scanner: inout Scanner, state: inout PathState
    ) -> Bool {
        guard let second = scanner.nextPoint(), let endpoint = scanner.nextPoint() else { return false }
        let relative = command == "s"
        let control1 = reflectedControl(for: state)
        let control2 = absolutePoint(second, relative: relative, from: state.current)
        let end = absolutePoint(endpoint, relative: relative, from: state.current)
        state.path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
        state.lastControl = control2
        state.current = end
        return true
    }

    private static func applyQuadraticCommand(
        _ command: Character, scanner: inout Scanner, state: inout PathState
    ) -> Bool {
        guard let control = scanner.nextPoint(), let endpoint = scanner.nextPoint() else { return false }
        let relative = command == "q"
        let quadratic = absolutePoint(control, relative: relative, from: state.current)
        let end = absolutePoint(endpoint, relative: relative, from: state.current)
        let control1 = NSPoint(
            x: state.current.x + 2 / 3 * (quadratic.x - state.current.x),
            y: state.current.y + 2 / 3 * (quadratic.y - state.current.y)
        )
        let control2 = NSPoint(
            x: end.x + 2 / 3 * (quadratic.x - end.x),
            y: end.y + 2 / 3 * (quadratic.y - end.y)
        )
        state.path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
        state.lastControl = quadratic
        state.current = end
        return true
    }

    private static func applyArcCommand(
        _ command: Character, scanner: inout Scanner, state: inout PathState
    ) -> Bool {
        guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
              let rotation = scanner.nextNumber(),
              let largeArc = scanner.nextFlag(), let sweep = scanner.nextFlag(),
              let endpoint = scanner.nextPoint() else { return false }
        let end = absolutePoint(endpoint, relative: command == "a", from: state.current)
        let arc = ArcCommand(
            start: state.current, end: end, radiusX: rx, radiusY: ry,
            rotationDegrees: rotation, largeArc: largeArc, sweep: sweep
        )
        appendArc(to: state.path, command: arc)
        state.current = end
        state.lastControl = nil
        return true
    }

    private static func absolutePoint(_ point: NSPoint, relative: Bool, from current: NSPoint) -> NSPoint {
        relative ? NSPoint(x: current.x + point.x, y: current.y + point.y) : point
    }

    private static func reflectedControl(for state: PathState) -> NSPoint {
        guard let control = state.lastControl, "CcSs".contains(state.lastCommand) else {
            return state.current
        }
        return NSPoint(x: 2 * state.current.x - control.x, y: 2 * state.current.y - control.y)
    }

    /// Converts one SVG elliptical arc into cubic Bézier segments
    /// (endpoint → center parameterization, W3C algorithm).
    private static func appendArc(to path: NSBezierPath, command: ArcCommand) {
        let start = command.start
        let end = command.end
        var rx = abs(command.radiusX), ry = abs(command.radiusY)
        if rx == 0 || ry == 0 || (start.x == end.x && start.y == end.y) {
            path.line(to: end)
            return
        }

        let phi = command.rotationDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        // Step 1: (x1', y1')
        let dx = (Double(start.x) - Double(end.x)) / 2
        let dy = (Double(start.y) - Double(end.y)) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // Correct out-of-range radii.
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let scale = lambda.squareRoot()
            rx *= scale
            ry *= scale
        }

        // Step 2: (cx', cy')
        let rxSq = rx * rx, rySq = ry * ry
        let numerator = max(0, rxSq * rySq - rxSq * y1p * y1p - rySq * x1p * x1p)
        let denominator = rxSq * y1p * y1p + rySq * x1p * x1p
        var coefficient = denominator == 0 ? 0 : (numerator / denominator).squareRoot()
        if command.largeArc == command.sweep {
            coefficient = -coefficient
        }
        let cxp = coefficient * rx * y1p / ry
        let cyp = -coefficient * ry * x1p / rx

        // Step 3: center
        let cx = cosPhi * cxp - sinPhi * cyp + (Double(start.x) + Double(end.x)) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (Double(start.y) + Double(end.y)) / 2

        let startAngle = vectorAngle(x: 1, y: 0, toX: (x1p - cxp) / rx, toY: (y1p - cyp) / ry)
        var sweepAngle = vectorAngle(
            x: (x1p - cxp) / rx, y: (y1p - cyp) / ry,
            toX: (-x1p - cxp) / rx, toY: (-y1p - cyp) / ry
        )
        if !command.sweep, sweepAngle > 0 {
            sweepAngle -= 2 * .pi
        } else if command.sweep, sweepAngle < 0 {
            sweepAngle += 2 * .pi
        }

        let geometry = ArcGeometry(rx: rx, ry: ry, cx: cx, cy: cy, cosPhi: cosPhi, sinPhi: sinPhi)
        appendArcSegments(to: path, geometry: geometry, startAngle: startAngle, sweepAngle: sweepAngle)
    }

    private static func vectorAngle(x: Double, y: Double, toX: Double, toY: Double) -> Double {
        let dot = x * toX + y * toY
        let length = ((x * x + y * y) * (toX * toX + toY * toY)).squareRoot()
        guard length > 0 else { return 0 }
        let magnitude = acos(min(1, max(-1, dot / length)))
        return x * toY - y * toX < 0 ? -magnitude : magnitude
    }

    private static func appendArcSegments(
        to path: NSBezierPath, geometry: ArcGeometry, startAngle: Double, sweepAngle: Double
    ) {

        // Split into ≤90° segments, each as one cubic.
        let segmentCount = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
        let delta = sweepAngle / Double(segmentCount)
        let t = 4 / 3 * tan(delta / 4)

        var angleCursor = startAngle
        for _ in 0..<segmentCount {
            let cos1 = cos(angleCursor), sin1 = sin(angleCursor)
            let angleNext = angleCursor + delta
            let cos2 = cos(angleNext), sin2 = sin(angleNext)

            let p1 = geometry.point(cosine: cos1, sine: sin1)
            let p2 = geometry.point(cosine: cos2, sine: sin2)
            let d1 = geometry.derivative(cosine: cos1, sine: sin1)
            let d2 = geometry.derivative(cosine: cos2, sine: sin2)
            let control1 = NSPoint(x: Double(p1.x) + t * d1.x, y: Double(p1.y) + t * d1.y)
            let control2 = NSPoint(x: Double(p2.x) - t * d2.x, y: Double(p2.y) - t * d2.y)
            path.curve(to: p2, controlPoint1: control1, controlPoint2: control2)
            angleCursor = angleNext
        }
    }

    private struct ArcCommand {
        let start: NSPoint
        let end: NSPoint
        let radiusX: Double
        let radiusY: Double
        let rotationDegrees: Double
        let largeArc: Bool
        let sweep: Bool
    }

    private struct ArcGeometry {
        let rx: Double
        let ry: Double
        let cx: Double
        let cy: Double
        let cosPhi: Double
        let sinPhi: Double

        func point(cosine: Double, sine: Double) -> NSPoint {
            NSPoint(
                x: cx + rx * cosine * cosPhi - ry * sine * sinPhi,
                y: cy + rx * cosine * sinPhi + ry * sine * cosPhi
            )
        }

        func derivative(cosine: Double, sine: Double) -> NSPoint {
            NSPoint(
                x: -rx * sine * cosPhi - ry * cosine * sinPhi,
                y: -rx * sine * sinPhi + ry * cosine * cosPhi
            )
        }
    }

    /// A tiny tokenizer over the `d` grammar.
    private struct Scanner {
        private let characters: [Character]
        private var index = 0

        init(text: String) {
            characters = Array(text)
        }

        private mutating func skipSeparators() {
            while index < characters.count, characters[index] == " " || characters[index] == "," || characters[index] == "\n" || characters[index] == "\t" {
                index += 1
            }
        }

        mutating func nextCommand() -> Character? {
            skipSeparators()
            guard index < characters.count else { return nil }
            let character = characters[index]
            guard character.isLetter else { return nil }
            index += 1
            return character
        }

        mutating func hasMoreNumbers() -> Bool {
            skipSeparators()
            guard index < characters.count else { return false }
            let character = characters[index]
            return character.isNumber || character == "-" || character == "." || character == "+"
        }

        mutating func nextNumber() -> Double? {
            skipSeparators()
            var text = ""
            var sawDot = false
            while index < characters.count {
                let character = characters[index]
                if character.isNumber || (text.isEmpty && (character == "-" || character == "+")) {
                    text.append(character)
                } else if character == ".", !sawDot {
                    sawDot = true
                    text.append(character)
                } else if character == "-", !text.isEmpty {
                    break
                } else {
                    break
                }
                index += 1
            }
            return Double(text)
        }

        mutating func nextPoint() -> NSPoint? {
            guard let x = nextNumber(), let y = nextNumber() else {
                return nil
            }
            return NSPoint(x: x, y: y)
        }

        /// Arc flags are single `0`/`1` digits that may be run together.
        mutating func nextFlag() -> Bool? {
            skipSeparators()
            guard index < characters.count, characters[index] == "0" || characters[index] == "1" else { return nil }
            let flag = characters[index] == "1"
            index += 1
            return flag
        }
    }
}

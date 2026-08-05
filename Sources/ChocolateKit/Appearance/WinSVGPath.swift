import WinFoundation

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

        var current = NSPoint(x: 0, y: 0)
        var subpathStart = current
        var lastControl: NSPoint?
        var lastCommand: Character = " "

        while let command = scanner.nextCommand() {
            var cmd = command
            repeat {
                switch cmd {
                case "M", "m":
                    guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                    current = cmd == "m" ? NSPoint(x: current.x + x, y: current.y + y) : NSPoint(x: x, y: y)
                    path.move(to: current)
                    subpathStart = current
                    // Subsequent coordinate pairs are implicit linetos.
                    cmd = cmd == "m" ? "l" : "L"
                    lastControl = nil
                case "L", "l":
                    guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                    current = cmd == "l" ? NSPoint(x: current.x + x, y: current.y + y) : NSPoint(x: x, y: y)
                    path.line(to: current)
                    lastControl = nil
                case "H", "h":
                    guard let x = scanner.nextNumber() else { return path }
                    current = NSPoint(x: cmd == "h" ? current.x + x : x, y: current.y)
                    path.line(to: current)
                    lastControl = nil
                case "V", "v":
                    guard let y = scanner.nextNumber() else { return path }
                    current = NSPoint(x: current.x, y: cmd == "v" ? current.y + y : y)
                    path.line(to: current)
                    lastControl = nil
                case "C", "c":
                    guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                          let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                          let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                    let base = cmd == "c" ? current : NSPoint(x: 0, y: 0)
                    let c1 = NSPoint(x: base.x + x1, y: base.y + y1)
                    let c2 = NSPoint(x: base.x + x2, y: base.y + y2)
                    let end = NSPoint(x: base.x + x, y: base.y + y)
                    path.curve(to: end, controlPoint1: c1, controlPoint2: c2)
                    lastControl = c2
                    current = end
                case "S", "s":
                    guard let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                          let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                    let base = cmd == "s" ? current : NSPoint(x: 0, y: 0)
                    let reflected: NSPoint
                    if let lastControl, lastCommand == "C" || lastCommand == "c" || lastCommand == "S" || lastCommand == "s" {
                        reflected = NSPoint(x: 2 * current.x - lastControl.x, y: 2 * current.y - lastControl.y)
                    } else {
                        reflected = current
                    }
                    let c2 = NSPoint(x: base.x + x2, y: base.y + y2)
                    let end = NSPoint(x: base.x + x, y: base.y + y)
                    path.curve(to: end, controlPoint1: reflected, controlPoint2: c2)
                    lastControl = c2
                    current = end
                case "Q", "q":
                    guard let qx = scanner.nextNumber(), let qy = scanner.nextNumber(),
                          let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                    let base = cmd == "q" ? current : NSPoint(x: 0, y: 0)
                    let q = NSPoint(x: base.x + qx, y: base.y + qy)
                    let end = NSPoint(x: base.x + x, y: base.y + y)
                    // Quadratic → cubic elevation.
                    let c1 = NSPoint(x: current.x + 2 / 3 * (q.x - current.x), y: current.y + 2 / 3 * (q.y - current.y))
                    let c2 = NSPoint(x: end.x + 2 / 3 * (q.x - end.x), y: end.y + 2 / 3 * (q.y - end.y))
                    path.curve(to: end, controlPoint1: c1, controlPoint2: c2)
                    lastControl = q
                    current = end
                case "A", "a":
                    guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
                          let rotation = scanner.nextNumber(),
                          let largeArc = scanner.nextFlag(), let sweep = scanner.nextFlag(),
                          let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return path }
                    let end = cmd == "a" ? NSPoint(x: current.x + x, y: current.y + y) : NSPoint(x: x, y: y)
                    appendArc(to: path, from: current, to: end,
                              rx: rx, ry: ry, rotationDegrees: rotation,
                              largeArc: largeArc, sweep: sweep)
                    current = end
                    lastControl = nil
                case "Z", "z":
                    path.close()
                    current = subpathStart
                    lastControl = nil
                default:
                    return path
                }
                lastCommand = cmd
            } while scanner.hasMoreNumbers() && cmd != "Z" && cmd != "z"
        }

        return path
    }

    /// Converts one SVG elliptical arc into cubic Bézier segments
    /// (endpoint → center parameterization, W3C algorithm).
    private static func appendArc(to path: NSBezierPath, from start: NSPoint, to end: NSPoint,
                                  rx radiusX: Double, ry radiusY: Double, rotationDegrees: Double,
                                  largeArc: Bool, sweep: Bool) {
        var rx = abs(radiusX), ry = abs(radiusY)
        if rx == 0 || ry == 0 || (start.x == end.x && start.y == end.y) {
            path.line(to: end)
            return
        }

        let phi = rotationDegrees * .pi / 180
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
        if largeArc == sweep {
            coefficient = -coefficient
        }
        let cxp = coefficient * rx * y1p / ry
        let cyp = -coefficient * ry * x1p / rx

        // Step 3: center
        let cx = cosPhi * cxp - sinPhi * cyp + (Double(start.x) + Double(end.x)) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (Double(start.y) + Double(end.y)) / 2

        // Step 4: angles
        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let length = ((ux * ux + uy * uy) * (vx * vx + vy * vy)).squareRoot()
            guard length > 0 else { return 0 }
            var value = acos(min(1, max(-1, dot / length)))
            if ux * vy - uy * vx < 0 {
                value = -value
            }
            return value
        }
        let startAngle = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var sweepAngle = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep, sweepAngle > 0 {
            sweepAngle -= 2 * .pi
        } else if sweep, sweepAngle < 0 {
            sweepAngle += 2 * .pi
        }

        // Split into ≤90° segments, each as one cubic.
        let segmentCount = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
        let delta = sweepAngle / Double(segmentCount)
        let t = 4 / 3 * tan(delta / 4)

        var angleCursor = startAngle
        for _ in 0..<segmentCount {
            let cos1 = cos(angleCursor), sin1 = sin(angleCursor)
            let angleNext = angleCursor + delta
            let cos2 = cos(angleNext), sin2 = sin(angleNext)

            func onEllipse(_ c: Double, _ s: Double) -> NSPoint {
                NSPoint(
                    x: cx + rx * c * cosPhi - ry * s * sinPhi,
                    y: cy + rx * c * sinPhi + ry * s * cosPhi
                )
            }
            func derivative(_ c: Double, _ s: Double) -> (Double, Double) {
                (-rx * s * cosPhi - ry * c * sinPhi, -rx * s * sinPhi + ry * c * cosPhi)
            }

            let p1 = onEllipse(cos1, sin1)
            let p2 = onEllipse(cos2, sin2)
            let d1 = derivative(cos1, sin1)
            let d2 = derivative(cos2, sin2)
            let control1 = NSPoint(x: Double(p1.x) + t * d1.0, y: Double(p1.y) + t * d1.1)
            let control2 = NSPoint(x: Double(p2.x) - t * d2.0, y: Double(p2.y) - t * d2.1)
            path.curve(to: p2, controlPoint1: control1, controlPoint2: control2)
            angleCursor = angleNext
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

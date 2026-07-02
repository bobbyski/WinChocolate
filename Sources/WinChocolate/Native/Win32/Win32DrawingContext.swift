#if os(Windows)
/// GDI-backed drawing surface used during `WM_PAINT` for custom views.
///
/// Path segments are replayed onto the device context with the GDI path API
/// (`BeginPath`/`MoveToEx`/`LineTo`/`PolyBezierTo`/`EndPath`) and rasterized
/// with `FillPath`/`StrokePath`, so lines and cubic Bezier curves render
/// natively. The context is only valid for the duration of one paint pass.
internal final class Win32DrawingContext: NativeDrawingContext {
    private let deviceContext: HDC

    internal init(deviceContext: HDC) {
        self.deviceContext = deviceContext
        _ = winSetPolyFillMode(deviceContext, windingFillMode)
    }

    /// Fills a path with a color using the nonzero winding rule.
    internal func fillPath(_ segments: [NativePathSegment], color: NSColor) {
        guard let brush = winCreateSolidBrush(colorRef(from: color)) else {
            return
        }
        defer {
            _ = winDeleteObject(brush)
        }

        let previousBrush = winSelectObject(deviceContext, brush)
        buildPath(segments)
        _ = winFillPath(deviceContext)
        _ = winSelectObject(deviceContext, previousBrush ?? nil)
    }

    /// Strokes a path with a color and line width.
    internal func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat) {
        guard let pen = winCreatePen(psSolid, Int32(max(lineWidth.rounded(), 1)), colorRef(from: color)) else {
            return
        }
        defer {
            _ = winDeleteObject(pen)
        }

        let previousPen = winSelectObject(deviceContext, pen)
        buildPath(segments)
        _ = winStrokePath(deviceContext)
        _ = winSelectObject(deviceContext, previousPen ?? nil)
    }

    /// Replays segments into an open GDI path on the device context.
    private func buildPath(_ segments: [NativePathSegment]) {
        _ = winBeginPath(deviceContext)
        for segment in segments {
            switch segment {
            case .move(let point):
                _ = winMoveToEx(deviceContext, Int32(point.x.rounded()), Int32(point.y.rounded()), nil)
            case .line(let point):
                _ = winLineTo(deviceContext, Int32(point.x.rounded()), Int32(point.y.rounded()))
            case .curve(let endPoint, let control1, let control2):
                let points = [
                    POINT(x: Int32(control1.x.rounded()), y: Int32(control1.y.rounded())),
                    POINT(x: Int32(control2.x.rounded()), y: Int32(control2.y.rounded())),
                    POINT(x: Int32(endPoint.x.rounded()), y: Int32(endPoint.y.rounded()))
                ]
                points.withUnsafeBufferPointer { pointer in
                    _ = winPolyBezierTo(deviceContext, pointer.baseAddress, 3)
                }
            case .close:
                _ = winCloseFigure(deviceContext)
            }
        }
        _ = winEndPath(deviceContext)
    }

    private func colorRef(from color: NSColor) -> DWORD {
        let red = DWORD((min(max(color.redComponent, 0), 1) * 255).rounded()) & 0xff
        let green = DWORD((min(max(color.greenComponent, 0), 1) * 255).rounded()) & 0xff
        let blue = DWORD((min(max(color.blueComponent, 0), 1) * 255).rounded()) & 0xff
        return red | (green << 8) | (blue << 16)
    }
}
#endif

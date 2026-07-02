#if os(Windows)
/// GDI-backed drawing surface used during `WM_PAINT` for custom views.
///
/// Path segments are replayed onto the device context with the GDI path API
/// (`BeginPath`/`MoveToEx`/`LineTo`/`PolyBezierTo`/`EndPath`) and rasterized
/// with `FillPath`/`StrokePath`, so lines and cubic Bezier curves render
/// natively. Text runs render with `TextOutW` and images blit with a GDI+
/// decode plus `StretchBlt`. The context is only valid for the duration of one
/// paint pass.
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

    /// Draws a single-line text run with `TextOutW` using a transient font.
    internal func drawText(_ text: String, at point: NSPoint, color: NSColor, fontName: String, fontSize: CGFloat, bold: Bool) {
        let font = withWideString(fontName) { faceName in
            winCreateFontW(
                -Int32(max(fontSize.rounded(), 1)),
                0,
                0,
                0,
                bold ? 700 : 400,
                0,
                0,
                0,
                defaultCharset,
                defaultPrecision,
                defaultPrecision,
                defaultQuality,
                defaultPitchAndFamily,
                faceName
            )
        }
        guard let font else {
            return
        }
        defer {
            _ = winDeleteObject(font)
        }

        let previousFont = winSelectObject(deviceContext, font)
        let previousColor = winSetTextColor(deviceContext, colorRef(from: color))
        let previousBkMode = winSetBkMode(deviceContext, transparentBkMode)
        let characters = Array(text.utf16)
        characters.withUnsafeBufferPointer { buffer in
            _ = winTextOutW(deviceContext, Int32(point.x.rounded()), Int32(point.y.rounded()), buffer.baseAddress, Int32(buffer.count))
        }
        _ = winSetBkMode(deviceContext, previousBkMode)
        _ = winSetTextColor(deviceContext, previousColor)
        _ = winSelectObject(deviceContext, previousFont ?? nil)
    }

    /// Draws an image file scaled into a rectangle with a halftone `StretchBlt`.
    ///
    /// First slice: the bitmap is decoded, blitted, and released on every call.
    /// A per-path bitmap cache can replace this once repaint traffic warrants it.
    internal func drawImage(atPath path: String, in rect: NSRect) {
        guard let decoded = Win32GdiPlusImageDecoder.decodeBitmap(fromFile: path), decoded.width > 0, decoded.height > 0 else {
            return
        }
        defer {
            _ = winDeleteObject(decoded.bitmap)
        }

        guard let memoryContext = winCreateCompatibleDC(deviceContext) else {
            return
        }
        defer {
            _ = winDeleteDC(memoryContext)
        }

        let previousBitmap = winSelectObject(memoryContext, decoded.bitmap)
        let previousStretchMode = winSetStretchBltMode(deviceContext, halftoneStretchMode)
        _ = winStretchBlt(
            deviceContext,
            Int32(rect.origin.x.rounded()),
            Int32(rect.origin.y.rounded()),
            Int32(rect.size.width.rounded()),
            Int32(rect.size.height.rounded()),
            memoryContext,
            0,
            0,
            decoded.width,
            decoded.height,
            srcCopyRasterOperation
        )
        _ = winSetStretchBltMode(deviceContext, previousStretchMode)
        _ = winSelectObject(memoryContext, previousBitmap ?? nil)
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

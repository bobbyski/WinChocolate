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
    internal func drawText(_ text: String, at point: NSPoint, color: NSColor, fontName: String, fontSize: CGFloat, weight: Int, italic: Bool) {
        let font = withWideString(fontName) { faceName in
            // Points convert to pixels at 96 DPI, matching setFont rendering.
            winCreateFontW(
                -Int32(max((fontSize * 96.0 / 72.0).rounded(), 1)),
                0,
                0,
                0,
                Int32(weight),
                italic ? 1 : 0,
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

    /// Draws an image file scaled into a rectangle.
    ///
    /// Untinted images blit a cache-owned decoded bitmap with a halftone
    /// `StretchBlt`. A tint renders through a GDI+ color matrix instead, so the
    /// tint color takes the image's alpha shape and blends over the existing
    /// pixels — template-image drawing.
    internal func drawImage(atPath path: String, in rect: NSRect, tint: NSColor?) {
        if let tint {
            drawTintedImage(atPath: path, in: rect, tint: tint)
            return
        }

        guard let decoded = Win32GdiPlusImageDecoder.cachedBitmap(fromFile: path), decoded.width > 0, decoded.height > 0 else {
            return
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

    /// Draws an image tinted through a GDI+ color matrix (template rendering).
    private func drawTintedImage(atPath path: String, in rect: NSRect, tint: NSColor) {
        guard Win32GdiPlusImageDecoder.ensureStarted() else {
            return
        }

        var image: UnsafeMutableRawPointer?
        let createStatus = withWideString(path) { widePath in
            winGdipCreateBitmapFromFile(widePath, &image)
        }
        guard createStatus == gdiplusOkStatus, let image else {
            return
        }
        defer {
            _ = winGdipDisposeImage(image)
        }

        var width: UINT = 0
        var height: UINT = 0
        _ = winGdipGetImageWidth(image, &width)
        _ = winGdipGetImageHeight(image, &height)
        guard width > 0, height > 0 else {
            return
        }

        var graphics: UnsafeMutableRawPointer?
        guard winGdipCreateFromHDC(deviceContext, &graphics) == gdiplusOkStatus, let graphics else {
            return
        }
        defer {
            _ = winGdipDeleteGraphics(graphics)
        }

        var attributes: UnsafeMutableRawPointer?
        guard winGdipCreateImageAttributes(&attributes) == gdiplusOkStatus, let attributes else {
            return
        }
        defer {
            _ = winGdipDisposeImageAttributes(attributes)
        }
        let matrix = Win32GdiPlusImageDecoder.tintColorMatrix(
            red: Float(tint.redComponent),
            green: Float(tint.greenComponent),
            blue: Float(tint.blueComponent),
            alpha: Float(tint.alphaComponent)
        )
        let matrixStatus = matrix.withUnsafeBufferPointer { buffer in
            winGdipSetImageAttributesColorMatrix(attributes, 0, 1, buffer.baseAddress, nil, 0)
        }
        guard matrixStatus == gdiplusOkStatus else {
            return
        }

        _ = winGdipDrawImageRectRectI(
            graphics, image,
            Int32(rect.origin.x.rounded()),
            Int32(rect.origin.y.rounded()),
            Int32(rect.size.width.rounded()),
            Int32(rect.size.height.rounded()),
            0, 0, Int32(width), Int32(height),
            gdiplusUnitPixel, attributes, nil, nil
        )
    }

    /// Fills a rectangle with a GDI+ linear gradient along an angle.
    ///
    /// GDI has no gradient brush for arbitrary angles, so the fill goes
    /// through a GDI+ graphics created over the same device context, which
    /// inherits the current GDI clip region. The rect-with-angle brush avoids
    /// the two-point brush's failure on purely vertical axes. AppKit angles
    /// are counterclockwise toward the view's top while GDI+ angles run
    /// clockwise in the flipped device space, so the angle negates.
    internal func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat) {
        guard stops.count >= 2, Win32GdiPlusImageDecoder.ensureStarted() else {
            return
        }

        var graphics: UnsafeMutableRawPointer?
        guard winGdipCreateFromHDC(deviceContext, &graphics) == gdiplusOkStatus, let graphics else {
            return
        }
        defer {
            _ = winGdipDeleteGraphics(graphics)
        }

        var brushRect = GdipRectF(
            x: Float(rect.origin.x),
            y: Float(rect.origin.y),
            width: Float(rect.size.width),
            height: Float(rect.size.height)
        )
        var brush: UnsafeMutableRawPointer?
        let created = withUnsafePointer(to: &brushRect) { rectPointer in
            winGdipCreateLineBrushFromRectWithAngle(
                rectPointer,
                argb(from: stops[0].color),
                argb(from: stops[stops.count - 1].color),
                Float(-angle),
                0,
                gdiplusWrapModeTileFlipXY,
                &brush
            )
        }
        guard created == gdiplusOkStatus, let brush else {
            return
        }
        defer {
            _ = winGdipDeleteBrush(brush)
        }

        // Preset blends require positions starting at 0 and ending at 1.
        var colors: [UInt32] = []
        var positions: [Float] = []
        if let first = stops.first, first.location > 0 {
            colors.append(argb(from: first.color))
            positions.append(0)
        }
        for stop in stops {
            colors.append(argb(from: stop.color))
            positions.append(Float(min(max(stop.location, 0), 1)))
        }
        if let last = stops.last, last.location < 1 {
            colors.append(argb(from: last.color))
            positions.append(1)
        }
        colors.withUnsafeBufferPointer { colorPointer in
            positions.withUnsafeBufferPointer { positionPointer in
                _ = winGdipSetLinePresetBlend(brush, colorPointer.baseAddress, positionPointer.baseAddress, Int32(colors.count))
            }
        }

        _ = winGdipFillRectangle(
            graphics,
            brush,
            Float(rect.origin.x),
            Float(rect.origin.y),
            Float(rect.size.width),
            Float(rect.size.height)
        )
    }

    /// Intersects the device context's clip region with a path.
    internal func clip(to segments: [NativePathSegment]) {
        buildPath(segments)
        _ = winSelectClipPath(deviceContext, rgnAnd)
    }

    /// Saves the device-context state, including the clip region.
    internal func saveState() {
        _ = winSaveDC(deviceContext)
    }

    /// Restores the most recently saved device-context state.
    internal func restoreState() {
        _ = winRestoreDC(deviceContext, -1)
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

    /// GDI+ 0xAARRGGBB color value.
    private func argb(from color: NSColor) -> UInt32 {
        let alpha = UInt32((min(max(color.alphaComponent, 0), 1) * 255).rounded()) & 0xff
        let red = UInt32((min(max(color.redComponent, 0), 1) * 255).rounded()) & 0xff
        let green = UInt32((min(max(color.greenComponent, 0), 1) * 255).rounded()) & 0xff
        let blue = UInt32((min(max(color.blueComponent, 0), 1) * 255).rounded()) & 0xff
        return (alpha << 24) | (red << 16) | (green << 8) | blue
    }
}
#endif

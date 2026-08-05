#if os(Windows)
/// GDI+-backed image decoding shared by image views and drawing contexts.
///
/// `LoadImageW` only understands BMP files, so PNG/JPEG/GIF sources go through
/// the GDI+ flat C API instead: decode with `GdipCreateBitmapFromFile`, convert
/// to a plain GDI `HBITMAP` with `GdipCreateHBITMAPFromBitmap`, and hand the
/// result to the same `HBITMAP` ownership paths BMP loads already use. GDI+ is
/// started lazily once per process; the startup token is intentionally never
/// released because decoding can be requested for the process lifetime.
enum Win32GdiPlusImageDecoder {
    // Decoding happens on the native UI thread during control updates and
    // paint dispatch, matching the backend's single-threaded access pattern.
    nonisolated(unsafe) private static var startupToken: UInt = 0
    nonisolated(unsafe) private static var startupAttempted = false
    nonisolated(unsafe) private static var isStarted = false

    /// A decoded GDI bitmap and its pixel dimensions. The caller owns the
    /// `HBITMAP` and must release it with `DeleteObject`.
    struct DecodedBitmap {
        /// The converted GDI bitmap handle.
        var bitmap: HBITMAP

        /// The source image width in pixels.
        var width: Int32

        /// The source image height in pixels.
        var height: Int32
    }

    /// Decodes an image file (PNG, JPEG, GIF, BMP, ...) into a GDI bitmap.
    ///
    /// Alpha is composited over a white background because plain `HBITMAP`
    /// targets (`STM_SETIMAGE`, `StretchBlt`) carry no alpha channel.
    static func decodeBitmap(fromFile path: String) -> DecodedBitmap? {
        guard !path.isEmpty, ensureStarted() else {
            return nil
        }

        var image: UnsafeMutableRawPointer?
        let createStatus = withWideString(path) { widePath in
            winGdipCreateBitmapFromFile(widePath, &image)
        }
        guard createStatus == gdiplusOkStatus, let image else {
            return nil
        }
        defer {
            _ = winGdipDisposeImage(image)
        }

        var width: UINT = 0
        var height: UINT = 0
        _ = winGdipGetImageWidth(image, &width)
        _ = winGdipGetImageHeight(image, &height)

        var bitmap: HBITMAP?
        let convertStatus = winGdipCreateHBITMAPFromBitmap(image, &bitmap, gdiplusWhiteBackground)
        guard convertStatus == gdiplusOkStatus, let bitmap else {
            return nil
        }

        return DecodedBitmap(bitmap: bitmap, width: Int32(width), height: Int32(height))
    }

    // Cache-owned decoded bitmaps, keyed by source path. Bounded by clearing
    // wholesale when it grows past the cap — repaint traffic re-primes the
    // handful of images actually on screen.
    nonisolated(unsafe) private static var bitmapCache: [String: DecodedBitmap] = [:]
    private static let bitmapCacheLimit = 64

    /// Returns a cached decoded bitmap for a path, decoding on first use.
    ///
    /// The returned `HBITMAP` is owned by the cache — callers must NOT release
    /// it. Repaint-driven callers (custom drawing) use this; peers that take
    /// ownership of their bitmap (`STM_SETIMAGE` image views) keep using
    /// `decodeBitmap(fromFile:)`.
    static func cachedBitmap(fromFile path: String) -> DecodedBitmap? {
        if let cached = bitmapCache[path] {
            return cached
        }

        guard let decoded = decodeBitmap(fromFile: path) else {
            return nil
        }
        if bitmapCache.count >= bitmapCacheLimit {
            for entry in bitmapCache.values {
                _ = winDeleteObject(entry.bitmap)
            }
            bitmapCache.removeAll()
        }
        bitmapCache[path] = decoded
        return decoded
    }

    /// The 25-element (5x5 row-major) GDI+ color matrix that maps every pixel
    /// to the tint color while scaling the source alpha, i.e. template tinting.
    static func tintColorMatrix(red: Float, green: Float, blue: Float, alpha: Float) -> [Float] {
        [
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, alpha, 0,
            red, green, blue, 0, 1,
        ]
    }

    /// Decodes an image file and bakes a template-tinted GDI bitmap: the tint
    /// color everywhere, shaped by the source alpha over a white background.
    ///
    /// The caller owns the returned `HBITMAP`.
    static func decodeTintedBitmap(fromFile path: String, red: Float, green: Float, blue: Float, alpha: Float) -> DecodedBitmap? {
        guard !path.isEmpty, ensureStarted() else {
            return nil
        }

        var source: UnsafeMutableRawPointer?
        let createStatus = withWideString(path) { widePath in
            winGdipCreateBitmapFromFile(widePath, &source)
        }
        guard createStatus == gdiplusOkStatus, let source else {
            return nil
        }
        defer {
            _ = winGdipDisposeImage(source)
        }

        var width: UINT = 0
        var height: UINT = 0
        _ = winGdipGetImageWidth(source, &width)
        _ = winGdipGetImageHeight(source, &height)
        guard width > 0, height > 0 else {
            return nil
        }

        // Render the source through the tint matrix into a fresh ARGB bitmap.
        var tinted: UnsafeMutableRawPointer?
        guard winGdipCreateBitmapFromScan0(Int32(width), Int32(height), 0, gdiplusPixelFormat32bppARGB, nil, &tinted) == gdiplusOkStatus, let tinted else {
            return nil
        }
        defer {
            _ = winGdipDisposeImage(tinted)
        }

        var graphics: UnsafeMutableRawPointer?
        guard winGdipGetImageGraphicsContext(tinted, &graphics) == gdiplusOkStatus, let graphics else {
            return nil
        }
        defer {
            _ = winGdipDeleteGraphics(graphics)
        }

        var attributes: UnsafeMutableRawPointer?
        guard winGdipCreateImageAttributes(&attributes) == gdiplusOkStatus, let attributes else {
            return nil
        }
        defer {
            _ = winGdipDisposeImageAttributes(attributes)
        }
        let matrix = tintColorMatrix(red: red, green: green, blue: blue, alpha: alpha)
        let matrixStatus = matrix.withUnsafeBufferPointer { buffer in
            winGdipSetImageAttributesColorMatrix(attributes, 0, 1, buffer.baseAddress, nil, 0)
        }
        guard matrixStatus == gdiplusOkStatus else {
            return nil
        }

        let drawStatus = winGdipDrawImageRectRectI(
            graphics, source,
            0, 0, Int32(width), Int32(height),
            0, 0, Int32(width), Int32(height),
            gdiplusUnitPixel, attributes, nil, nil
        )
        guard drawStatus == gdiplusOkStatus else {
            return nil
        }

        var bitmap: HBITMAP?
        guard winGdipCreateHBITMAPFromBitmap(tinted, &bitmap, gdiplusWhiteBackground) == gdiplusOkStatus, let bitmap else {
            return nil
        }
        return DecodedBitmap(bitmap: bitmap, width: Int32(width), height: Int32(height))
    }

    /// Starts GDI+ once per process, remembering a failed startup.
    ///
    /// Also used by the drawing context before GDI+ rendering calls.
    static func ensureStarted() -> Bool {
        if startupAttempted {
            return isStarted
        }

        startupAttempted = true
        var input = GdiplusStartupInput()
        let status = withUnsafePointer(to: &input) { inputPointer in
            winGdiplusStartup(&startupToken, inputPointer, nil)
        }
        isStarted = status == gdiplusOkStatus
        return isStarted
    }
}
#endif

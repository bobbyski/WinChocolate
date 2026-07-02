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

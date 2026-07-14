/// A CoreGraphics-shaped bitmap image (plan 13.6).
///
/// `CGImage` owns decoded pixels — width × height rows of RGBA8 — giving the
/// framework its first honest *in-memory* bitmap representation (`NSImage`'s
/// data-backed boundary; drawing has so far been file-path-based). The first
/// codec is BMP (uncompressed 24/32-bit, the Windows-native interchange
/// format); PNG/JPEG decode is a follow-up discovery item (13.7).
public final class CGImage: @unchecked Sendable {
    /// The pixel width.
    public let width: Int

    /// The pixel height.
    public let height: Int

    /// Bits per component (8 in this representation).
    public let bitsPerComponent: Int = 8

    /// Bits per pixel (RGBA8 = 32).
    public let bitsPerPixel: Int = 32

    /// Bytes per row (width × 4; rows are not padded in memory).
    public var bytesPerRow: Int { width * 4 }

    /// The decoded pixels, row-major, 4 bytes per pixel (R, G, B, A),
    /// top row first.
    public let pixels: [UInt8]

    /// Creates an image from raw RGBA8 pixels (top row first). Fails when the
    /// buffer does not match width × height × 4.
    public init?(width: Int, height: Int, rgbaPixels: [UInt8]) {
        guard width > 0, height > 0, rgbaPixels.count == width * height * 4 else {
            return nil
        }
        self.width = width
        self.height = height
        self.pixels = rgbaPixels
    }

    /// Reads the pixel at a coordinate (top-left origin) as RGBA components,
    /// or `nil` outside the image.
    public func pixel(atX x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard x >= 0, x < width, y >= 0, y < height else {
            return nil
        }
        let offset = (y * width + x) * 4
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
    }

    // MARK: - BMP codec

    /// Decodes an uncompressed 24- or 32-bit BMP (BITMAPINFOHEADER or later;
    /// bottom-up or top-down rows). Returns `nil` for anything else.
    public static func decodeBMP(_ bytes: [UInt8]) -> CGImage? {
        // File header (14 bytes): "BM", size, reserved, pixel-data offset.
        guard bytes.count > 54, bytes[0] == 0x42, bytes[1] == 0x4D else {
            return nil
        }
        func u32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        }
        func i32(_ offset: Int) -> Int32 { Int32(bitPattern: u32(offset)) }
        func u16(_ offset: Int) -> UInt16 {
            UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        }

        let pixelOffset = Int(u32(10))
        let headerSize = Int(u32(14))
        guard headerSize >= 40 else {
            return nil // BITMAPCOREHEADER not supported.
        }
        let width = Int(i32(18))
        let rawHeight = Int(i32(22))
        let topDown = rawHeight < 0
        let height = abs(rawHeight)
        let planes = u16(26)
        let bitCount = Int(u16(28))
        let compression = u32(30)
        guard width > 0, height > 0, planes == 1,
              bitCount == 24 || bitCount == 32,
              compression == 0 /* BI_RGB */ else {
            return nil
        }

        let bytesPerPixel = bitCount / 8
        // BMP rows pad to 4-byte boundaries.
        let rowStride = (width * bytesPerPixel + 3) & ~3
        guard pixelOffset + rowStride * height <= bytes.count else {
            return nil
        }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            // BMP stores bottom-up unless the height was negative.
            let sourceRow = topDown ? row : (height - 1 - row)
            let rowStart = pixelOffset + sourceRow * rowStride
            for column in 0..<width {
                let source = rowStart + column * bytesPerPixel
                let destination = (row * width + column) * 4
                // BMP pixel order is BGR(A).
                rgba[destination] = bytes[source + 2]
                rgba[destination + 1] = bytes[source + 1]
                rgba[destination + 2] = bytes[source]
                rgba[destination + 3] = bytesPerPixel == 4 ? bytes[source + 3] : 255
            }
        }
        return CGImage(width: width, height: height, rgbaPixels: rgba)
    }

    /// Encodes the image as an uncompressed 32-bit bottom-up BMP.
    public func encodeBMP() -> [UInt8] {
        let rowBytes = width * 4 // 32-bit rows are already 4-byte aligned.
        let pixelDataSize = rowBytes * height
        let fileSize = 54 + pixelDataSize
        var out = [UInt8]()
        out.reserveCapacity(fileSize)

        func append32(_ value: UInt32) {
            out.append(UInt8(value & 0xFF))
            out.append(UInt8((value >> 8) & 0xFF))
            out.append(UInt8((value >> 16) & 0xFF))
            out.append(UInt8((value >> 24) & 0xFF))
        }
        func append16(_ value: UInt16) {
            out.append(UInt8(value & 0xFF))
            out.append(UInt8((value >> 8) & 0xFF))
        }

        // BITMAPFILEHEADER.
        out.append(0x42) // B
        out.append(0x4D) // M
        append32(UInt32(fileSize))
        append32(0)
        append32(54)
        // BITMAPINFOHEADER.
        append32(40)
        append32(UInt32(bitPattern: Int32(width)))
        append32(UInt32(bitPattern: Int32(height))) // positive → bottom-up
        append16(1)
        append16(32)
        append32(0) // BI_RGB
        append32(UInt32(pixelDataSize))
        append32(2835) // ~72 DPI
        append32(2835)
        append32(0)
        append32(0)
        // Pixel rows, bottom-up, BGRA.
        for row in stride(from: height - 1, through: 0, by: -1) {
            for column in 0..<width {
                let source = (row * width + column) * 4
                out.append(pixels[source + 2])
                out.append(pixels[source + 1])
                out.append(pixels[source])
                out.append(pixels[source + 3])
            }
        }
        return out
    }
}

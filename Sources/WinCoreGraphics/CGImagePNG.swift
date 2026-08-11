/// PNG decoding for `CGImage` (plan 13.6), pure-Swift over `Inflate`.
///
/// Supports the common non-interlaced, 8-bit-per-channel color types —
/// grayscale (0), truecolor RGB (2), grayscale+alpha (4), and truecolor+alpha
/// (6). Palette (3), 16-bit depth, and Adam7 interlacing are documented gaps
/// (they surface as `nil`); the framework loads modern RGB/RGBA PNGs, which
/// this covers. CRCs are not validated (they guard against corruption, not
/// misdecoding).
extension CGImage {
    /// Sniffs the format of image bytes and decodes BMP or PNG, or `nil` when
    /// neither matches / is supported.
    public static func decode(_ bytes: [UInt8]) -> CGImage? {
        if bytes.count >= 8, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return decodePNG(bytes)
        }
        if bytes.count >= 2, bytes[0] == 0x42, bytes[1] == 0x4D {
            return decodeBMP(bytes)
        }
        return nil
    }

    /// Decodes a non-interlaced 8-bit PNG (grayscale / RGB / gray+alpha / RGBA).
    public static func decodePNG(_ bytes: [UInt8]) -> CGImage? {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count > 8, Array(bytes[0..<8]) == signature else {
            return nil
        }
        guard let png = parsePNGChunks(bytes),
              png.width > 0, png.height > 0,
              png.bitDepth == 8, png.interlace == 0,
              let channels = pngChannelCount(for: png.colorType),
              let raw = try? Inflate.inflateZlib(png.imageData),
              let recon = unfilterPNG(raw, width: png.width, height: png.height, channels: channels) else {
            return nil
        }
        let rgba = expandPNGToRGBA(
            recon,
            pixelCount: png.width * png.height,
            channels: channels,
            colorType: png.colorType
        )
        return CGImage(width: png.width, height: png.height, rgbaPixels: rgba)
    }

    private struct PNGChunks {
        var width = 0
        var height = 0
        var bitDepth = 0
        var colorType = 0
        var interlace = 0
        var imageData: [UInt8] = []
    }

    private static func parsePNGChunks(_ bytes: [UInt8]) -> PNGChunks? {
        var offset = 8
        var result = PNGChunks()
        var sawHeader = false
        while offset + 8 <= bytes.count {
            let length = pngBigEndianInt(bytes, at: offset)
            let type = String(decoding: bytes[offset + 4..<offset + 8], as: UTF8.self)
            let dataStart = offset + 8
            guard dataStart + length + 4 <= bytes.count else { return nil }
            switch type {
            case "IHDR":
                guard length >= 13 else { return nil }
                result.width = pngBigEndianInt(bytes, at: dataStart)
                result.height = pngBigEndianInt(bytes, at: dataStart + 4)
                result.bitDepth = Int(bytes[dataStart + 8])
                result.colorType = Int(bytes[dataStart + 9])
                result.interlace = Int(bytes[dataStart + 12])
                sawHeader = true
            case "IDAT":
                result.imageData.append(contentsOf: bytes[dataStart..<dataStart + length])
            case "IEND":
                return sawHeader ? result : nil
            default:
                break // ancillary chunks (pHYs, tEXt, …) are ignored
            }
            offset = dataStart + length + 4 // skip data + CRC
        }
        return sawHeader ? result : nil
    }

    private static func pngBigEndianInt(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16
            | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
    }

    private static func pngChannelCount(for colorType: Int) -> Int? {
        switch colorType {
        case 0: return 1
        case 2: return 3
        case 4: return 2
        case 6: return 4
        default: return nil
        }
    }

    private static func unfilterPNG(_ raw: [UInt8], width: Int, height: Int, channels: Int) -> [UInt8]? {
        let stride = width * channels
        guard raw.count >= (stride + 1) * height else { return nil }
        var result = [UInt8](repeating: 0, count: stride * height)
        for row in 0..<height {
            let filter = raw[row * (stride + 1)]
            let sourceStart = row * (stride + 1) + 1
            let destinationStart = row * stride
            for index in 0..<stride {
                let filtered = Int(raw[sourceStart + index])
                let left = index >= channels ? Int(result[destinationStart + index - channels]) : 0
                let above = row > 0 ? Int(result[destinationStart - stride + index]) : 0
                let upperLeft = row > 0 && index >= channels
                    ? Int(result[destinationStart - stride + index - channels])
                    : 0
                guard let value = pngFilterValue(
                    filter,
                    filtered: filtered,
                    left: left,
                    above: above,
                    upperLeft: upperLeft
                ) else { return nil }
                result[destinationStart + index] = UInt8(value & 0xFF)
            }
        }
        return result
    }

    private static func pngFilterValue(
        _ filter: UInt8, filtered: Int, left: Int, above: Int, upperLeft: Int
    ) -> Int? {
        switch filter {
        case 0: return filtered
        case 1: return filtered + left
        case 2: return filtered + above
        case 3: return filtered + (left + above) / 2
        case 4: return filtered + paeth(left, above, upperLeft)
        default: return nil
        }
    }

    private static func expandPNGToRGBA(
        _ bytes: [UInt8], pixelCount: Int, channels: Int, colorType: Int
    ) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: pixelCount * 4)
        for pixel in 0..<pixelCount {
            let source = pixel * channels
            let dest = pixel * 4
            switch colorType {
            case 0:
                let gray = bytes[source]
                rgba[dest] = gray; rgba[dest + 1] = gray; rgba[dest + 2] = gray; rgba[dest + 3] = 255
            case 2:
                rgba[dest] = bytes[source]; rgba[dest + 1] = bytes[source + 1]
                rgba[dest + 2] = bytes[source + 2]; rgba[dest + 3] = 255
            case 4:
                let gray = bytes[source]
                rgba[dest] = gray; rgba[dest + 1] = gray; rgba[dest + 2] = gray
                rgba[dest + 3] = bytes[source + 1]
            default: // 6
                rgba[dest] = bytes[source]; rgba[dest + 1] = bytes[source + 1]
                rgba[dest + 2] = bytes[source + 2]; rgba[dest + 3] = bytes[source + 3]
            }
        }
        return rgba
    }

    /// The PNG Paeth predictor (RFC 2083 §6.6).
    private static func paeth(_ a: Int, _ b: Int, _ c: Int) -> Int {
        let p = a + b - c
        let pa = abs(p - a), pb = abs(p - b), pc = abs(p - c)
        if pa <= pb && pa <= pc { return a }
        if pb <= pc { return b }
        return c
    }
}

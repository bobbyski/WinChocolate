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

        func be32(_ offset: Int) -> Int {
            Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16
                | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
        }

        var offset = 8
        var width = 0, height = 0, bitDepth = 0, colorType = 0, interlace = 0
        var sawHeader = false
        var idat = [UInt8]()

        while offset + 8 <= bytes.count {
            let length = be32(offset)
            let type = String(decoding: bytes[offset + 4..<offset + 8], as: UTF8.self)
            let dataStart = offset + 8
            guard dataStart + length + 4 <= bytes.count else {
                break
            }
            switch type {
            case "IHDR":
                guard length >= 13 else { return nil }
                width = be32(dataStart)
                height = be32(dataStart + 4)
                bitDepth = Int(bytes[dataStart + 8])
                colorType = Int(bytes[dataStart + 9])
                interlace = Int(bytes[dataStart + 12])
                sawHeader = true
            case "IDAT":
                idat.append(contentsOf: bytes[dataStart..<dataStart + length])
            case "IEND":
                offset = bytes.count
            default:
                break // ancillary chunks (pHYs, tEXt, …) are ignored
            }
            offset = dataStart + length + 4 // skip data + CRC
        }

        guard sawHeader, width > 0, height > 0, bitDepth == 8, interlace == 0 else {
            return nil
        }
        let channels: Int
        switch colorType {
        case 0: channels = 1 // grayscale
        case 2: channels = 3 // RGB
        case 4: channels = 2 // grayscale + alpha
        case 6: channels = 4 // RGBA
        default: return nil  // palette / unsupported
        }

        guard let raw = try? Inflate.inflateZlib(idat) else {
            return nil
        }
        let stride = width * channels
        guard raw.count >= (stride + 1) * height else {
            return nil
        }

        // Unfilter into a contiguous channel buffer (RFC 2083 §6).
        var recon = [UInt8](repeating: 0, count: stride * height)
        let bpp = channels
        for row in 0..<height {
            let filterType = raw[row * (stride + 1)]
            let sourceStart = row * (stride + 1) + 1
            let destStart = row * stride
            for index in 0..<stride {
                let filtered = Int(raw[sourceStart + index])
                let a = index >= bpp ? Int(recon[destStart + index - bpp]) : 0
                let b = row > 0 ? Int(recon[destStart - stride + index]) : 0
                let c = (row > 0 && index >= bpp) ? Int(recon[destStart - stride + index - bpp]) : 0
                let value: Int
                switch filterType {
                case 0: value = filtered
                case 1: value = filtered + a
                case 2: value = filtered + b
                case 3: value = filtered + (a + b) / 2
                case 4: value = filtered + paeth(a, b, c)
                default: return nil
                }
                recon[destStart + index] = UInt8(value & 0xFF)
            }
        }

        // Expand to RGBA8.
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for pixel in 0..<(width * height) {
            let source = pixel * channels
            let dest = pixel * 4
            switch colorType {
            case 0:
                let gray = recon[source]
                rgba[dest] = gray; rgba[dest + 1] = gray; rgba[dest + 2] = gray; rgba[dest + 3] = 255
            case 2:
                rgba[dest] = recon[source]; rgba[dest + 1] = recon[source + 1]
                rgba[dest + 2] = recon[source + 2]; rgba[dest + 3] = 255
            case 4:
                let gray = recon[source]
                rgba[dest] = gray; rgba[dest + 1] = gray; rgba[dest + 2] = gray
                rgba[dest + 3] = recon[source + 1]
            default: // 6
                rgba[dest] = recon[source]; rgba[dest + 1] = recon[source + 1]
                rgba[dest + 2] = recon[source + 2]; rgba[dest + 3] = recon[source + 3]
            }
        }
        return CGImage(width: width, height: height, rgbaPixels: rgba)
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

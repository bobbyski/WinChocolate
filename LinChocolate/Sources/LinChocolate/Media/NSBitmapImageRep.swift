import Foundation

/// A byte buffer handed to `CGImage`'s designated initializer — Apple's
/// `CGDataProvider`, in the reduced shape the demo's raw-RGBA path uses.
public final class CGDataProvider {

    let bytes: [UInt8]

    /// Creates a provider over `data`'s bytes.
    public init?(data: Data) {
        self.bytes = [UInt8](data)
    }
}

/// Apple's bitmap-format descriptor (the alpha-position slice).
public struct CGBitmapInfo: OptionSet, Sendable {
    /// The raw bit-flag value.
    public let rawValue: UInt32
    /// Creates a bitmap-info value with the given raw flags.
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

/// Where alpha lives (and whether it is premultiplied) in a bitmap's pixels.
public enum CGImageAlphaInfo: UInt32, Sendable {
    /// No alpha channel.
    case none = 0
    /// Alpha follows the color components and is premultiplied.
    case premultipliedLast = 1
    /// Alpha precedes the color components and is premultiplied.
    case premultipliedFirst = 2
    /// Alpha follows the color components; not premultiplied.
    case last = 3
    /// Alpha precedes the color components; not premultiplied.
    case first = 4
    /// No alpha; a trailing byte is present and ignored.
    case noneSkipLast = 5
    /// No alpha; a leading byte is present and ignored.
    case noneSkipFirst = 6
}

/// Color-matching intent when rendering across color spaces.
public enum CGColorRenderingIntent: Int32, Sendable {
    /// The default rendering intent for the context.
    case defaultIntent = 0
    /// Absolute colorimetric matching.
    case absoluteColorimetric = 1
    /// Relative colorimetric matching.
    case relativeColorimetric = 2
    /// Perceptual matching (preserves visual relationships).
    case perceptual = 3
    /// Saturation matching (preserves vividness).
    case saturation = 4
}

public extension CGImage {
    /// Apple's designated initializer, for the 32-bit RGBA layout the demo
    /// builds (8 bits/component, alpha last, `bytesPerRow == width * 4`).
    convenience init?(width: Int, height: Int,
                      bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int,
                      space: CGColorSpace, bitmapInfo: CGBitmapInfo,
                      provider: CGDataProvider, decode: [CGFloat]?,
                      shouldInterpolate: Bool, intent: CGColorRenderingIntent) {
        guard bitsPerComponent == 8, bitsPerPixel == 32, bytesPerRow == width * 4,
              provider.bytes.count >= width * height * 4 else {
            return nil
        }

        self.init(width: width, height: height,
                  rgbaPixels: Array(provider.bytes.prefix(width * height * 4)))
    }
}

/// Apple's bitmap image rep — pixel access plus the BMP/PNG codecs. Backed by
/// LinChocolate's `CGImage` pixel store, whose BMP round-trip it exposes under
/// Apple's spellings (`representation(using: .bmp)`, `init(data:)`,
/// `colorAt(x:y:)`).
public final class NSBitmapImageRep {

    /// A key for the property dictionary passed to `representation(using:properties:)`.
    public struct PropertyKey: RawRepresentable, Hashable, Sendable {
        /// The raw property-key string.
        public let rawValue: String
        /// Creates a property key with the given raw string.
        public init(rawValue: String) { self.rawValue = rawValue }
    }

    /// The image file formats the rep can encode to.
    public enum FileType: Sendable {
        /// Windows Bitmap (uncompressed).
        case bmp
        /// Portable Network Graphics. Not yet implemented; encoding returns `nil`.
        case png
    }

    let backing: CGImage

    /// Wraps an existing image's pixels.
    public init(cgImage: CGImage) {
        self.backing = cgImage
    }

    /// Decodes encoded image bytes (the BMP the demo round-trips).
    public init?(data: Data) {
        guard let decoded = CGImage.decodeBMP([UInt8](data)) else {
            return nil
        }
        self.backing = decoded
    }

    /// The bitmap's width in pixels.
    public var pixelsWide: Int { backing.width }
    /// The bitmap's height in pixels.
    public var pixelsHigh: Int { backing.height }

    /// The rep as a `CGImage`.
    public var cgImage: CGImage? { backing }

    /// The pixel's color, or nil outside the bitmap (Apple's accessor —
    /// pixel reads live on the rep, not on `CGImage`).
    public func colorAt(x: Int, y: Int) -> NSColor? {
        guard let pixel = backing.pixel(atX: x, y: y) else {
            return nil
        }

        return NSColor(calibratedRed: CGFloat(pixel.r) / 255,
                       green: CGFloat(pixel.g) / 255,
                       blue: CGFloat(pixel.b) / 255,
                       alpha: CGFloat(pixel.a) / 255)
    }

    /// Encodes the bitmap (`.bmp` through the BMP codec; `.png` is a later
    /// codec item and returns nil).
    public func representation(using type: FileType, properties: [PropertyKey: Any]) -> Data? {
        switch type {
        case .bmp:
            return Data(backing.encodeBMP())
        case .png:
            return nil
        }
    }
}

/// The color-space identities `usingColorSpace(_:)` converts between. All of
/// LinChocolate's colors are device RGB already, so conversion is identity.
public final class NSColorSpace {
    /// The device RGB color space.
    nonisolated(unsafe) public static let deviceRGB = NSColorSpace()
    /// The sRGB color space.
    nonisolated(unsafe) public static let sRGB = NSColorSpace()
}

public extension NSColor {
    /// Apple's color-space conversion; LinChocolate colors are RGBA already.
    func usingColorSpace(_ space: NSColorSpace) -> NSColor? {
        self
    }
}

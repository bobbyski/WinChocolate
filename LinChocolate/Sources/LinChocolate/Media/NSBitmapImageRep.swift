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
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

public enum CGImageAlphaInfo: UInt32, Sendable {
    case none = 0
    case premultipliedLast = 1
    case premultipliedFirst = 2
    case last = 3
    case first = 4
    case noneSkipLast = 5
    case noneSkipFirst = 6
}

public enum CGColorRenderingIntent: Int32, Sendable {
    case defaultIntent = 0
    case absoluteColorimetric = 1
    case relativeColorimetric = 2
    case perceptual = 3
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

    public struct PropertyKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }

    public enum FileType: Sendable {
        case bmp
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

    public var pixelsWide: Int { backing.width }
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
    nonisolated(unsafe) public static let deviceRGB = NSColorSpace()
    nonisolated(unsafe) public static let sRGB = NSColorSpace()
}

public extension NSColor {
    /// Apple's color-space conversion; LinChocolate colors are RGBA already.
    func usingColorSpace(_ space: NSColorSpace) -> NSColor? {
        self
    }
}

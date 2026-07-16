import WinFoundation

/// A bitmap image representation — AppKit's `NSBitmapImageRep`, which *is*
/// Apple's BMP codec (`representation(using: .bmp)` / `init(data:)`) and pixel
/// accessor (`colorAt(x:y:)`).
///
/// WinChocolate's slice wraps the `CGImage` RGBA buffer and its BMP/PNG codec,
/// exposing Apple's exact surface so ported drawing code (and the shared demo)
/// round-trips a `CGImage` through real bitmap data. Apple derives this from
/// `NSImageRep`; this slice needs only the standalone codec surface the demo
/// exercises, so it is a plain `NSObject` for now.
open class NSBitmapImageRep: NSObject {
    /// Bitmap file formats — AppKit's `NSBitmapImageRep.FileType`. Raw values
    /// match AppKit's ordering.
    public enum FileType: UInt, Sendable {
        case tiff = 0
        case bmp = 1
        case gif = 2
        case jpeg = 3
        case png = 4
        case jpeg2000 = 5
    }

    /// Keys for `representation(using:properties:)` — AppKit's
    /// `NSBitmapImageRep.PropertyKey`. This slice reads none; the parameter
    /// exists for exact source parity.
    public struct PropertyKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    /// The backing image (RGBA8, top row first).
    public let cgImage: CGImage

    /// Wraps a `CGImage` — AppKit's `init(cgImage:)`.
    public init(cgImage: CGImage) {
        self.cgImage = cgImage
        super.init()
    }

    /// Decodes bitmap data — AppKit's `init(data:)`. Accepts the BMP the
    /// `.bmp` representation produces, and PNG.
    public init?(data: Data) {
        let bytes = Array(data)
        guard let image = CGImage.decodeBMP(bytes) ?? CGImage.decodePNG(bytes) else {
            return nil
        }
        self.cgImage = image
        super.init()
    }

    /// The pixel width — AppKit's `pixelsWide`.
    open var pixelsWide: Int { cgImage.width }

    /// The pixel height — AppKit's `pixelsHigh`.
    open var pixelsHigh: Int { cgImage.height }

    /// Encodes the bitmap to a file format — AppKit's
    /// `representation(using:properties:)`. This slice supports `.bmp`.
    open func representation(using storageType: FileType, properties: [PropertyKey: Any]) -> Data? {
        switch storageType {
        case .bmp:
            return Data(cgImage.encodeBMP())
        default:
            return nil
        }
    }

    /// The color at a pixel (top-left origin) — AppKit's `colorAt(x:y:)`.
    open func colorAt(x: Int, y: Int) -> NSColor? {
        guard let pixel = cgImage.pixel(atX: x, y: y) else {
            return nil
        }

        return NSColor(
            red: CGFloat(pixel.r) / 255,
            green: CGFloat(pixel.g) / 255,
            blue: CGFloat(pixel.b) / 255,
            alpha: CGFloat(pixel.a) / 255
        )
    }
}

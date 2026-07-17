import WinFoundation

// CoreGraphics bitmap-construction surface, matching Apple's module layering:
// `CGColorSpace`, `CGDataProvider`, `CGBitmapInfo`, `CGImageAlphaInfo`,
// `CGColorRenderingIntent`, and `CGImage`'s designated initializer are all
// CoreGraphics on Apple, so they live here alongside `CGImage` — not up in
// WinChocolate. (The drawing-backed surface — `CGContext`, `CGColor = NSColor`,
// `CGPath`, `CGGradient` — stays in WinChocolate, where those genuinely are the
// AppKit objects.)

/// A color-space stand-in — CoreGraphics' `CGColorSpace`. WinChocolate colors
/// are device-independent RGBA values, so spaces carry no conversion; the type
/// exists so AppKit-shaped source compiles unchanged.
public final class CGColorSpace: @unchecked Sendable {
    /// The sRGB space name.
    public static let sRGB = "kCGColorSpaceSRGB"

    /// Creates a named color space; all names resolve to the same identity
    /// space here.
    public init?(name: String) {}

    /// Creates the device RGB space.
    public init() {}
}

/// Creates the device RGB color space, matching the C-style CG spelling.
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace {
    CGColorSpace()
}

/// Core Foundation data stand-in for the `Data(...) as CFData` idiom, mirroring
/// `CFArray = [Any]`. CoreFoundation sits below CoreGraphics on Apple; here that
/// is WinFoundation.
public typealias CFData = Data

/// A data source for a `CGImage` — CoreGraphics' `CGDataProvider`.
public final class CGDataProvider: @unchecked Sendable {
    /// The provided bytes.
    public let data: Data

    /// Creates a provider over a data buffer — CoreGraphics' `init?(data:)`.
    public init?(data: CFData) {
        self.data = data
    }
}

/// Alpha layout for a bitmap — CoreGraphics' `CGImageAlphaInfo`. Raw values
/// match CoreGraphics.
public enum CGImageAlphaInfo: UInt32, Sendable {
    case none = 0
    case premultipliedLast = 1
    case premultipliedFirst = 2
    case last = 3
    case first = 4
    case noneSkipLast = 5
    case noneSkipFirst = 6
    case alphaOnly = 7
}

/// Bitmap layout flags — CoreGraphics' `CGBitmapInfo`. The low 5 bits carry a
/// `CGImageAlphaInfo` raw value.
public struct CGBitmapInfo: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let alphaInfoMask = CGBitmapInfo(rawValue: 0x1F)
    public static let byteOrderDefault = CGBitmapInfo(rawValue: 0)
}

/// Rendering intent — CoreGraphics' `CGColorRenderingIntent`.
public enum CGColorRenderingIntent: Int32, Sendable {
    case defaultIntent = 0
    case absoluteColorimetric = 1
    case relativeColorimetric = 2
    case perceptual = 3
    case saturation = 4
}

extension CGImage {
    /// CoreGraphics' designated `CGImage` initializer. This slice supports the
    /// 8-bit RGBA case: `bitsPerComponent 8`, `bitsPerPixel 32`, a provider
    /// carrying the pixels (honoring `bytesPerRow` row padding). The buffer is
    /// taken as RGBA (top row first), which is the `.last` /
    /// `.premultipliedLast` layout callers supply.
    public convenience init?(width: Int, height: Int,
                             bitsPerComponent: Int, bitsPerPixel: Int,
                             bytesPerRow: Int, space: CGColorSpace,
                             bitmapInfo: CGBitmapInfo, provider: CGDataProvider,
                             decode: [CGFloat]?, shouldInterpolate: Bool,
                             intent: CGColorRenderingIntent) {
        guard bitsPerComponent == 8, bitsPerPixel == 32, width > 0, height > 0 else {
            return nil
        }

        let bytes = [UInt8](provider.data)
        let rowBytes = width * 4
        var rgba: [UInt8]
        if bytesPerRow == rowBytes {
            guard bytes.count >= rowBytes * height else {
                return nil
            }
            rgba = Array(bytes.prefix(rowBytes * height))
        } else {
            rgba = []
            rgba.reserveCapacity(rowBytes * height)
            for row in 0..<height {
                let start = row * bytesPerRow
                guard start + rowBytes <= bytes.count else {
                    return nil
                }
                rgba.append(contentsOf: bytes[start..<(start + rowBytes)])
            }
        }

        self.init(width: width, height: height, rgbaPixels: rgba)
    }
}

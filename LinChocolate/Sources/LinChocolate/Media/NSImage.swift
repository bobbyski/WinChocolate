import Foundation

/// AppKit-shaped image reference. This slice is file-backed: it carries the
/// path and validates existence; decoding happens natively in the view
/// (GdkTexture via GtkPicture).
public final class NSImage {

    /// The file the image was loaded from.
    public let path: String

    /// Creates an image from a file on disk; nil if the file doesn't exist.
    public init?(contentsOfFile path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        self.path = path
    }
}

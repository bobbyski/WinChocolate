import Foundation

/// AppKit-shaped image reference. Backed either by a file on disk (decoded
/// natively via GdkTexture/GtkPicture) or by a *named* image — on Apple a named
/// asset, on Linux the matching icon from the GTK icon theme.
public final class NSImage {

    /// A symbolic image name (AppKit's `NSImage.Name`).
    public typealias Name = String

    /// The file the image was loaded from (nil for a named image).
    let path: String?

    /// The icon-theme name (nil for a file-backed image).
    let iconName: String?

    /// Creates an image from a file on disk; nil if the file doesn't exist.
    public init?(contentsOfFile path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        self.path = path
        self.iconName = nil
    }

    /// Creates a named image (AppKit's `NSImage(named:)`). On Linux the name is
    /// resolved against the GTK icon theme when the image is displayed.
    public init?(named name: NSImage.Name) {
        guard !name.isEmpty else { return nil }
        self.path = nil
        self.iconName = name
    }
}

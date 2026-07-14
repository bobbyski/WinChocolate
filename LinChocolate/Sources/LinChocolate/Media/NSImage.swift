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

    /// Creates an SF-Symbol image (AppKit's `NSImage(systemSymbolName:…)`),
    /// mapping the symbol name to the closest GTK theme icon on Linux.
    public convenience init?(systemSymbolName name: String, accessibilityDescription: String?) {
        self.init(named: NSImage.gtkIconName(forSymbol: name))
    }

    /// Creates an image from in-memory data (AppKit's `NSImage(data:)`). The
    /// backing store here is path-based (GdkTexture decodes from disk), so the
    /// bytes are staged to a temporary file GdkPixbuf can read (BMP/PNG/…).
    public convenience init?(data: Data) {
        guard !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("linchocolate-image-\(UUID().uuidString).img")
        guard (try? data.write(to: url)) != nil else { return nil }
        self.init(contentsOfFile: url.path)
    }

    /// Best-effort SF-Symbol → GTK icon-theme name mapping.
    static func gtkIconName(forSymbol symbol: String) -> String {
        switch symbol {
        case "folder", "folder.fill": return "folder-symbolic"
        case "doc", "doc.text", "square.and.pencil": return "document-open-symbolic"
        case "square.and.arrow.down": return "document-save-symbolic"
        case "square.and.arrow.up": return "document-send-symbolic"
        case "info.circle", "info": return "dialog-information-symbolic"
        case "gearshape", "gear": return "emblem-system-symbolic"
        case "trash": return "user-trash-symbolic"
        case "plus": return "list-add-symbolic"
        case "minus": return "list-remove-symbolic"
        case "magnifyingglass": return "system-search-symbolic"
        case "slider.horizontal.3": return "emblem-system-symbolic"
        case "paintbrush", "paintpalette": return "applications-graphics-symbolic"
        default: return symbol
        }
    }
}

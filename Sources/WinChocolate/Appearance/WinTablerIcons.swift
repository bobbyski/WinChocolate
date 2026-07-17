import WinFoundation

/// The framework's stock glyph artwork: a curated subset of
/// [Tabler Icons](https://tabler.io/icons) (MIT License, © Paweł Kuna),
/// embedded as SVG path data and stroked at render time — replacing the
/// legacy comctl32 stock image list wherever the framework needs an icon it
/// doesn't get from the app (toolbar name-based fallbacks, the customization
/// palette's standard identifiers).
///
/// Icons are authored 24×24, stroke width 2, round caps/joins; rendering
/// scales the stroke with the target size so they stay crisp at glyph sizes.
enum WinTablerIcons {
    /// Icon-space edge length the path data is authored against.
    static let designSize: CGFloat = 24

    /// Path data per icon (each entry is the icon's `<path d="…">` list).
    private static let icons: [String: [String]] = [
        "file": [
            "M14 3v4a1 1 0 0 0 1 1h4",
            "M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2",
        ],
        "file-plus": [
            "M14 3v4a1 1 0 0 0 1 1h4",
            "M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2",
            "M12 11l0 6",
            "M9 14l6 0",
        ],
        "folder-open": [
            "M5 19l2.757 -7.351a1 1 0 0 1 .936 -.649h12.307a1 1 0 0 1 .986 1.164l-.996 5.211a2 2 0 0 1 -1.964 1.625h-14.026a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2h4l3 3h7a2 2 0 0 1 2 2v2",
        ],
        "device-floppy": [
            "M6 4h10l4 4v10a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2",
            "M10 14a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
            "M14 4l0 4l-6 0l0 -4",
        ],
        "printer": [
            "M17 17h2a2 2 0 0 0 2 -2v-4a2 2 0 0 0 -2 -2h-14a2 2 0 0 0 -2 2v4a2 2 0 0 0 2 2h2",
            "M17 9v-4a2 2 0 0 0 -2 -2h-6a2 2 0 0 0 -2 2v4",
            "M7 15a2 2 0 0 1 2 -2h6a2 2 0 0 1 2 2v4a2 2 0 0 1 -2 2h-6a2 2 0 0 1 -2 -2l0 -4",
        ],
        "settings": [
            "M10.325 4.317c.426 -1.756 2.924 -1.756 3.35 0a1.724 1.724 0 0 0 2.573 1.066c1.543 -.94 3.31 .826 2.37 2.37a1.724 1.724 0 0 0 1.065 2.572c1.756 .426 1.756 2.924 0 3.35a1.724 1.724 0 0 0 -1.066 2.573c.94 1.543 -.826 3.31 -2.37 2.37a1.724 1.724 0 0 0 -2.572 1.065c-.426 1.756 -2.924 1.756 -3.35 0a1.724 1.724 0 0 0 -2.573 -1.066c-1.543 .94 -3.31 -.826 -2.37 -2.37a1.724 1.724 0 0 0 -1.065 -2.572c-1.756 -.426 -1.756 -2.924 0 -3.35a1.724 1.724 0 0 0 1.066 -2.573c-.94 -1.543 .826 -3.31 2.37 -2.37c1 .608 2.296 .07 2.572 -1.065",
            "M9 12a3 3 0 1 0 6 0a3 3 0 0 0 -6 0",
        ],
        "adjustments-horizontal": [
            "M12 6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
            "M4 6l8 0",
            "M16 6l4 0",
            "M6 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
            "M4 12l2 0",
            "M10 12l10 0",
            "M15 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
            "M4 18l11 0",
            "M19 18l1 0",
        ],
        "help-circle": [
            "M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0",
            "M12 16v.01",
            "M12 13a2 2 0 0 0 .914 -3.782a1.98 1.98 0 0 0 -2.414 .483",
        ],
        "trash": [
            "M4 7l16 0",
            "M10 11l0 6",
            "M14 11l0 6",
            "M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12",
            "M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3",
        ],
        "search": [
            "M3 10a7 7 0 1 0 14 0a7 7 0 1 0 -14 0",
            "M21 21l-6 -6",
        ],
        "palette": [
            "M12 21a9 9 0 0 1 0 -18c4.97 0 9 3.582 9 8c0 1.06 -.474 2.078 -1.318 2.828c-.844 .75 -1.989 1.172 -3.182 1.172h-2.5a2 2 0 0 0 -1 3.75a1.3 1.3 0 0 1 -1 2.25",
            "M7.5 10.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
            "M11.5 7.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
            "M15.5 10.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
        ],
        "typography": [
            "M4 20l3 0",
            "M14 20l7 0",
            "M6.9 15l6.9 0",
            "M10.2 6.3l5.8 13.7",
            "M5 20l6 -16l2 0l7 16",
        ],
        "ban": [
            "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0",
            "M5.7 5.7l12.6 12.6",
        ],
    ]

    /// Maps the framework's legacy glyph keys and common SF-symbol-ish names
    /// onto the Tabler set, so every name that previously hit the comctl32
    /// stock image list (or a hand-drawn glyph) resolves to real artwork.
    static func iconName(forGlyphKey key: String) -> String? {
        let lowered = key.lowercased()
        switch lowered {
        case "new", "document", "doc", "filenew", "square.and.pencil":
            return "file-plus"
        case "open", "folder", "folder.open", "fileopen":
            return "folder-open"
        case "save", "filesave", "square.and.arrow.down", "tray.and.arrow.down":
            return "device-floppy"
        case "print", "printer":
            return "printer"
        case "properties", "info", "info.circle", "gear", "gearshape", "settings":
            return "settings"
        case "customize", "slider.horizontal.3", "adjustments":
            return "adjustments-horizontal"
        case "help", "questionmark", "questionmark.circle":
            return "help-circle"
        case "trash", "delete", "remove":
            return "trash"
        case "search", "find", "magnifyingglass":
            return "search"
        case "colors", "showcolors", "paintpalette":
            return "palette"
        case "fonts", "showfonts", "textformat":
            return "typography"
        case "ban", "disable", "nosign":
            return "ban"
        default:
            return icons[lowered] != nil ? lowered : nil
        }
    }

    /// The icon's paths scaled into a target square, ready to stroke with
    /// width `2 × (side / designSize)`.
    static func paths(named name: String, scaledTo side: CGFloat, at origin: NSPoint) -> [NSBezierPath]? {
        guard let pathData = icons[name] else {
            return nil
        }

        let scale = side / designSize
        return pathData.map { d in
            let path = WinSVGPath.path(from: d)
            let scaled = NSBezierPath()
            for segment in path.nativeSegments {
                switch segment {
                case .move(let point):
                    scaled.move(to: NSPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale))
                case .line(let point):
                    scaled.line(to: NSPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale))
                case .curve(let end, let control1, let control2):
                    scaled.curve(
                        to: NSPoint(x: origin.x + end.x * scale, y: origin.y + end.y * scale),
                        controlPoint1: NSPoint(x: origin.x + control1.x * scale, y: origin.y + control1.y * scale),
                        controlPoint2: NSPoint(x: origin.x + control2.x * scale, y: origin.y + control2.y * scale)
                    )
                case .close:
                    scaled.close()
                }
            }
            return scaled
        }
    }
}

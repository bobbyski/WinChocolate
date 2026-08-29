// SF Symbols in a browser.
//
// A page has no symbol library, and the framework's image path for a symbol is
// just its name — `arrow.2.squarepath`, `NSToolbarToggleSidebarItem` — with no
// extension and no file behind it. Requesting it produced a 404 and a
// broken-image icon in every toolbar and every sidebar row.
//
// **A broken image is the worst of the three possible answers.** It is not the
// artwork, it does not say what the control does, and it looks like the page
// failed to load. So symbols are recognised by shape (no file extension) and
// answered here, from a small table of the ones that carry meaning in chrome,
// with a drawn monogram for the rest. Nothing is ever fetched.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// A 1×1 fully transparent SVG, for an image element with nothing to show.
    internal static let transparentPixel =
        "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='1' height='1'/%3E"

    /// Whether an image path names a symbol rather than a file.
    ///
    /// Symbol names have no extension; file names do. That is the whole test,
    /// and it is the right one because it is the same thing the caller knows:
    /// `NSImage(systemSymbolName:)` records a bare name, every file route
    /// records a path.
    internal static func isSymbolName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\") else { return false }
        let fileExtensions = ["bmp", "png", "ico", "jpg", "jpeg", "gif", "svg", "xib", "pdf", "tiff"]
        guard let dot = name.lastIndex(of: ".") else { return true }
        let ext = String(name[name.index(after: dot)...]).lowercased()
        // `arrow.2.squarepath` has dots and is still a symbol; `logo.png` is
        // not. What separates them is whether the tail is a known extension.
        return !fileExtensions.contains(ext)
    }

    /// SVG path data for the symbols that carry meaning in window chrome.
    ///
    /// Deliberately small. 129 distinct symbols appear across ActiveUI and its
    /// demos, and hand-drawing all of them would be a worse likeness than
    /// nothing plus a great deal of code. These are the ones where the glyph
    /// *is* the control — a chevron, a gear, a magnifier — and where a label
    /// alone would leave a toolbar unreadable.
    ///
    /// Drawn in a 16×16 box, stroked rather than filled, so one path serves
    /// every size and both light and dark: the stroke takes `currentColor`.
    private static let symbolPaths: [String: String] = [
        "chevron.left": "M10 3 L5 8 L10 13",
        "chevron.right": "M6 3 L11 8 L6 13",
        "chevron.up": "M3 10 L8 5 L13 10",
        "chevron.down": "M3 6 L8 11 L13 6",
        "plus": "M8 3 V13 M3 8 H13",
        "minus": "M3 8 H13",
        "xmark": "M4 4 L12 12 M12 4 L4 12",
        "checkmark": "M3 8 L7 12 L13 4",
        "magnifyingglass": "M7 2 A5 5 0 1 0 7 12 A5 5 0 1 0 7 2 M11 11 L14 14",
        "trash": "M3 4 H13 M6 4 V2 H10 V4 M4.5 4 L5 14 H11 L11.5 4",
        "gearshape": "M8 5.5 A2.5 2.5 0 1 0 8 10.5 A2.5 2.5 0 1 0 8 5.5 M8 1 V3 M8 13 V15 M1 8 H3 M13 8 H15 M3 3 L4.5 4.5 M11.5 11.5 L13 13 M13 3 L11.5 4.5 M4.5 11.5 L3 13",
        "folder": "M2 4 H6.5 L8 6 H14 V13 H2 Z",
        "doc": "M4 2 H10 L13 5 V14 H4 Z M10 2 V5 H13",
        "doc.text": "M4 2 H10 L13 5 V14 H4 Z M10 2 V5 H13 M6 8 H11 M6 11 H11",
        "pencil": "M3 13 L4 10 L11 3 L13 5 L6 12 Z",
        "square.and.pencil": "M12 3 L14 5 L8 11 L5 12 L6 9 Z M13 9 V14 H2 V3 H7",
        "star": "M8 2 L10 6.5 L15 7 L11.5 10.5 L12.5 15 L8 12.5 L3.5 15 L4.5 10.5 L1 7 L6 6.5 Z",
        "star.fill": "M8 2 L10 6.5 L15 7 L11.5 10.5 L12.5 15 L8 12.5 L3.5 15 L4.5 10.5 L1 7 L6 6.5 Z",
        "sidebar.leading": "M2 3 H14 V13 H2 Z M6 3 V13",
        "sidebar.left": "M2 3 H14 V13 H2 Z M6 3 V13",
        "NSToolbarToggleSidebarItem": "M2 3 H14 V13 H2 Z M6 3 V13",
        "list.bullet": "M3 4 H3.01 M6 4 H13 M3 8 H3.01 M6 8 H13 M3 12 H3.01 M6 12 H13",
        "square.grid.2x2": "M2 2 H7 V7 H2 Z M9 2 H14 V7 H9 Z M2 9 H7 V14 H2 Z M9 9 H14 V14 H9 Z",
        "tablecells": "M2 3 H14 V13 H2 Z M2 7 H14 M2 10 H14 M6 3 V13 M10 3 V13",
        "chart.bar": "M3 13 V8 H5.5 V13 Z M6.75 13 V4 H9.25 V13 Z M10.5 13 V6 H13 V13 Z",
        "arrow.clockwise": "M13 8 A5 5 0 1 1 11.5 4.5 M11.5 1.5 V4.5 H8.5",
        "arrow.2.squarepath": "M4 5 H11 A2 2 0 0 1 11 9 H5 A2 2 0 0 0 5 13 H12 M4 5 L6 3 M4 5 L6 7 M12 13 L10 11 M12 13 L10 15",
        "photo": "M2 3 H14 V13 H2 Z M2 11 L6 7 L9 10 L11 8 L14 11",
        "globe": "M8 1.5 A6.5 6.5 0 1 0 8 14.5 A6.5 6.5 0 1 0 8 1.5 M1.5 8 H14.5 M8 1.5 A9 6.5 0 0 0 8 14.5 M8 1.5 A9 6.5 0 0 1 8 14.5",
        "gear": "M8 5.5 A2.5 2.5 0 1 0 8 10.5 A2.5 2.5 0 1 0 8 5.5 M8 1 V3 M8 13 V15 M1 8 H3 M13 8 H15",
        "square.and.arrow.up": "M8 2 V10 M5 5 L8 2 L11 5 M3 9 V14 H13 V9",
        "info.circle": "M8 1.5 A6.5 6.5 0 1 0 8 14.5 A6.5 6.5 0 1 0 8 1.5 M8 7 V11.5 M8 4.5 V5",
        "questionmark.circle": "M8 1.5 A6.5 6.5 0 1 0 8 14.5 A6.5 6.5 0 1 0 8 1.5 M6 6.2 A2 2 0 1 1 8 9 V10 M8 12 V12.01",
        "exclamationmark.triangle": "M8 2 L15 14 H1 Z M8 6 V10 M8 12 V12.01",
    ]

    /// A `data:` URL for a symbol name, or nil when it should show nothing.
    ///
    /// - Parameter description: the image's accessibility description, used for
    ///   the monogram when the symbol is not one of the drawn ones. Empty means
    ///   there is nothing to say, so nothing is drawn — an icon-only control
    ///   with no description is a bug in the caller, not something to paper
    ///   over with a letter.
    internal static func symbolImageDataURL(for name: String, description: String) -> String? {
        let body: String
        if let path = symbolPaths[name] {
            body = """
                <path d="\(path)" fill="none" stroke="currentColor" \
                stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>
                """
        } else {
            // The monogram. Not artwork and not pretending to be: a legible
            // stand-in that says "there is a control here and it is this one",
            // which is more than a broken image says and more than blank does.
            guard let initial = description.first(where: { !$0.isWhitespace }) else { return nil }
            let letter = escapedForXML(String(initial).uppercased())
            body = """
                <rect x="1.5" y="1.5" width="13" height="13" rx="3.5" fill="none" \
                stroke="currentColor" stroke-width="1.2" opacity="0.45"/>\
                <text x="8" y="11.5" text-anchor="middle" font-size="9" \
                font-family="-apple-system,system-ui,sans-serif" \
                fill="currentColor">\(letter)</text>
                """
        }

        let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16">\
            \(body)</svg>
            """
        // `data:image/svg+xml;utf8,` with the few characters that would end the
        // attribute or the URL percent-escaped. Base64 would avoid the question
        // entirely and would also make every one of these unreadable in the
        // inspector, which is where anyone debugging a wrong icon will look.
        return "data:image/svg+xml;utf8,\(percentEscapedForDataURL(svg))"
    }

    /// Escapes the three characters that cannot appear raw in XML text.
    private static func escapedForXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Escapes what a `data:` URL in an `src` attribute cannot carry raw.
    private static func percentEscapedForDataURL(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count + 32)
        for character in text {
            switch character {
            case "#": out += "%23"      // ends the URL, starts a fragment
            case "%": out += "%25"      // would be read as an escape
            case "\"": out += "%22"     // ends the attribute
            case "<": out += "%3C"
            case ">": out += "%3E"
            default: out.append(character)
            }
        }
        return out
    }
}

#endif

/// The methods a search-field delegate implements, matching AppKit's shape:
/// search fields report text changes through the text-field delegate surface.
public protocol NSSearchFieldDelegate: NSTextFieldDelegate {}

/// A single-line search field control.
///
/// This first slice preserves the AppKit name and text-change/search action
/// shape while using the same native edit peer as `NSTextField`.
open class NSSearchField: NSTextField {
    /// Creates a search field with a zero frame, matching AppKit's shape.
    public convenience init() {
        self.init(frame: .zero)
    }

    /// Recent search strings tracked by the application.
    open var recentSearches: [String] = []

    /// Whether each edit should send the search action.
    open var sendsSearchStringImmediately: Bool = true

    /// Whether Return-style searches should send the whole search string.
    open var sendsWholeSearchString: Bool = true

    /// Creates a search field with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = true
        isSelectable = true
        isBordered = true
        drawsBackground = true
    }

    /// Performs the search action.
    open func performSearch(_ sender: Any?) {
        rememberCurrentSearch()
        sendAction()
    }

    /// Clears the search text and sends the action.
    open func cancelSearch(_ sender: Any?) {
        stringValue = ""
        sendAction()
    }

    /// Ensures native edit changes flow through search-field semantics.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
            if self.sendsSearchStringImmediately {
                self.rememberCurrentSearch()
                self.sendAction()
            }
        }
        return handle
    }

    private func rememberCurrentSearch() {
        guard !stringValue.isEmpty else {
            return
        }

        recentSearches.removeAll { $0 == stringValue }
        recentSearches.insert(stringValue, at: 0)
    }

    // MARK: Search chrome (10.8)
    //
    // Win32 has no native search field, so the search chrome is composed over
    // the editable peer: a magnifier glyph on the leading edge (which drops the
    // recent-searches menu) and, once there's text, a clear (✕) button on the
    // trailing edge. The geometry insets the text area so glyphs and text don't
    // overlap, matching the AppKit search field.

    /// The side length of the leading/trailing glyph boxes.
    private var winGlyphSide: CGFloat { min(16, bounds.height - 4) }

    /// The magnifier glyph box, on the leading edge.
    open var winSearchIconRect: NSRect {
        let side = winGlyphSide
        return NSRect(x: 4, y: (bounds.height - side) / 2, width: side, height: side)
    }

    /// The clear-button box, on the trailing edge (empty when there's no text).
    open var winCancelButtonRect: NSRect {
        guard !stringValue.isEmpty else { return .zero }
        let side = winGlyphSide
        return NSRect(x: bounds.width - side - 4, y: (bounds.height - side) / 2, width: side, height: side)
    }

    /// The text area between the two glyphs (where the editable peer sits).
    open var winSearchTextRect: NSRect {
        let leading = winSearchIconRect.maxX + 3
        let trailing = stringValue.isEmpty ? bounds.width - 4 : winCancelButtonRect.minX - 3
        return NSRect(x: leading, y: 0, width: max(0, trailing - leading), height: bounds.height)
    }

    /// Draws the magnifier glyph and, when there is text, the clear button.
    open func winDrawSearchChrome(in context: NativeDrawingContext) {
        let glyphColor = NSColor(white: 0.5, alpha: 1)

        // Magnifier: a ring (octagon approximation) plus a diagonal handle.
        // Fixed unit octagon offsets avoid depending on a trig runtime.
        let lens = winSearchIconRect.insetBy(dx: 2, dy: 2)
        let cx = lens.midX, cy = lens.midY
        let r = min(lens.width, lens.height) / 2 * 0.7
        let d = r * 0.7071  // cos/sin of 45°
        let unit: [(CGFloat, CGFloat)] = [
            (1, 0), (d / r, d / r), (0, 1), (-d / r, d / r),
            (-1, 0), (-d / r, -d / r), (0, -1), (d / r, -d / r), (1, 0)
        ]
        var ring: [NativePathSegment] = []
        for (i, offset) in unit.enumerated() {
            let p = NSPoint(x: cx + r * offset.0, y: cy + r * offset.1)
            ring.append(i == 0 ? .move(p) : .line(p))
        }
        context.strokePath(ring, color: glyphColor, lineWidth: 1.2)
        // Handle from the lower-right of the ring outward.
        let handleStart = NSPoint(x: cx + r * 0.7, y: cy - r * 0.7)
        let handleEnd = NSPoint(x: cx + r * 1.5, y: cy - r * 1.5)
        context.strokePath([.move(handleStart), .line(handleEnd)], color: glyphColor, lineWidth: 1.4)

        // Clear button: an ✕ inside the trailing box.
        let cancel = winCancelButtonRect
        if cancel.width > 0 {
            let box = cancel.insetBy(dx: 3, dy: 3)
            context.strokePath([.move(NSPoint(x: box.minX, y: box.minY)),
                                .line(NSPoint(x: box.maxX, y: box.maxY))],
                               color: glyphColor, lineWidth: 1.4)
            context.strokePath([.move(NSPoint(x: box.minX, y: box.maxY)),
                                .line(NSPoint(x: box.maxX, y: box.minY))],
                               color: glyphColor, lineWidth: 1.4)
        }
    }

    /// The recent-searches menu dropped from the magnifier, matching AppKit's
    /// layout: a disabled "Recent Searches" header, the recent items, and a
    /// "Clear" item — empty (just "No Recent Searches") when there are none.
    open func winRecentSearchesMenu() -> NSMenu {
        let menu = NSMenu()
        if recentSearches.isEmpty {
            let empty = NSMenuItem(title: "No Recent Searches", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return menu
        }
        let header = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for term in recentSearches {
            let item = NSMenuItem(title: term, action: "winSelectRecentSearch:", keyEquivalent: "")
            item.target = self
            item.onAction = { [weak self] _ in
                self?.stringValue = term
                self?.performSearch(self)
            }
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let clear = NSMenuItem(title: "Clear", action: "winClearRecentSearches:", keyEquivalent: "")
        clear.target = self
        clear.onAction = { [weak self] _ in self?.recentSearches.removeAll() }
        menu.addItem(clear)
        return menu
    }

    /// Routes a click in the search field: the magnifier drops the recent menu,
    /// the clear button empties the field. Returns whether the click was
    /// consumed by the chrome (so the caller doesn't also begin text editing).
    @discardableResult
    open func winHandleSearchChromeClick(at point: NSPoint) -> Bool {
        if winCancelButtonRect.width > 0, winCancelButtonRect.contains(point) {
            cancelSearch(self)
            return true
        }
        if winSearchIconRect.contains(point) {
            let menu = winRecentSearchesMenu()
            _ = menu.popUp(positioning: nil, at: NSPoint(x: winSearchIconRect.minX, y: winSearchIconRect.maxY), in: self)
            return true
        }
        return false
    }
}

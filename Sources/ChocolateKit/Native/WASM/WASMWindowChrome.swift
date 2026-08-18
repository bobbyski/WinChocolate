// Window chrome the browser does not supply: drag-to-move, a resize grip, and
// a dock to minimize into (Docs/WASMChocolatePlan.md rows W5.3 and W5.7).
//
// The same argument that justifies the synthesized desktop justifies all three.
// A page has no window server, so this backend is the window server: if it does
// not draw a grip, no window can be resized; if it does not keep a dock, a
// miniaturized window has nowhere to go and simply vanishes.
//
// Resizing was pulled ahead of tables and input plumbing for a specific reason.
// The catalog's Auto Layout page instructs the reader to *"resize the window →
// the green middle box reflows live"*, and until a grip exists that sentence is
// an instruction the browser build cannot follow — the constraint solver and
// every autoresizing mask in the demo are untested here rather than merely
// unfinished. One grip turns the whole page into something checkable at a
// glance.
//
// The frame stays law. A drag reports the new origin or size through
// `registerWindowMoveAction` / `registerWindowResizeAction` and lets the core
// drive the relayout, which then pushes frames back down through `setFrame`.
// The backend never resizes the DOM and tells the core afterwards.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// The height reserved for the dock along the bottom of the desktop.
    internal static var dockHeight: Double { 44 }

    // MARK: - Dragging

    /// Makes a window's title bar drag the window.
    internal func installWindowDrag(on bar: Element, handle: NativeHandle) {
        listeners[handle, default: []].append(bar.addEventListener(.pointerdown) { [weak self] event in
            guard let self, let record = self.records[handle] else { return }
            event.preventDefault()
            self.beginWindowGesture(
                handle: handle,
                startX: event.clientX,
                startY: event.clientY,
                origin: record.frame.origin,
                size: record.frame.size,
                kind: .move)
        })
    }

    /// Builds the corner grip that resizes a window.
    internal func makeResizeGrip(handle: NativeHandle) -> Element {
        let grip = Element.div()
            .setStyle("position", "absolute")
            .setStyle("right", "0").setStyle("bottom", "0")
            .setStyle("width", "16px").setStyle("height", "16px")
            .setStyle("cursor", "nwse-resize")
            // Two hairlines, the way every resize corner has looked since the
            // classic Mac — cheap, and unmistakably a grip.
            .setStyle("background",
                      "linear-gradient(135deg, transparent 0 46%, #9a9a9a 46% 54%, transparent 54% 70%, #9a9a9a 70% 78%, transparent 78%)")
        listeners[handle, default: []].append(grip.addEventListener(.pointerdown) { [weak self] event in
            guard let self, let record = self.records[handle] else { return }
            event.preventDefault()
            event.stopPropagation()
            self.beginWindowGesture(
                handle: handle,
                startX: event.clientX,
                startY: event.clientY,
                origin: record.frame.origin,
                size: record.frame.size,
                kind: .resize)
        })
        return grip
    }

    /// Starts tracking a move or resize until the pointer is released.
    ///
    /// The move and up listeners go on `document.body` rather than the grip:
    /// a pointer that outruns a 16-pixel corner mid-drag would otherwise stop
    /// sending events, and the window would stick.
    private func beginWindowGesture(handle: NativeHandle, startX: Double, startY: Double,
                                    origin: NSPoint, size: NSSize, kind: WindowGestureKind) {
        endWindowGesture()

        let body = DOM.document.body
        gestureListeners.append(body.addEventListener(.pointermove) { [weak self] event in
            guard let self else { return }
            let deltaX = event.clientX - startX
            let deltaY = event.clientY - startY
            switch kind {
            case .move:
                let moved = NSMakePoint(origin.x + CGFloat(deltaX), origin.y + CGFloat(deltaY))
                self.applyWindowOrigin(moved, for: handle)
            case .resize:
                self.applyWindowSize(
                    self.clampedContentSize(NSMakeSize(size.width + CGFloat(deltaX),
                                                       size.height + CGFloat(deltaY)),
                                            for: handle),
                    for: handle)
            }
        })
        gestureListeners.append(body.addEventListener(.pointerup) { [weak self] _ in
            self?.endWindowGesture()
        })
    }

    /// Applies the window's content size limits to a proposed size.
    ///
    /// Enforcing `contentMinSize` / `contentMaxSize` is the backend's job, not
    /// the core's: `NSWindow.frame` is a plain stored property, so the core
    /// records whatever size it is told and pushes nothing back. Win32 does
    /// this in `WM_GETMINMAXINFO`; here it is arithmetic. The demo sets a
    /// 900×600 floor, and without this a drag past it silently desynchronises
    /// the recorded frame from what the core believes.
    private func clampedContentSize(_ size: NSSize, for handle: NativeHandle) -> NSSize {
        // A window narrower than its own title bar cannot be grabbed again, so
        // there is a hard floor even when the app asks for none.
        var width = max(120, size.width)
        var height = max(60, size.height)
        if let minimum = records[handle]?.minContentSize {
            width = max(width, minimum.width)
            height = max(height, minimum.height)
        }
        if let maximum = records[handle]?.maxContentSize {
            width = min(width, maximum.width)
            height = min(height, maximum.height)
        }
        return NSMakeSize(width, height)
    }

    /// Drops the listeners installed for the duration of a drag.
    private func endWindowGesture() {
        gestureListeners.forEach { $0.remove() }
        gestureListeners.removeAll()
    }

    /// Moves a window and tells the core, which owns the consequences.
    private func applyWindowOrigin(_ origin: NSPoint, for handle: NativeHandle) {
        records[handle]?.frame.origin = origin
        _ = elements[handle]?
            .setStyle("left", "\(origin.x)px")
            .setStyle("top", "\(origin.y + Self.menuBarHeight)px")
        windowMoveActions[handle]?(origin)
    }

    /// Resizes a window and tells the core, which relays out and pushes frames
    /// back down through `setFrame`.
    private func applyWindowSize(_ size: NSSize, for handle: NativeHandle) {
        records[handle]?.frame.size = size
        _ = elements[handle]?.setStyle("width", "\(size.width)px")
        _ = windowContent[handle]?
            .setStyle("width", "\(size.width)px")
            .setStyle("height", "\(size.height)px")
        windowResizeActions[handle]?(size)
    }

    // MARK: - The dock

    /// The dock, created with the desktop on first use.
    internal func dockElement() -> Element? {
        if let dock { return dock }
        guard let desktop else { return nil }

        let bar = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "0").setStyle("right", "0").setStyle("bottom", "0")
            .setStyle("height", "\(Self.dockHeight)px")
            .setStyle("display", "flex")
            .setStyle("align-items", "center")
            .setStyle("gap", "8px")
            .setStyle("padding", "0 10px")
            .setStyle("background", "rgba(240,240,240,0.92)")
            .setStyle("border-top", "1px solid #c6c6c6")
            .setStyle("font", "12px system-ui, sans-serif")
            .setStyle("z-index", "900")
            // Empty until something is minimized: an always-visible empty bar
            // would just be eating 44 pixels of a demo that needs them.
            .setStyle("display", "none")
        _ = desktop.appendChild(bar)
        dock = bar
        return bar
    }

    /// Adds a window's tile to the dock, or removes it again.
    internal func setDockTile(_ present: Bool, for handle: NativeHandle) {
        guard let dock = dockElement() else { return }

        if !present {
            _ = dockTiles.removeValue(forKey: handle)?.remove()
            _ = dock.setStyle("display", dockTiles.isEmpty ? "none" : "flex")
            return
        }
        guard dockTiles[handle] == nil else { return }

        let tile = Element.button()
            .setStyle("max-width", "180px")
            .setStyle("overflow", "hidden")
            .setStyle("text-overflow", "ellipsis")
            .setStyle("white-space", "nowrap")
            .setStyle("padding", "6px 12px")
            .setStyle("font", "12px system-ui, sans-serif")
            .setStyle("cursor", "default")
        tile.textContent = records[handle]?.text ?? "Window"
        listeners[handle, default: []].append(tile.addEventListener(.click) { [weak self] _ in
            // Restore through the same path an app would use, so the core sees
            // an ordinary deminiaturize rather than a DOM-only change.
            self?.setWindowMinimized(false, for: handle)
        })
        _ = dock.appendChild(tile)
        dockTiles[handle] = tile
        _ = dock.setStyle("display", "flex")
    }
}

/// What a pointer drag on window chrome is doing.
internal enum WindowGestureKind {
    /// Dragging the title bar.
    case move
    /// Dragging the corner grip.
    case resize
}

#endif

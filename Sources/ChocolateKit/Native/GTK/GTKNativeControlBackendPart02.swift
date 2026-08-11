#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func installPaintTrace(_ handle: NativeHandle) {
        guard paintTrace, let w = widget(handle) else { return }
        let widget = asWidget(w)
        for signal in ["map", "unmap", "realize", "unrealize"] {
            let box = PaintTraceBox(backend: self, raw: handle.rawValue, event: signal)
            g_signal_connect_data(
                UnsafeMutableRawPointer(widget), signal,
                unsafeBitCast(gtkPaintTraceTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
        // The frame clock is the authority on repaints: one cycle per frame GTK
        // actually renders.
        guard let clock = gtk_widget_get_frame_clock(widget) else { return }
        for signal in ["layout", "after-paint"] {
            let box = PaintTraceBox(backend: self, raw: handle.rawValue, event: "clock:" + signal)
            g_signal_connect_data(
                UnsafeMutableRawPointer(clock), signal,
                unsafeBitCast(gtkPaintTraceTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
    }

    /// Presents the window (`gtk_window_present`).
    public func showWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        installPendingMainMenu(on: handle)
        // Realize before mapping so the surface exists and GTK can measure the
        // window, then map it.
        // Re-presenting an ALREADY-SHOWN window (the demo's inspector panel is
        // cached and re-ordered front on every press) must only raise it. Doing
        // the first-show work again re-sized a mapped window — a resize request
        // costs a window-manager round trip, which is why a second open measured
        // SLOWER than the first (2.1s then 3.5s on the reporter's display) — and
        // re-installed the trace handlers, so every later event logged twice.
        guard !presentedWindows.contains(handle.rawValue) else {
            tracePaint(handle.rawValue, "re-present")
            gtk_window_present(asWindow(w))
            return
        }
        presentedWindows.insert(handle.rawValue)

        // Size the window BEFORE realizing it. `gtk_widget_realize` creates the
        // GdkSurface, and with no size set that surface is created 1x1: the trace
        // showed `map surface=1x1` followed by a jump to the real size on the
        // first frame-clock cycle, i.e. the window is mapped tiny and then
        // resized — a visible flash, and the origin of the "blank repaints".
        //
        // Measure rather than reusing AppKit's contentRect: the window also
        // carries the menu bar and toolbar, and an earlier attempt that set the
        // content size mapped the window too short and then had to grow it.
        // Measuring gets content + chrome right in one step, for a panel (no
        // chrome) as much as for the main window.
        var minW: gint = 0, natW: gint = 0, minH: gint = 0, natH: gint = 0
        gtk_widget_measure(asWidget(w), GTK_ORIENTATION_HORIZONTAL, -1, &minW, &natW, nil, nil)
        gtk_widget_measure(asWidget(w), GTK_ORIENTATION_VERTICAL, natW, &minH, &natH, nil, nil)
        if natW > 0, natH > 0 {
            gtk_window_set_default_size(asWindow(w), natW, natH)
        }
        tracePaint(handle.rawValue, "pre-realize")
        gtk_widget_realize(asWidget(w))
        // Paint the X background to match the app BEFORE the window is mapped.
        // Between map and the first frame the X server fills the window with
        // this pixel, and that gap is seconds on a window manager that never
        // finishes GTK's frame-sync handshake. Left at the default it flashes
        // white against a dark app — the reported "blank screens". Matched to the
        // window background, the same wait is invisible. (Verified as the visible
        // symptom by Tools/window-timing-spike.c, whose light theme made the very
        // same flash near-invisible: white on white.)
        let background = NSColor.windowBackgroundColor
        lc_set_window_background_rgb(asWidget(w),
                                     Double(background.redComponent),
                                     Double(background.greenComponent),
                                     Double(background.blueComponent))
        // Drop GTK's frame-sync handshake where there is no compositor to sync
        // WITH. GTK holds a newly mapped window's first frame until the window
        // manager acknowledges it through a sync counter; quartz-wm advertises
        // the protocol and never answers, so GTK waited out its timeout — a
        // measured ~2 s for every window after the first, identical to the
        // millisecond across two different code paths. On a composited desktop
        // the handshake earns its keep (it is what keeps resizing tear-free), so
        // this is deliberately scoped to displays with no compositor, where the
        // wait buys nothing. `LINCHOCOLATE_KEEP_WM_SYNC=1` restores it.
        let keepSync = !(ProcessInfo.processInfo.environment["LINCHOCOLATE_KEEP_WM_SYNC"] ?? "").isEmpty
        if nonComposited, !keepSync {
            lc_strip_wm_sync_request(asWidget(w))
        }
        installPaintTrace(handle)
        tracePaint(handle.rawValue, "pre-present")
        gtk_window_present(asWindow(w))
        tracePaint(handle.rawValue, "post-present")
        // NOTE: there is deliberately NO "wait until laid out" loop here.
        //
        // An earlier version pumped the main context after `present` so the
        // content would have a size before returning. It was wrong, and it was
        // the cause of the reported flashing rather than a fix for it: GTK lays
        // a window out on the frame clock, so every pumped iteration while the
        // window is mapped-but-unlaid-out lets GTK render and push a BLANK frame
        // to the display — "several repainting blank screens before the real
        // one". A pure-GTK4 control program (Tools/window-timing-spike.c) waits
        // just as long for its first frame on the same display (1131 ms for a
        // second window) and shows no flashing at all, precisely because it
        // never pumps: it returns to the main loop and paints once, when ready.
        //
        // The multi-second wait for a second window's first frame is GTK's/the
        // window manager's (quartz-wm does not complete the frame-sync
        // handshake). We cannot shorten it — but we must not make it visible.
        if !(ProcessInfo.processInfo.environment["LINCHOCOLATE_GEOMETRY_AUDIT"] ?? "").isEmpty {
            let box = ActionBox { [weak self] in self?.auditGeometry() }
            g_timeout_add_seconds(2, { userData in
                guard let userData else { return gboolean(0) }
                Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
                return gboolean(0)   // one shot
            }, Unmanaged.passRetained(box).toOpaque())
        }
    }

    // MARK: Geometry audit

    /// Compares every placed widget's AppKit frame against what GTK actually
    /// allocated it. Enabled with `LINCHOCOLATE_GEOMETRY_AUDIT=1`.
    ///
    /// The frame is authoritative in AppKit: a view IS its frame. GTK's
    /// `gtk_widget_set_size_request` only sets a *minimum* and documents that it
    /// "will not cause a widget to be smaller than its natural size" — so any
    /// widget whose intrinsic minimum exceeds its AppKit frame silently
    /// overflows and collides with its neighbours. This audit surfaces exactly
    /// which controls do that, and by how much.
    func auditGeometry() {
        print("── LinChocolate geometry audit ─────────────────────────────────────────────")
        print(String(format: "%-14@ %-18@ %-13@ %-13@ %-14@ %@", "kind" as NSString, "frame x,y,w,h" as NSString,
                     "min w,h" as NSString, "alloc w,h" as NSString, "self/parent" as NSString, "verdict" as NSString))
        var violations = 0
        var pending = 0
        for (raw, w) in widgets.sorted(by: { $0.key < $1.key }) {
            guard let frame = frames[raw], let parentRaw = parents[raw] else { continue }
            guard gtk_widget_get_mapped(asWidget(w)) != 0 else { continue }
            let kind = kinds[raw].map { String(describing: $0) } ?? "view"
            let flip = (flippedViews.contains(raw) ? "flip" : "unflip")
                + "/" + (flippedViews.contains(parentRaw) ? "flip" : "unflip")

            var minW: gint = 0, natW: gint = 0, minH: gint = 0, natH: gint = 0
            gtk_widget_measure(asWidget(w), GTK_ORIENTATION_HORIZONTAL, -1, &minW, &natW, nil, nil)
            gtk_widget_measure(asWidget(w), GTK_ORIENTATION_VERTICAL, -1, &minH, &natH, nil, nil)
            // Measure the *allocated* (border) box, not gtk_widget_get_width():
            // that returns the CSS content box — allocation minus margin, border
            // and padding — so a correctly placed control still reads short by
            // exactly its padding. compute_bounds gives the real rect.
            var allocation = GTKGeometryAllocation()
            if let container = containerFixed(of: parentRaw) {
                var bounds = graphene_rect_t()
                if gtk_widget_compute_bounds(asWidget(w), asWidget(container), &bounds) != 0 {
                    allocation.x = Double(bounds.origin.x)
                    allocation.y = Double(bounds.origin.y)
                    allocation.width = Int(bounds.size.width.rounded())
                    allocation.height = Int(bounds.size.height.rounded())
                }
            }
            let wantX = Double(frame.origin.x)
            let wantY = Double(placementY(for: frame, in: parentRaw))

            // A 0x0 bounds means GTK has not allocated the widget yet, not that
            // it was allocated wrongly — an animating page (Auto Layout) can be
            // caught mid-relayout. Report it, but don't call it a frame fault.
            if allocation.width == 0 && allocation.height == 0 {
                pending += 1
                print("\(kind) \(Int(frame.origin.x)),\(Int(frame.origin.y)) — not allocated yet (mid-relayout?)")
                continue
            }
            let faults = geometryFaults(frame: frame, allocation: allocation, wantX: wantX, wantY: wantY)
            if faults.isEmpty { continue }
            violations += 1
            let frameDesc = "\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))"
            print(String(format: "%-14@ %-18@ %-13@ %-13@ %-14@ %@",
                         kind as NSString, frameDesc as NSString,
                         "\(minW),\(minH)" as NSString, "\(allocation.width),\(allocation.height)" as NSString,
                         flip as NSString, faults.joined(separator: "  ") as NSString))
        }
        print("── \(violations) control(s) not honouring their AppKit frame"
              + (pending > 0 ? "; \(pending) not yet allocated" : "") + " ─────────────────")
        fflush(nil)   // stdout is fully buffered when piped
    }

    internal func geometryFaults(
        frame: NSRect,
        allocation: GTKGeometryAllocation,
        wantX: Double,
        wantY: Double
    ) -> [String] {
        var faults: [String] = []
        if allocation.width >= 0, Int(frame.width) != allocation.width {
            faults.append("W \(Int(frame.width))→\(allocation.width)")
        }
        if allocation.height >= 0, Int(frame.height) != allocation.height {
            faults.append("H \(Int(frame.height))→\(allocation.height)")
        }
        if allocation.x.isFinite, abs(allocation.x - wantX) > 0.5 {
            faults.append("X \(Int(wantX))→\(Int(allocation.x))")
        }
        if allocation.y.isFinite, abs(allocation.y - wantY) > 0.5 {
            faults.append("Y \(Int(wantY))→\(Int(allocation.y))")
        }
        return faults
    }

    /// Hides the window without destroying it (AppKit's `orderOut`).
    public func setWindowResizeAction(for handle: NativeHandle, _ handler: @escaping (Double, Double) -> Void) {
        // GTK4 has no public size-allocate signal, and a window's
        // default-width/height do NOT change for a resize driven by the WM — so
        // neither is usable here. The content view's DRAW pass is: it re-runs
        // with the new width/height on every resize (that is what repaints the
        // background at the new size). `noteContentDraw` compares sizes there and
        // fires this handler when it actually changed.
        windowResizeActions[handle.rawValue] = handler
    }
    /// Called from the content view's draw pass. Fires the window's resize
    /// handler when the size really changed, from an idle callback so layout
    /// never runs inside a draw.
    func noteContentDraw(view raw: UInt, width: Double, height: Double) {
        guard let window = contentViewOwners[raw], let handler = windowResizeActions[window] else { return }
        guard lastContentSizes[window] != NSMakeSize(width, height) else { return }
        let isFirstSize = lastContentSizes[window] == nil
        lastContentSizes[window] = NSMakeSize(width, height)
        // The first size is the window's initial layout, not a resize: AppKit
        // does not post `windowDidResize` for it. Recording it as the baseline
        // (and not notifying) also spares a layout pass during the first map.
        guard !isFirstSize else { return }
        let box = ActionBox { handler(width, height) }
        g_idle_add({ userData in
            guard let userData else { return gboolean(0) }
            Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
            return gboolean(0)   // one shot
        }, Unmanaged.passRetained(box).toOpaque())
    }
    /// Performs the `setWindowParent` operation.
    public func setWindowParent(_ parent: NativeHandle, for handle: NativeHandle) {
        guard let w = widget(handle), let p = widget(parent) else { return }
        // A transient window is placed and decorated by the WM as a utility
        // window of its parent, in one pass. Without this a panel maps as an
        // unrelated new toplevel and goes through full placement/decoration
        // negotiation — extra visible mapping work on a remote/slow display.
        gtk_window_set_transient_for(asWindow(w), asWindow(p))
        // AppKit keeps the panel alive independently of the parent's lifetime.
        gtk_window_set_destroy_with_parent(asWindow(w), gboolean(0))
    }
    /// Performs the `hideWindow` operation.
    public func hideWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_visible(asWidget(w), gboolean(0))
    }

    /// Performs the `toggleZoomWindow` operation.
    public func toggleZoomWindow(_ handle: NativeHandle) {
        // Track intent ourselves. AppKit's `zoom(_:)` is synchronous — `isZoomed`
        // reads true the instant it returns — but GTK's `is_maximized` reflects
        // the compositor's *acknowledged* surface state, which lands a frame or
        // two later (and never, with no window manager). Mirroring the request
        // keeps `isZoomed` truthful immediately, as the demo reads it.
        let nowZoomed = !zoomedWindows.contains(handle.rawValue)
        guard let content = windowContents[handle.rawValue], let w = widget(handle) else { return }
        let cw = asWidget(content)
        let win = asWindow(w)
        if nowZoomed {
            zoomedWindows.insert(handle.rawValue)
            // Zoom on Linux follows the desktop convention (fill the screen), NOT
            // AppKit's fit-to-content. We do NOT call `gtk_window_maximize`: the
            // diagnostic proved that under quartz-wm (XQuartz) it locks the window
            // size and the surface never grows — the content stayed 1120 in a
            // maximized frame (the black void). Instead we grow the CONTENT to the
            // monitor size, which makes GTK issue a normal client resize; a WM that
            // honors client resizes (mutter/kwin, and — un-maximized — quartz-wm)
            // grows the surface, and the content's expand/fill makes it cover the
            // window. Children stay frame-placed.
            let (mw, mh) = monitorWorkArea()
            // Remember the window's current size so un-zoom restores it.
            preZoomContentSize[handle.rawValue] = (Int32(gtk_widget_get_width(UnsafeMutablePointer<GtkWidget>(OpaquePointer(win)))),
                                                   Int32(gtk_widget_get_height(UnsafeMutablePointer<GtkWidget>(OpaquePointer(win)))))
            // The content must FILL whatever the window becomes; it must not be
            // floored by a size_request (a floor also blocks later shrinking, and
            // an over-large floor makes a WM refuse the resize outright).
            gtk_widget_set_hexpand(cw, gboolean(1)); gtk_widget_set_vexpand(cw, gboolean(1))
            gtk_widget_set_halign(cw, GTK_ALIGN_FILL); gtk_widget_set_valign(cw, GTK_ALIGN_FILL)
            // GTK4 has no `gtk_window_resize`; set_default_size resizes a mapped
            // window. Sizes are LOGICAL pixels — the monitor geometry comes back in
            // device pixels on a scaled/retina display (3200x1767 on the reporter's
            // Mac), and asking for a window larger than the screen is exactly what
            // quartz-wm refused.
            gtk_window_set_default_size(win, mw, mh)
            gtk_widget_queue_resize(cw)
            logZoom("request", handle: handle, content: cw, window: win, req: (mw, mh))
        } else {
            zoomedWindows.remove(handle.rawValue)
            if let (rw, rh) = preZoomContentSize[handle.rawValue], rw > 0, rh > 0 {
                gtk_window_set_default_size(win, rw, rh)
                preZoomContentSize[handle.rawValue] = nil
            }
        }
    }
    /// Env-gated (`LINCHOCOLATE_ZOOM_DEBUG`) diagnostics: logs the requested size
    /// now, and the content's *actual* allocation a moment later. Lets us see, on
    /// a setup we can't reproduce, whether the monitor query or the resize is the
    /// problem.
}

#endif

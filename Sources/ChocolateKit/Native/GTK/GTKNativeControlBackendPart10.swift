#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    public func createImageView(frame: NSRect) -> NativeHandle {
        let picture = gtk_picture_new()!
        gtk_widget_set_size_request(picture, Int32(frame.width), Int32(frame.height))
        return allocate(picture, .imageView, frame: frame)
    }
    /// Loads (or clears with nil) the picture from a file path.
    public func setImagePath(_ path: String?, for handle: NativeHandle) {
        imageViewPaths[handle.rawValue] = path
        renderImageView(handle)
    }
    /// Performs the `setImageTint` operation.
    public func setImageTint(_ color: NSColor?, isTemplate: Bool, for handle: NativeHandle) {
        if let color, isTemplate {
            imageViewTints[handle.rawValue] = GTKRGB(
                red: UInt8(color.redComponent * 255),
                green: UInt8(color.greenComponent * 255),
                blue: UInt8(color.blueComponent * 255)
            )
        } else {
            imageViewTints[handle.rawValue] = nil
        }
        renderImageView(handle)
    }
    /// (Re)paints an image view from its stored path, recoloring the artwork to
    /// the tint when one is set (AppKit template semantics: keep alpha, replace RGB).
    internal func renderImageView(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        guard let path = imageViewPaths[handle.rawValue] else {
            gtk_picture_set_filename(w, nil)
            return
        }
        guard let tint = imageViewTints[handle.rawValue],
              let pixbuf = gdk_pixbuf_new_from_file(path, nil),
              gdk_pixbuf_get_has_alpha(pixbuf) != 0, gdk_pixbuf_get_n_channels(pixbuf) == 4 else {
            gtk_picture_set_filename(w, path)
            return
        }
        recolorPixbuf(pixbuf, to: tint)
        if let texture = gdk_texture_new_for_pixbuf(pixbuf) {
            gtk_picture_set_paintable(w, texture)
        }
    }
    /// Replaces every pixel's RGB with `rgb`, keeping alpha (template recolor).
    internal func recolorPixbuf(_ pixbuf: OpaquePointer, to rgb: GTKRGB) {
        let width = Int(gdk_pixbuf_get_width(pixbuf))
        let height = Int(gdk_pixbuf_get_height(pixbuf))
        let stride = Int(gdk_pixbuf_get_rowstride(pixbuf))
        guard let pixels = gdk_pixbuf_get_pixels(pixbuf) else { return }
        for y in 0..<height {
            for x in 0..<width {
                let p = pixels + y * stride + x * 4
                p[0] = rgb.red
                p[1] = rgb.green
                p[2] = rgb.blue
            }
        }
    }
    /// Creates a titled `GtkFrame` as the box container.
    public func createBox(title: String, frame: NSRect) -> NativeHandle {
        let f = gtk_frame_new(title)!
        gtk_widget_set_size_request(f, Int32(frame.width), Int32(frame.height))
        return allocate(f, .box, frame: frame)
    }
    /// Creates a `GtkScrolledWindow` with permanent scroller gutters.
    public func createScrollView(frame: NSRect) -> NativeHandle {
        let sw = gtk_scrolled_window_new()!
        gtk_widget_set_size_request(sw, Int32(frame.width), Int32(frame.height))
        // Reserve a permanent gutter for the scrollbar instead of floating it
        // over the content (AppKit's legacy scrollers take space). GTK's overlay
        // scrollbar otherwise draws atop the right edge — and on a non-composited
        // display (XQuartz) that overlay renders as an opaque strip clipping the
        // content rather than the viewport resizing to make room for it.
        gtk_scrolled_window_set_overlay_scrolling(OpaquePointer(sw), gboolean(0))
        return allocate(sw, .scrollView, frame: frame)
    }
    /// Sets per-axis scroller visibility policy via `gtk_scrolled_window_set_policy`.
    public func setScrollerPolicy(vertical: Bool, horizontal: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_scrolled_window_set_policy(w,   // GtkScrolledWindow is opaque
            horizontal ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER,
            vertical ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER)
    }
    /// Sets the scroll adjustments' values to `(x, y)`.
    public func setScrollOffset(x: Double, y: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_adjustment_set_value(gtk_scrolled_window_get_hadjustment(w), x)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(w), y)
    }
    /// Returns the scroll adjustments' current values.
    public func scrollOffset(for handle: NativeHandle) -> (x: Double, y: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_value(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_value(gtk_scrolled_window_get_vadjustment(w)))
    }
    /// Returns the total scrollable content size (each adjustment's upper).
    public func scrollDocumentSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_upper(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_upper(gtk_scrolled_window_get_vadjustment(w)))
    }
    /// Returns the visible viewport size (each adjustment's page size).
    public func scrollVisibleSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_page_size(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_page_size(gtk_scrolled_window_get_vadjustment(w)))
    }
    /// Wires both scroll adjustments' `value-changed` signals to report the new offset.
    public func setScrollChangeAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        guard let w = widget(handle),
              let hadj = gtk_scrolled_window_get_hadjustment(w),
              let vadj = gtk_scrolled_window_get_vadjustment(w) else { return }
        let box = ScrollBox(hadj: hadj, vadj: vadj, action: action)
        // Both adjustments drive the same box; retain once per connection.
        for adjustment in [hadj, vadj] {
            g_signal_connect_data(
                UnsafeMutableRawPointer(adjustment), "value-changed",
                unsafeBitCast(gtkScrollChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
    }
    /// Creates a `GtkPaned`; AppKit `vertical` = vertical divider = GTK horizontal orientation.
    public func createSplitView(vertical: Bool, frame: NSRect) -> NativeHandle {
        // AppKit "vertical" = vertical divider = panes side by side, which is
        // GTK's *horizontal* orientation.
        let orientation = vertical ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL
        let paned = gtk_paned_new(orientation)!
        gtk_widget_set_size_request(paned, Int32(frame.width), Int32(frame.height))
        return allocate(paned, .splitView, frame: frame)
    }
    /// Adds `pane` as the next `GtkPaned` child (first = leading/top, second = trailing/bottom).
    public func addSplitPane(_ pane: NativeHandle, to splitView: NativeHandle) {
        guard let paned = widget(splitView), let p = widget(pane) else { return }
        let count = splitPaneCounts[splitView.rawValue, default: 0]
        if count == 0 {
            gtk_paned_set_start_child(paned, asWidget(p))   // GtkPaned is opaque
            // Pin the leading pane to the divider position (don't let it grow to
            // its natural width and push the divider right).
            gtk_paned_set_resize_start_child(paned, gboolean(0))
            gtk_paned_set_shrink_start_child(paned, gboolean(0))
        } else {
            gtk_paned_set_end_child(paned, asWidget(p))
            // The trailing pane fills the remaining width but never shrinks below
            // its content — otherwise the pane's box is clipped on the right.
            gtk_paned_set_resize_end_child(paned, gboolean(1))
            gtk_paned_set_shrink_end_child(paned, gboolean(0))
        }
        splitPaneCounts[splitView.rawValue] = count + 1
    }
    /// Moves the paned's divider to `position` (pixels from the leading edge).
    public func setDividerPosition(_ position: Double, for splitView: NativeHandle) {
        guard let paned = widget(splitView) else { return }
        gtk_paned_set_position(paned, gint(position))
    }
    /// Toggles `gtk_widget_set_overflow` between `HIDDEN` and `VISIBLE`.
    public func setClipsToBounds(_ clips: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_overflow(asWidget(w), clips ? GTK_OVERFLOW_HIDDEN : GTK_OVERFLOW_VISIBLE)
    }

    /// Records the view's flip state and re-places every child accordingly.
    public func setViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        let was = flippedViews.contains(handle.rawValue)
        if flipped { flippedViews.insert(handle.rawValue) } else { flippedViews.remove(handle.rawValue) }
        // isFlipped is per-view, not app-wide: this view may disagree with its
        // parent and its own children. Changing it re-reads every child's Y.
        if was != flipped { replaceChildren(of: handle.rawValue) }
    }

    /// Re-places every child of `parentRaw` from its (unchanged) AppKit frame.
    ///
    /// A child's GTK Y is derived from *this* parent's height and *this*
    /// parent's flip — so resizing the parent, or flipping it, invalidates
    /// every child's position even though no child's frame changed. Only
    /// unflipped parents actually move their children, but re-placing is
    /// idempotent, so it is not worth special-casing.
    internal func replaceChildren(of parentRaw: UInt) {
        guard let container = containerFixed(of: parentRaw) else { return }
        var moved = false
        for childRaw in childrenByParent[parentRaw] ?? [] {
            guard let w = widgets[childRaw], let childFrame = frames[childRaw] else { continue }
            setExactRect(placement(for: childFrame, in: parentRaw), on: w)
            moved = true
        }
        if moved { gtk_widget_queue_allocate(asWidget(container)) }
    }

    /// Whether `view` draws in a top-left (flipped) coordinate space.
    func isViewFlipped(_ view: UInt) -> Bool {
        // Read only by the draw trampoline, to decide whether Cairo needs the
        // Y-axis flip that lets bottom-left AppKit drawing code work. The
        // shared core always authors in top-left device coordinates (it grew up
        // on GDI), so a view it draws needs no flip — with one, the pill shapes
        // survived because a rounded rect is vertically symmetric, but every
        // glyph came out mirrored. Layout's own notion of flipped-ness is
        // `flippedViews`, which this deliberately does not disturb.
        flippedViews.contains(view) || coreSeam.topLeftDrawing.contains(view)
    }

    /// The magnification applied to `view`'s custom drawing (1 = no zoom).
    func viewMagnification(_ view: UInt) -> Double { viewMagnifications[view] ?? 1 }

    /// Scales a document view's drawing and enlarges its requested size so a
    /// hosting `GtkScrolledWindow` reports the enlarged scrollable extent —
    /// the backing for `NSScrollView.magnification`.
    public func setViewMagnification(_ magnification: Double, for handle: NativeHandle) {
        // The natural (unscaled) size is what the view was created at.
        guard let overlay = widget(handle), let natural = frames[handle.rawValue] else { return }
        let scale = magnification > 0 ? magnification : 1
        viewMagnifications[handle.rawValue] = scale
        gtk_widget_set_size_request(asWidget(overlay),
                                    Int32((natural.width  * CGFloat(scale)).rounded()),
                                    Int32((natural.height * CGFloat(scale)).rounded()))
        if let area = viewDrawAreas[handle.rawValue] {
            gtk_widget_queue_draw(asWidget(area))
        }
    }

    /// The exact rect `childFrame` occupies inside `parentRaw`, in GTK's
    /// top-left space. The one place a child's geometry is decided — see
    /// `CoordinateSpace.place`.
    internal func placement(for childFrame: NSRect, in parentRaw: UInt) -> NSRect {
        CoordinateSpace.place(childFrame,
                              inParentOfHeight: frames[parentRaw]?.height ?? 0,
                              parentIsFlipped: flippedViews.contains(parentRaw))
    }

    /// The GTK (top-left) Y for `childFrame` inside `parentRaw`.
    internal func placementY(for childFrame: NSRect, in parentRaw: UInt) -> CGFloat {
        placement(for: childFrame, in: parentRaw).origin.y
    }

    /// Places `child` inside `parent`'s child-hosting `GtkFixed` at the child's frame origin.
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        guard let c = widget(child) else { return }
        guard let p = containerFixed(of: parent.rawValue) else {
            // The parent hosts no children (it is not an NSView-backed
            // container). Silently dropping the child is how controls went
            // missing, so say so instead.
            let kind = kinds[parent.rawValue].map { String(describing: $0) } ?? "?"
            let message = "LinChocolate: cannot add a subview to a " + kind
                + " - it has no child area; the child will not appear.\n"
            FileHandle.standardError.write(Data(message.utf8))
            return
        }
        parents[child.rawValue] = parent.rawValue
        childrenByParent[parent.rawValue, default: []].append(child.rawValue)
        let childFrame = frames[child.rawValue] ?? .zero
        setExactRect(placement(for: childFrame, in: parent.rawValue), on: c)
        gtk_widget_set_parent(asWidget(c), asWidget(p))
        gtk_widget_queue_allocate(asWidget(p))
        // AppKit groups radio buttons that share a superview; mirror that so the
        // GtkCheckButtons render round and behave mutually exclusively.
        if kinds[child.rawValue] == .radio {
            if let lead = radiosByParent[parent.rawValue]?.first, let leadW = widgets[lead] {
                gtk_check_button_set_group(asCheckButton(c), asCheckButton(leadW))
            }
            radiosByParent[parent.rawValue, default: []].append(child.rawValue)
        }
    }

    // MARK: Mutators
    /// Updates a control's text/title, dispatched by kind to the appropriate GTK setter.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .button:    gtk_button_set_label(asButton(w), text)
        case .label:     gtk_label_set_text(w, text)          // GtkLabel is opaque
        case .textField, .secureField, .searchField: gtk_editable_set_text(w, text)
        case .comboBox:  if let e = comboEntries[handle.rawValue] { gtk_editable_set_text(e, text) }
        case .checkbox, .radio: gtk_check_button_set_label(asCheckButton(w), text)
        case .textView:  gtk_text_buffer_set_text(gtk_text_view_get_buffer(asTextView(w)), text, -1)
        default: setContainerText(text, widget: w, handle: handle)
        }
    }

    internal func setContainerText(_ text: String, widget: OpaquePointer, handle: NativeHandle) {
        switch kinds[handle.rawValue] {
        case .box: gtk_frame_set_label(asFrame(widget), text)
        case .window: gtk_window_set_title(asWindow(widget), text)
        case .view: setViewText(text, for: handle)
        default: break
        }
    }

    /// Displays `text` on a plain view.
    ///
    /// A Win32 view is a static control, so the shared core sets text straight
    /// on one and expects it to show — that is how a toolbar item's icon-and-
    /// label tile renders (`NSToolbarCompositeItemView.updateNativeText`).
    /// GTK's view is a GtkOverlay with a drawing area and a child area, and
    /// neither displays text, so the toolbar came up as a row of blank tiles.
    /// A centered label overlaid on the view is the missing piece.
    internal func setViewText(_ text: String, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard let overlay = widgets[raw] else { return }

        // Drop whatever this view showed before; the core re-sends the whole
        // description on every change.
        if let old = coreSeam.viewTextLabels[raw] {
            gtk_widget_unparent(UnsafeMutablePointer<GtkWidget>(old))
            coreSeam.viewTextLabels[raw] = nil
        }

        guard let content = viewTextContent(text) else { return }
        gtk_widget_set_halign(content, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(content, GTK_ALIGN_CENTER)
        gtk_overlay_add_overlay(overlay, content)
        coreSeam.viewTextLabels[raw] = OpaquePointer(content)
    }

    /// Builds the widget a plain view's text asks for, or nil for nothing.
    ///
    /// A toolbar item tile does not send a label — it sends a tab-separated
    /// description (`NSToolbarCompositeItemView.nativeText`) that the Win32
    /// side decodes into an icon and a caption. Rendering it verbatim printed
    /// the image's file path across the toolbar, so it is decoded here too.
}

#endif

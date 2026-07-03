/// Base class for visible rectangular content.
///
/// `NSView` owns a frame, a child hierarchy, and a lazily-created native peer.
/// Subclasses override `realizeNativePeer(in:)` to request a specific Windows
/// control kind while keeping AppKit-style view composition at the public API.
open class NSView: NSResponder {
    /// Autoresizing behavior flags matching AppKit names.
    public struct AutoresizingMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates an autoresizing mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Left margin can change.
        public static let minXMargin = AutoresizingMask(rawValue: 1 << 0)

        /// Width can change.
        public static let width = AutoresizingMask(rawValue: 1 << 1)

        /// Right margin can change.
        public static let maxXMargin = AutoresizingMask(rawValue: 1 << 2)

        /// Bottom margin can change.
        public static let minYMargin = AutoresizingMask(rawValue: 1 << 3)

        /// Height can change.
        public static let height = AutoresizingMask(rawValue: 1 << 4)

        /// Top margin can change.
        public static let maxYMargin = AutoresizingMask(rawValue: 1 << 5)
    }

    /// The view frame in its parent coordinate space.
    open var frame: NSRect {
        didSet {
            autoresizeSubviews(from: oldValue.size, to: frame.size)

            guard let nativeHandle else {
                return
            }

            realizedBackend?.setFrame(frame, for: nativeHandle)
        }
    }

    /// The view bounds in its own coordinate space.
    open var bounds: NSRect {
        NSRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
    }

    /// Application-defined integer tag used to find views in a hierarchy.
    open var tag: Int = 0

    /// Autoresizing behavior for legacy frame-based layouts.
    open var autoresizingMask: AutoresizingMask = []

    /// Whether child views should be autoresized by this view.
    open var autoresizesSubviews: Bool = true

    /// Whether this view requests layer-backed rendering.
    open var wantsLayer: Bool = false

    /// Informational tooltip text.
    open var toolTip: String? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setToolTip(toolTip, for: nativeHandle)
        }
    }

    /// The view's parent view.
    public private(set) weak var superview: NSView?

    /// The view's child views.
    public private(set) var subviews: [NSView] = []

    /// The next view in the keyboard focus loop.
    open weak var nextKeyView: NSView?

    /// The previous view in the keyboard focus loop.
    open weak var previousKeyView: NSView?

    /// The nearest containing window, when this view is attached to one.
    open var window: NSWindow? {
        if let superview {
            return superview.window
        }

        return nextResponder as? NSWindow
    }

    /// The backend-created native handle, if realized.
    public private(set) var nativeHandle: NativeHandle?

    /// Backend that created the native peer, if realized.
    public private(set) weak var realizedBackend: NativeControlBackend?

    /// Whether the view needs a redraw on the next paint pass.
    ///
    /// Setting `true` invalidates the realized native peer; the flag clears
    /// when the native paint pass calls `draw(_:)`.
    open var needsDisplay = false {
        didSet {
            guard needsDisplay, let nativeHandle else {
                return
            }

            realizedBackend?.invalidateControl(nativeHandle)
        }
    }

    /// Whether the view is hidden from display.
    open var isHidden: Bool = false {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setHidden(isHidden, for: nativeHandle)
        }
    }

    /// The view background color, when explicitly set.
    open var backgroundColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setBackgroundColor(backgroundColor, for: nativeHandle)
        }
    }

    /// Creates a view with a frame.
    public init(frame frameRect: NSRect) {
        self.frame = frameRect
        super.init()
    }

    /// Plain WinChocolate views can accept keyboard focus.
    open override var acceptsFirstResponder: Bool {
        true
    }

    /// Adds a child view.
    open func addSubview(_ view: NSView) {
        addSubview(view, positioned: .above, relativeTo: nil)
    }

    /// Adds a child view at a position relative to another child view.
    open func addSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
        view.removeFromSuperview()
        view.superview = self
        view.nextResponder = self
        insertSubview(view, positioned: place, relativeTo: otherView)

        guard let realizedBackend, let nativeHandle else {
            return
        }

        view.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
    }

    /// Replaces one child view with another while preserving the child position.
    open func replaceSubview(_ oldView: NSView, with newView: NSView) {
        guard let index = subviews.firstIndex(where: { $0 === oldView }) else {
            addSubview(newView)
            return
        }

        oldView.superview = nil
        oldView.nextResponder = nil
        oldView.destroyNativePeer()
        newView.removeFromSuperview()
        newView.superview = self
        newView.nextResponder = self
        subviews[index] = newView

        guard let realizedBackend, let nativeHandle else {
            return
        }

        newView.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
    }

    /// Removes the view from its parent hierarchy.
    open func removeFromSuperview() {
        guard let superview else {
            return
        }

        superview.subviews.removeAll { $0 === self }
        self.superview = nil
        self.nextResponder = nil
        destroyNativePeer()
    }

    /// Marks the view as needing display.
    open func setNeedsDisplay(_ needsDisplay: Bool) {
        self.needsDisplay = needsDisplay
    }

    private func autoresizeSubviews(from oldSize: NSSize, to newSize: NSSize) {
        guard autoresizesSubviews, oldSize != newSize else {
            return
        }

        let deltaWidth = newSize.width - oldSize.width
        let deltaHeight = newSize.height - oldSize.height
        guard deltaWidth != 0 || deltaHeight != 0 else {
            return
        }

        for subview in subviews {
            var newFrame = subview.frame
            let mask = subview.autoresizingMask

            if mask.contains(.width) {
                newFrame.size.width = max(0, newFrame.size.width + deltaWidth)
            } else if mask.contains(.minXMargin), !mask.contains(.maxXMargin) {
                newFrame.origin.x += deltaWidth
            } else if mask.contains(.minXMargin), mask.contains(.maxXMargin) {
                newFrame.origin.x += deltaWidth / 2
            }

            if mask.contains(.height) {
                newFrame.size.height = max(0, newFrame.size.height + deltaHeight)
            } else if mask.contains(.minYMargin), !mask.contains(.maxYMargin) {
                newFrame.origin.y += deltaHeight
            } else if mask.contains(.minYMargin), mask.contains(.maxYMargin) {
                newFrame.origin.y += deltaHeight / 2
            }

            subview.frame = newFrame
        }
    }

    /// Returns true when this view is contained by the given ancestor.
    open func isDescendant(of view: NSView) -> Bool {
        var current = superview
        while let candidate = current {
            if candidate === view {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    /// Finds the first view in this hierarchy with the given tag.
    open func viewWithTag(_ tag: Int) -> NSView? {
        if self.tag == tag {
            return self
        }

        for subview in subviews {
            if let match = subview.viewWithTag(tag) {
                return match
            }
        }

        return nil
    }

    /// Converts a point from another view's coordinate space into this view's coordinate space.
    open func convert(_ point: NSPoint, from view: NSView?) -> NSPoint {
        let windowPoint = view?.convertPointToWindow(point) ?? point
        return convertPointFromWindow(windowPoint)
    }

    /// Converts a point from this view's coordinate space into another view's coordinate space.
    open func convert(_ point: NSPoint, to view: NSView?) -> NSPoint {
        let windowPoint = convertPointToWindow(point)
        return view?.convertPointFromWindow(windowPoint) ?? windowPoint
    }

    /// Converts a rectangle from another view's coordinate space into this view's coordinate space.
    open func convert(_ rect: NSRect, from view: NSView?) -> NSRect {
        NSRect(origin: convert(rect.origin, from: view), size: rect.size)
    }

    /// Converts a rectangle from this view's coordinate space into another view's coordinate space.
    open func convert(_ rect: NSRect, to view: NSView?) -> NSRect {
        NSRect(origin: convert(rect.origin, to: view), size: rect.size)
    }

    /// Returns the deepest visible subview containing the point, or this view.
    open func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, NSPointInRect(point, bounds) else {
            return nil
        }

        for subview in subviews.reversed() {
            let childPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(childPoint) {
                return hitView
            }
        }

        return self
    }

    /// Ensures the view and its children have native peers.
    @discardableResult
    open func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if let nativeHandle {
            return nativeHandle
        }

        let handle = createNativePeer(in: backend, parent: parent)
        nativeHandle = handle
        realizedBackend = backend
        backend.setHidden(isHidden, for: handle)
        backend.setBackgroundColor(backgroundColor, for: handle)
        backend.setToolTip(toolTip, for: handle)
        backend.registerMouseDownAction(for: handle) { [weak self] event in
            _ = self?.window?.makeFirstResponder(self)
            self?.mouseDown(with: event)
        }
        backend.registerMouseUpAction(for: handle) { [weak self] event in
            self?.mouseUp(with: event)
        }
        backend.registerMouseMovedAction(for: handle) { [weak self] event in
            self?.mouseMoved(with: event)
        }
        backend.registerMouseDraggedAction(for: handle) { [weak self] event in
            self?.mouseDragged(with: event)
        }
        backend.registerKeyDownAction(for: handle) { [weak self] event in
            self?.keyDown(with: event)
        }
        backend.registerKeyUpAction(for: handle) { [weak self] event in
            self?.keyUp(with: event)
        }
        backend.registerRightMouseDownAction(for: handle) { [weak self] event in
            self?.rightMouseDown(with: event)
        }
        backend.registerRightMouseUpAction(for: handle) { [weak self] event in
            self?.rightMouseUp(with: event)
        }
        backend.registerOtherMouseDownAction(for: handle) { [weak self] event in
            self?.otherMouseDown(with: event)
        }
        backend.registerOtherMouseUpAction(for: handle) { [weak self] event in
            self?.otherMouseUp(with: event)
        }
        backend.registerScrollWheelAction(for: handle) { [weak self] event in
            self?.scrollWheel(with: event)
        }
        backend.registerDrawAction(for: handle) { [weak self] nativeContext, dirtyRect in
            guard let self else {
                return
            }

            self.needsDisplay = false
            NSGraphicsContext(nativeContext: nativeContext).asCurrent {
                self.draw(dirtyRect)
            }
        }
        updateCursorRegions()

        for subview in subviews {
            subview.realizeNativePeer(in: backend, parent: handle)
        }

        return handle
    }

    // MARK: - Cursor rectangles

    private var cursorRects: [(rect: NSRect, cursor: NSCursor)] = []

    /// Associates a hover cursor with a rectangle in local coordinates.
    ///
    /// Call from `resetCursorRects()`, matching AppKit's contract; rects
    /// added elsewhere are discarded on the next invalidation.
    open func addCursorRect(_ rect: NSRect, cursor: NSCursor) {
        cursorRects.append((rect, cursor))
    }

    /// Removes all of the view's cursor rectangles.
    open func discardCursorRects() {
        cursorRects.removeAll()
    }

    /// Override point: rebuild cursor rectangles with `addCursorRect`.
    open func resetCursorRects() {
    }

    /// Discards, rebuilds, and pushes cursor rectangles to the native peer.
    internal func updateCursorRegions() {
        discardCursorRects()
        resetCursorRects()
        guard let nativeHandle, let realizedBackend else {
            return
        }

        let regions = cursorRects.map { NativeCursorRegion(rect: $0.rect, cursorName: $0.cursor.cursorName) }
        realizedBackend.setCursorRegions(regions, for: nativeHandle)
    }

    /// The nearest ancestor scroll view containing this view, if any.
    open var enclosingScrollView: NSScrollView? {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            ancestor = view.superview
        }
        return nil
    }

    /// Scrolls the nearest enclosing scroll view to make a rect visible.
    ///
    /// The rectangle is in this view's coordinates. Returns whether any
    /// scrolling occurred, matching AppKit.
    @discardableResult
    open func scrollToVisible(_ rect: NSRect) -> Bool {
        guard let scrollView = enclosingScrollView, let documentView = scrollView.documentView else {
            return false
        }

        let clipView = scrollView.contentView
        // Work in document coordinates so the comparison matches
        // `documentVisibleRect`, which is expressed there too.
        let target = convert(rect, to: documentView)
        let visible = clipView.documentVisibleRect
        var origin = clipView.boundsOrigin

        if NSMinX(target) < NSMinX(visible) {
            origin.x = NSMinX(target)
        } else if NSMaxX(target) > NSMaxX(visible) {
            origin.x += NSMaxX(target) - NSMaxX(visible)
        }

        if NSMinY(target) < NSMinY(visible) {
            origin.y = NSMinY(target)
        } else if NSMaxY(target) > NSMaxY(visible) {
            origin.y += NSMaxY(target) - NSMaxY(visible)
        }

        let constrained = clipView.constrainBoundsRect(NSRect(origin: origin, size: visible.size)).origin
        guard constrained != clipView.boundsOrigin else {
            return false
        }

        clipView.scroll(to: constrained)
        return true
    }

    /// Gives this view and its subtree a chance to consume a key equivalent.
    ///
    /// Subviews are asked depth-first before the main menu sees the event,
    /// matching AppKit's dispatch order. The base implementation only
    /// forwards; views with their own shortcuts override and return `true`
    /// when they handle the event.
    open func performKeyEquivalent(with event: NSEvent) -> Bool {
        for subview in subviews where !subview.isHidden {
            if subview.performKeyEquivalent(with: event) {
                return true
            }
        }
        return false
    }

    /// Draws the view's custom content.
    ///
    /// Called during a native paint pass with `NSGraphicsContext.current`
    /// installed, after the view's `backgroundColor` has been painted.
    /// Subclasses override this and draw with `NSBezierPath`, `NSColor`, and
    /// `NSRectFill`; the base implementation draws nothing.
    open func draw(_ dirtyRect: NSRect) {
    }


    /// Creates the native peer for this specific view type.
    open func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Destroys the native peer for this view and its children.
    open func destroyNativePeer() {
        for subview in subviews {
            subview.destroyNativePeer()
        }

        guard let nativeHandle, let realizedBackend else {
            return
        }

        realizedBackend.destroyControl(nativeHandle)
        self.nativeHandle = nil
        self.realizedBackend = nil
    }

    private func convertPointToWindow(_ point: NSPoint) -> NSPoint {
        var converted = point
        var current: NSView? = self

        while let view = current {
            converted.x += view.frame.origin.x
            converted.y += view.frame.origin.y
            current = view.superview
        }

        return converted
    }

    private func convertPointFromWindow(_ point: NSPoint) -> NSPoint {
        var converted = point
        var chain: [NSView] = []
        var current: NSView? = self

        while let view = current {
            chain.append(view)
            current = view.superview
        }

        for view in chain {
            converted.x -= view.frame.origin.x
            converted.y -= view.frame.origin.y
        }

        return converted
    }

    private func insertSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
        guard let otherView, let index = subviews.firstIndex(where: { $0 === otherView }) else {
            switch place {
            case .above:
                subviews.append(view)
            case .below:
                subviews.insert(view, at: 0)
            case .out:
                subviews.append(view)
            }
            return
        }

        switch place {
        case .above:
            subviews.insert(view, at: index + 1)
        case .below:
            subviews.insert(view, at: index)
        case .out:
            subviews.append(view)
        }
    }
}

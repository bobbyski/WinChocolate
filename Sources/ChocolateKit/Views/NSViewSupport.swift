extension NSView {
    func winNSViewRealizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if let nativeHandle {
            return nativeHandle
        }

        let handle = createNativePeer(in: backend, parent: parent)
        nativeHandle = handle
        realizedBackend = backend
        // Diagnostics only, and only for a backend that asks. A backend sees
        // coarse kinds — "textField" covers NSTextField, NSSearchField and
        // NSTokenField alike, and a framework-drawn control creates a plain
        // view — so a backend that has to name what it could not render has no
        // way to know. This is the one place every realized view passes
        // through. `wantsDebugClassNames` is false by default, so Win32, GTK
        // and the recorder do not even pay for the string.
        if backend.wantsDebugClassNames {
            backend.setDebugClassName(String(describing: type(of: self)), for: handle)
        }
        backend.setHidden(isHidden, for: handle)
        // Before any child is placed: a backend that positions children from
        // AppKit frames has to know which edge `origin.y` is measured from.
        backend.setViewFlipped(isFlipped, for: handle)
        backend.setBackgroundColor(winBackgroundColor, for: handle)
        backend.setToolTip(toolTip, for: handle)
        // Replay an explicit accessibility label set before realization so the
        // backend's accessibility annotation matches, regardless of order.
        if let storedAccessibilityLabel {
            backend.setAccessibilityName(storedAccessibilityLabel, for: handle)
        }
        winRegisterNativeInputActions(backend: backend, handle: handle)
        installDropTargetIfRealized()
        // AppKit calls updateTrackingAreas once a view joins a window; do the
        // same so views that install tracking areas there start receiving
        // mouseEntered/mouseExited.
        updateTrackingAreas()
        updateCursorRegions()

        for subview in subviews {
            subview.realizeNativePeer(in: backend, parent: handle)
        }

        return handle
    }

    func winRegisterNativeInputActions(backend: NativeControlBackend, handle: NativeHandle) {
        backend.registerMouseDownAction(for: handle) { [weak self] event in
            _ = self?.window?.makeFirstResponder(self)
            self?.mouseDown(with: event)
        }
        backend.registerMouseUpAction(for: handle) { [weak self] event in self?.mouseUp(with: event) }
        backend.registerMouseMovedAction(for: handle) { [weak self] event in
            self?.resolveTrackingAreas(with: event)
            self?.mouseMoved(with: event)
        }
        backend.registerMouseLeftAction(for: handle) { [weak self] in self?.exitAllTrackingAreas() }
        backend.registerMouseDraggedAction(for: handle) { [weak self] event in self?.mouseDragged(with: event) }
        backend.registerKeyDownAction(for: handle) { [weak self] event in self?.keyDown(with: event) }
        backend.registerKeyUpAction(for: handle) { [weak self] event in self?.keyUp(with: event) }
        backend.registerRightMouseDownAction(for: handle) { [weak self] event in self?.rightMouseDown(with: event) }
        backend.registerRightMouseUpAction(for: handle) { [weak self] event in self?.rightMouseUp(with: event) }
        backend.registerOtherMouseDownAction(for: handle) { [weak self] event in self?.otherMouseDown(with: event) }
        backend.registerOtherMouseUpAction(for: handle) { [weak self] event in self?.otherMouseUp(with: event) }
        backend.registerScrollWheelAction(for: handle) { [weak self] event in self?.scrollWheel(with: event) }
        backend.registerDrawAction(for: handle) { [weak self] nativeContext, dirtyRect in
            guard let self else { return }
            self.needsDisplay = false
            NSGraphicsContext(nativeContext: nativeContext).asCurrent {
                NSAppearance.winWithCurrentDrawing(self.effectiveAppearance) {
                    self.draw(dirtyRect)
                }
            }
        }
    }

    func isTrackingActive(_ area: NSTrackingArea) -> Bool {
        if area.options.contains(.activeAlways) {
            return true
        }
        if area.options.contains(.activeInKeyWindow) {
            return window?.isKeyWindow ?? false
        }
        // Areas created without an activity option track like key-window ones.
        return window?.isKeyWindow ?? true
    }

    func resolveTrackingAreas(with event: NSEvent) {
        guard !trackingAreas.isEmpty else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        for area in trackingAreas where area.options.contains(.mouseMoved) {
            let region = area.options.contains(.inVisibleRect) ? bounds : area.rect
            if isTrackingActive(area), region.contains(point) {
                trackingResponder(for: area)?.mouseMoved(with: event)
            }
        }
        for area in trackingAreas where area.options.contains(.mouseEnteredAndExited) {
            let identity = ObjectIdentifier(area)
            let region = area.options.contains(.inVisibleRect) ? bounds : area.rect
            let inside = isTrackingActive(area) && region.contains(point)
            let wasInside = hoveredTrackingAreas.contains(identity)
            if inside && !wasInside {
                hoveredTrackingAreas.insert(identity)
                trackingResponder(for: area)?.mouseEntered(with: NSEvent(type: .mouseEntered, locationInWindow: event.locationInWindow, modifierFlags: event.modifierFlags))
            } else if !inside && wasInside {
                hoveredTrackingAreas.remove(identity)
                trackingResponder(for: area)?.mouseExited(with: NSEvent(type: .mouseExited, locationInWindow: event.locationInWindow, modifierFlags: event.modifierFlags))
            }
        }
    }

    func exitAllTrackingAreas() {
        guard !hoveredTrackingAreas.isEmpty else {
            return
        }

        for area in trackingAreas where hoveredTrackingAreas.contains(ObjectIdentifier(area)) {
            hoveredTrackingAreas.remove(ObjectIdentifier(area))
            trackingResponder(for: area)?.mouseExited(with: NSEvent(type: .mouseExited, locationInWindow: NSPoint(x: -1, y: -1)))
        }
    }

    func trackingResponder(for area: NSTrackingArea) -> NSResponder? {
        (area.owner as? NSResponder) ?? self
    }

    func autoresizeSubviews(from oldSize: NSSize, to newSize: NSSize) {
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

    internal func updateCursorRegions() {
        let regions = winResolvedCursorRegions()
        guard let nativeHandle, let realizedBackend else {
            return
        }

        realizedBackend.setCursorRegions(regions, for: nativeHandle)
    }

    func convertPointToWindow(_ point: NSPoint) -> NSPoint {
        var converted = point
        var current: NSView? = self

        while let view = current {
            converted.x += view.frame.origin.x
            converted.y += view.frame.origin.y
            current = view.superview
        }

        return converted
    }

    func convertPointFromWindow(_ point: NSPoint) -> NSPoint {
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

    func insertSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
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

    func winRightMouseDown(with event: NSEvent) {
        if let menu {
            _ = menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
            return
        }
        super.rightMouseDown(with: event)
    }

    func winMouseDown(with event: NSEvent) {
        for recognizer in winGestureRecognizers {
            recognizer.mouseDown(with: event)
        }
        super.mouseDown(with: event)
    }

    func winMouseDragged(with event: NSEvent) {
        for recognizer in winGestureRecognizers {
            recognizer.mouseDragged(with: event)
        }
        super.mouseDragged(with: event)
    }

    func winMouseUp(with event: NSEvent) {
        for recognizer in winGestureRecognizers {
            recognizer.mouseUp(with: event)
        }
        super.mouseUp(with: event)
    }

    func winAddSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
        view.removeFromSuperview()
        view.superview = self
        view.nextResponder = self
        insertSubview(view, positioned: place, relativeTo: otherView)

        // **A subtree joining a window is when its deferred marks come due.**
        // `needsLayout` only schedules a pass for a view that is already in a
        // window, and a view hierarchy is always built the other way round:
        // frames are set, children are added, and only then is the whole thing
        // hung off a window. Without this the marks sit there forever, and the
        // symptom is a native box of the right size with nothing laid out
        // inside it — a split view with its divider in the right place and two
        // empty panes.
        //
        // It matters just as much *after* first display: a page swapped into a
        // content pane is a fresh subtree meeting an existing window, which is
        // the same moment arriving again.
        if let window {
            NSLayoutPump.shared.scheduleLayout(for: window)
        }

        guard let realizedBackend, let nativeHandle else {
            return
        }

        view.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
    }

    func winReplaceSubview(_ oldView: NSView, with newView: NSView) {
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

        // A replacement is a new subtree meeting the window, same as an add.
        if let window {
            NSLayoutPump.shared.scheduleLayout(for: window)
        }

        guard let realizedBackend, let nativeHandle else {
            return
        }

        newView.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
    }

    func winRemoveFromSuperview() {
        guard let superview else {
            return
        }

        superview.subviews.removeAll { $0 === self }
        self.superview = nil
        self.nextResponder = nil
        destroyNativePeer()
    }

    func winIsDescendant(of view: NSView) -> Bool {
        var current = superview
        while let candidate = current {
            if candidate === view {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    func winViewWithTag(_ tag: Int) -> NSView? {
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

    func winHitTest(_ point: NSPoint) -> NSView? {
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

    func winScrollToVisible(_ rect: NSRect) -> Bool {
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

    func winPerformKeyEquivalent(with event: NSEvent) -> Bool {
        for subview in subviews where !subview.isHidden {
            if subview.performKeyEquivalent(with: event) {
                return true
            }
        }
        return false
    }

    func winDestroyNativePeer() {
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
}

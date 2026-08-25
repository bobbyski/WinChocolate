extension NSWindow {

    internal func winPresentSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)?) {
        let sheetSize = sheetWindow.frame.size
        sheetWindow.setFrame(NSRect(origin: winSheetOrigin(for: sheetSize), size: sheetSize), display: true)
        attachedSheet = sheetWindow
        sheetWindow.sheetParent = self
        let response = NSApplication.shared.runModal(for: sheetWindow)
        handler?(response)
    }


    /// Pushes the effective caption text to the native window, honoring
    /// `titleVisibility`.
    internal func applyTitleVisibility() {
        guard let nativeHandle else {
            return
        }

        // The subtitle rides along with the title: AppKit draws it as a second,
        // dimmer run inside the same caption, and a native title bar with one
        // caption shows the same two pieces of information joined.
        let caption = subtitle.isEmpty ? title : "\(title) — \(subtitle)"
        nativeBackend.setText(titleVisibility == .hidden ? "" : caption, for: nativeHandle)
    }


    /// Reflects the standard-button proxies' `isHidden` onto the native caption.
    internal func applyStandardButtonVisibility() {
        guard let nativeHandle else {
            return
        }

        nativeBackend.setWindowButtonsHidden(
            closeHidden: standardButtons[.closeButton]?.isHidden ?? false,
            minimizeHidden: standardButtons[.miniaturizeButton]?.isHidden ?? false,
            zoomHidden: standardButtons[.zoomButton]?.isHidden ?? false,
            for: nativeHandle
        )
    }


    internal func applyMovableByWindowBackground() {
        guard let contentHandle = contentView?.nativeHandle else {
            return
        }

        nativeBackend.setViewDragsParentWindow(isMovableByWindowBackground, for: contentHandle)
    }


    internal func applySizeLimits() {
        guard let nativeHandle else {
            return
        }

        func positive(_ size: NSSize) -> NSSize? {
            (size.width > 0 || size.height > 0) ? size : nil
        }

        nativeBackend.setWindowContentSizeLimits(
            minSize: positive(contentMinSize) ?? positive(minSize),
            maxSize: positive(contentMaxSize) ?? positive(maxSize),
            for: nativeHandle
        )
    }


    internal func nativeWindowDidClose() {
        // The title-bar close arrives here, not through `close()`, so the modal
        // session has to be ended on this path too. `NSApplication` makes the
        // call idempotent, so a programmatic `close()` that also triggers this
        // callback cannot stop the session twice.
        NSApplication.shared.windowWillClose(self)
        toolbarHostView?.destroyNativePeer()
        toolbarHostView = nil
        contentView?.destroyNativePeer()
        nativeHandle = nil
        NSApplication.shared.removeWindowsItem(self)
        delegate?.windowWillClose(Notification(name: Notification.Name("NSWindowWillCloseNotification"), object: self))
    }


    internal func nativeWindowDidResize(to size: NSSize) {
        frame = NSRect(origin: frame.origin, size: size)
        layoutToolbarAndContent()
        // Run the layout pass synchronously so live resize tracks the new
        // size instead of waiting for the next pump tick.
        contentView?.layoutSubtreeIfNeeded()
        delegate?.windowDidResize(Notification(name: Notification.Name("NSWindowDidResizeNotification"), object: self))
    }


    internal func nativeWindowDidMove(to origin: NSPoint) {
        // Track the native origin without pushing it back to the backend.
        frame.origin = origin
        delegate?.windowDidMove(Notification(name: Notification.Name("NSWindowDidMoveNotification"), object: self))
    }


    internal func intersectionArea(of rect: NSRect) -> CGFloat {
        let overlap = frame.intersection(rect)
        return overlap.width * overlap.height
    }


    internal func layoutToolbarAndContent() {
        syncAutomaticToolbarHeight()

        if let toolbarHostView {
            toolbarHostView.frame = NSMakeRect(0, 0, frame.size.width, resolvedToolbarHeight)
            if let handle = toolbarHostView.nativeHandle {
                nativeBackend.setFrame(toolbarHostView.frame, for: handle)
                toolbarHostView.reloadItems()
            }
        }

        guard let contentView else {
            return
        }

        contentView.frame = contentLayoutRect
        if let handle = contentView.nativeHandle {
            nativeBackend.setFrame(contentView.frame, for: handle)
        }
    }


    internal var resolvedToolbarHeight: CGFloat {
        if usesAutomaticToolbarHeight {
            return NSToolbarView.preferredHeight(for: toolbar)
        }

        return toolbarHeight
    }


    internal func syncAutomaticToolbarHeight() {
        guard usesAutomaticToolbarHeight else {
            return
        }

        let preferredHeight = NSToolbarView.preferredHeight(for: toolbar)
        guard toolbarHeight != preferredHeight else {
            return
        }

        isUpdatingToolbarHeight = true
        toolbarHeight = preferredHeight
        isUpdatingToolbarHeight = false
    }


    internal func nextKeyView(after responder: NSResponder?) -> NSView? {
        if let view = responder as? NSView, let nextKeyView = firstFocusableNextKeyView(startingAt: view.winEffectiveNextKeyView) {
            return nextKeyView
        }

        return firstFocusableView(startingAt: contentView)
    }


    internal func previousKeyView(before responder: NSResponder?) -> NSView? {
        if let view = responder as? NSView, let previousKeyView = firstFocusablePreviousKeyView(startingAt: view.previousKeyView) {
            return previousKeyView
        }

        return lastFocusableView(in: contentView)
    }


    internal func firstFocusableNextKeyView(startingAt view: NSView?) -> NSView? {
        var visited: Set<ObjectIdentifier> = []
        var current = view

        while let candidate = current {
            let identifier = ObjectIdentifier(candidate)
            guard !visited.contains(identifier) else {
                return nil
            }

            visited.insert(identifier)

            if candidate.acceptsFirstResponder && !isHiddenInHierarchy(candidate) {
                return candidate
            }

            if candidate.winShouldDescendInKeyLoop, let focusableChild = firstFocusableView(startingAt: candidate) {
                return focusableChild
            }

            current = candidate.winEffectiveNextKeyView
        }

        return nil
    }


    internal func firstFocusablePreviousKeyView(startingAt view: NSView?) -> NSView? {
        var visited: Set<ObjectIdentifier> = []
        var current = view

        while let candidate = current {
            let identifier = ObjectIdentifier(candidate)
            guard !visited.contains(identifier) else {
                return nil
            }

            visited.insert(identifier)

            if candidate.acceptsFirstResponder && !isHiddenInHierarchy(candidate) {
                return candidate
            }

            if candidate.winShouldDescendInKeyLoop, let focusableChild = lastFocusableView(in: candidate) {
                return focusableChild
            }

            current = candidate.previousKeyView
        }

        return nil
    }


    internal func firstFocusableView(startingAt view: NSView?) -> NSView? {
        guard let view else {
            return nil
        }

        if isHiddenInHierarchy(view) {
            return nil
        }

        if view.acceptsFirstResponder {
            return view
        }

        for subview in view.subviews {
            if let focusable = firstFocusableView(startingAt: subview) {
                return focusable
            }
        }

        return nil
    }


    internal func lastFocusableView(in view: NSView?) -> NSView? {
        guard let view else {
            return nil
        }

        if isHiddenInHierarchy(view) {
            return nil
        }

        for subview in view.subviews.reversed() {
            if let focusable = lastFocusableView(in: subview) {
                return focusable
            }
        }

        return view.acceptsFirstResponder ? view : nil
    }


    internal func isHiddenInHierarchy(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let candidate = current {
            if candidate.isHidden {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    func winMakeFirstResponder(_ responder: NSResponder?) -> Bool {
        if responder === firstResponder {
            return true
        }

        if let firstResponder, !firstResponder.resignFirstResponder() {
            return false
        }

        guard let responder else {
            firstResponder = nil
            return true
        }

        guard responder.becomeFirstResponder() else {
            return false
        }

        firstResponder = responder

        if let view = responder as? NSView, let nativeHandle = view.nativeHandle {
            view.realizedBackend?.focusControl(nativeHandle)
        }

        return true
    }

    func winRealizeNativePeer() -> NativeHandle {
        if let nativeHandle {
            return nativeHandle
        }

        let handle = nativeBackend.createWindow(title: title, frame: frame, styleMask: styleMask, usesMainMenu: usesMainMenu)
        nativeHandle = handle
        nativeBackend.registerWindowCloseAction(for: handle) { [weak self] in
            self?.nativeWindowDidClose()
        }
        nativeBackend.registerWindowShouldCloseHandler(for: handle) { [weak self] in
            guard let self else {
                return true
            }
            return self.delegate?.windowShouldClose(self) ?? true
        }
        nativeBackend.registerWindowResizeAction(for: handle) { [weak self] size in
            self?.nativeWindowDidResize(to: size)
        }
        nativeBackend.registerWindowMoveAction(for: handle) { [weak self] origin in
            self?.nativeWindowDidMove(to: origin)
        }
        if level != .normal {
            nativeBackend.setWindowLevel(level, for: handle)
        }
        applySizeLimits()
        NSApplication.shared.addWindowsItem(self)
        applyTitleVisibility()
        applyStandardButtonVisibility()
        installToolbarHost()
        layoutToolbarAndContent()
        contentView?.realizeNativePeer(in: nativeBackend, parent: handle)
        if isMovableByWindowBackground {
            applyMovableByWindowBackground()
        }
        return handle
    }

    func winStandardWindowButton(_ type: ButtonType) -> NSButton? {
        guard styleMask.contains(.titled) else {
            return nil
        }

        if let existing = standardButtons[type] {
            return existing
        }

        let button = StandardWindowButtonProxy(frame: NSMakeRect(0, 0, 14, 14))
        switch type {
        case .closeButton:
            button.title = "Close"
        case .miniaturizeButton:
            button.title = "Minimize"
        case .zoomButton:
            button.title = "Zoom"
        case .toolbarButton:
            button.title = "Toolbar"
        case .documentIconButton:
            button.title = ""
        }
        // Hiding a caption button (close/minimize/zoom) reflects onto the
        // native title bar.
        button.onVisibilityChanged = { [weak self] in
            self?.applyStandardButtonVisibility()
        }
        standardButtons[type] = button
        return button
    }

    func winToggleFullScreen(_ sender: Any?) {
        guard !collectionBehavior.contains(.fullScreenNone) else {
            return
        }

        let handle = realizeNativePeer()
        let entering = !winIsFullScreen
        let willName = entering ? "NSWindowWillEnterFullScreenNotification" : "NSWindowWillExitFullScreenNotification"
        let didName = entering ? "NSWindowDidEnterFullScreenNotification" : "NSWindowDidExitFullScreenNotification"

        if entering {
            delegate?.windowWillEnterFullScreen(Notification(name: Notification.Name(willName), object: self))
        } else {
            delegate?.windowWillExitFullScreen(Notification(name: Notification.Name(willName), object: self))
        }

        winIsFullScreen = entering
        nativeBackend.setWindowFullScreen(entering, for: handle)
        // The toolbar/content re-layout for the new frame (the toolbar remains
        // the top strip — no title-bar merge on Windows).
        layoutToolbarAndContent()

        if entering {
            delegate?.windowDidEnterFullScreen(Notification(name: Notification.Name(didName), object: self))
        } else {
            delegate?.windowDidExitFullScreen(Notification(name: Notification.Name(didName), object: self))
        }
    }

    func winEndSheet(_ sheetWindow: NSWindow, returnCode: NSApplication.ModalResponse = .OK) {
        NSApplication.shared.stopModal(withCode: returnCode)
        sheetWindow.close()
        if attachedSheet === sheetWindow {
            attachedSheet = nil
        }
        sheetWindow.sheetParent = nil
        if !winQueuedSheets.isEmpty {
            let (next, handler) = winQueuedSheets.removeFirst()
            winPresentSheet(next, completionHandler: handler)
        }
    }

    func winClose() {
        guard let nativeHandle else {
            return
        }

        // A modal window closed from its title bar ends its session, so
        // `runModal(for:)` callers unwind instead of leaking a nested loop.
        NSApplication.shared.windowWillClose(self)
        nativeBackend.closeWindow(nativeHandle)
        toolbarHostView?.destroyNativePeer()
        toolbarHostView = nil
        contentView?.destroyNativePeer()
        self.nativeHandle = nil
        NSApplication.shared.removeWindowsItem(self)
    }

    func winCenter() {
        let workArea = nativeBackend.screenDescriptions().first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let origin = NSPoint(
            x: NSMidX(workArea) - frame.size.width / 2,
            y: NSMidY(workArea) - frame.size.height / 2
        )
        setFrame(NSRect(origin: origin, size: frame.size), display: true)
    }
}

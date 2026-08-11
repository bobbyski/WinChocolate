#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {

    // MARK: Event registration

    /// Converts a point in `handle`'s own GTK space (top-left) to the AppKit
    /// `locationInWindow` the core expects (window space, bottom-left).
    ///
    /// The core hit-tests with it — `NSSegmentedControl.mouseDown` computes
    /// `event.locationInWindow.x - frameInWindow().origin.x` to find the
    /// segment. Handing it a view-local point made that difference negative, no
    /// segment matched, and the control did nothing at all.
    internal func windowPoint(x: Double, y: Double, in handle: NativeHandle) -> NSPoint {
        guard let w = widget(handle), let root = gtk_widget_get_root(asWidget(w)) else {
            return NSPoint(x: CGFloat(x), y: CGFloat(y))
        }
        let rootWidget = UnsafeMutablePointer<GtkWidget>(root)
        var local = graphene_point_t(x: Float(x), y: Float(y))
        var inWindow = graphene_point_t(x: 0, y: 0)
        guard gtk_widget_compute_point(asWidget(w), rootWidget, &local, &inWindow) != 0 else {
            return NSPoint(x: CGFloat(x), y: CGFloat(y))
        }
        // AppKit measures the window from its BOTTOM-left.
        let height = Double(gtk_widget_get_height(rootWidget))
        return NSPoint(x: CGFloat(inWindow.x), y: CGFloat(height - Double(inWindow.y)))
    }

    /// Installs the one GTK mouse handler that fans out to the core's
    /// per-event callbacks, the first time any of them is registered.
    internal func ensureMouseHandler(for handle: NativeHandle) {
        let raw = handle.rawValue
        guard !coreSeam.mouseInstalled.contains(raw) else { return }
        coreSeam.mouseInstalled.insert(raw)
        setMouseHandler(for: handle) { [weak self] event in
            guard let self, let actions = self.coreSeam.mouse[raw] else { return }
            switch event {
            case let .down(x, y, clickCount, rightButton):
                let event = NSEvent(type: rightButton ? .rightMouseDown : .leftMouseDown,
                                    locationInWindow: self.windowPoint(x: x, y: y, in: handle),
                                    clickCount: clickCount)
                if rightButton { actions.rightDown?(event) } else { actions.down?(event) }
            case let .entered(x, y):
                actions.moved?(NSEvent(type: .mouseMoved,
                                       locationInWindow: self.windowPoint(x: x, y: y, in: handle)))
            case .exited:
                actions.left?()
            case let .scroll(deltaX, deltaY):
                actions.scroll?(NSEvent(type: .mouseMoved, locationInWindow: .zero,
                                        scrollingDeltaX: CGFloat(deltaX),
                                        scrollingDeltaY: CGFloat(deltaY)))
            }
        }
    }

    /// Registers a left mouse-down handler.
    public func registerMouseDownAction(for handle: NativeHandle,
                                        action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].down = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a left mouse-up handler.
    ///
    /// GTK's mouse seam above reports press, enter, leave, and scroll — a
    /// release is not among them, so this is recorded and will start firing
    /// when that seam grows a release event.
    public func registerMouseUpAction(for handle: NativeHandle,
                                      action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].up = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a mouse-moved handler (GTK's pointer-enter motion).
    public func registerMouseMovedAction(for handle: NativeHandle,
                                         action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].moved = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a drag handler. See `registerMouseUpAction` for why this does
    /// not fire yet.
    public func registerMouseDraggedAction(for handle: NativeHandle,
                                           action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].dragged = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a pointer-exit handler.
    public func registerMouseLeftAction(for handle: NativeHandle, action: @escaping () -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].left = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a right mouse-down handler.
    public func registerRightMouseDownAction(for handle: NativeHandle,
                                             action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].rightDown = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a right mouse-up handler.
    public func registerRightMouseUpAction(for handle: NativeHandle,
                                           action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].rightUp = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a middle mouse-down handler.
    public func registerOtherMouseDownAction(for handle: NativeHandle,
                                             action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].otherDown = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a middle mouse-up handler.
    public func registerOtherMouseUpAction(for handle: NativeHandle,
                                           action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].otherUp = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a scroll-wheel handler.
    public func registerScrollWheelAction(for handle: NativeHandle,
                                          action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].scroll = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a text-change handler.
    public func registerTextChangeAction(for handle: NativeHandle,
                                         action: @escaping (String) -> Void) {
        setTextChangeAction(for: handle, action: action)
    }

    /// Registers a cell-commit handler.
    public func registerTableEditAction(for handle: NativeHandle,
                                        action: @escaping (Int, Int, String) -> Void) {
        setTableCellCommitAction(for: handle, action)
    }

    /// Registers a window-resize handler.
    public func registerWindowResizeAction(for handle: NativeHandle,
                                           action: @escaping (NSSize) -> Void) {
        setWindowResizeAction(for: handle) { width, height in
            action(NSSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }

    /// Registers a window-move handler. X11 delivers configure events for
    /// position, but GDK4 surfaces no toplevel position to report, by design —
    /// clients are not told where the compositor put them.
    public func registerWindowMoveAction(for handle: NativeHandle,
                                         action: @escaping (NSPoint) -> Void) {}

    /// Registers a should-close handler.
    public func registerWindowShouldCloseHandler(for handle: NativeHandle,
                                                 handler: @escaping () -> Bool) {
        windowShouldCloseHandlers[handle.rawValue] = handler
    }

    /// Registers a focus-change handler.
    public func registerFocusChangeAction(for handle: NativeHandle,
                                          action: @escaping (Bool) -> Void) {}

    /// Registers a key-down handler.
    public func registerKeyDownAction(for handle: NativeHandle,
                                      action: @escaping (NSEvent) -> Void) {}

    /// Registers a key-up handler.
    public func registerKeyUpAction(for handle: NativeHandle,
                                    action: @escaping (NSEvent) -> Void) {}

    /// Registers the app-wide key-equivalent handler. Menu accelerators are
    /// installed with the menu bar on GTK, so this is not consulted.
    public func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {}

    /// Registers a toolbar-item handler.
    public func registerToolbarAction(for handle: NativeHandle,
                                      action: @escaping (String) -> Void) {
        coreSeam.toolbarActions[handle.rawValue] = action
    }

    /// Registers a drawing handler, bridging the core's path-batch context onto
    /// GTK's immediate-mode Cairo one.
    public func registerDrawAction(for handle: NativeHandle,
                                   action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        coreSeam.topLeftDrawing.insert(handle.rawValue)
        setDrawHandler(for: handle) { context, width, height in
            action(GTKCoreDrawingContext(context),
                   NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
    }

    /// Registers a drop target.
    public func registerDropTarget(for handle: NativeHandle, handler: NativeDropHandler) {
        registerDropTarget(for: handle, types: ["text/plain"]) { text, x, y in
            handler.performed(NativeDropContent(text: text, filePaths: []),
                              NSPoint(x: x, y: y))
        }
    }

    /// Removes a drop target.
    public func unregisterDropTarget(for handle: NativeHandle) {}

    /// Starts a drag from a view. GTK drags begin from a drag-source gesture on
    /// the widget rather than from a programmatic call, so the content offered
    /// by `registerDragSource` is what leaves the view.
    public func performDrag(content: NativeDropContent, from handle: NativeHandle) -> Bool { false }

    // MARK: Toolbar

    /// Installs the toolbar's items on its window.
    public func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle) {
        coreSeam.toolbarItems[handle.rawValue] = items
        guard let window = coreSeam.toolbarWindow[handle.rawValue] else { return }
        let action = coreSeam.toolbarActions[handle.rawValue]
        let specs = items.map { item in
            NativeToolbarItemSpec(identifier: item.identifier,
                                  label: item.label,
                                  iconName: item.imageName,
                                  isFlexibleSpace: item.isFlexibleSpace,
                                  action: { action?(item.identifier) })
        }
        installToolbar(specs, on: window)
    }

    /// The on-screen frame of a toolbar item. GTK's header bar owns its own
    /// layout and reports no per-child geometry before it is mapped.
    public func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect? { nil }

    // MARK: Menus and dialogs

    /// Installs the application menu bar on the frontmost window.
    public func installMainMenu(_ menu: NSMenu?) {
        guard let menu else { return }
        let specs = menu.items.map { top in
            NativeMenuSpec(title: top.title,
                           items: (top.submenu?.items ?? []).map { item in
                               NativeMenuItemSpec(title: item.title,
                                                  isSeparator: item.isSeparatorItem,
                                                  accelerator: nil,
                                                  action: { _ = item.performAction() })
                           })
        }
        // `NSApplication.mainMenu` is usually set during launch, before the
        // first window is created — and GTK installs a menu bar ON a window.
        // Hold it until there is one rather than dropping it.
        guard let window = firstWindowHandle() else {
            coreSeam.pendingMainMenu = specs
            return
        }
        installMenuBar(specs, on: window)
    }

    /// Installs a menu bar that arrived before any window existed.
    func installPendingMainMenu(on window: NativeHandle) {
        guard let specs = coreSeam.pendingMainMenu else { return }
        coreSeam.pendingMainMenu = nil
        installMenuBar(specs, on: window)
    }

    /// The first window created, which is the one menus and modals attach to.
    internal func firstWindowHandle() -> NativeHandle? {
        kinds.filter { $0.value == .window }.keys.min().map { NativeHandle(rawValue: $0) }
    }

    /// Runs an alert modally.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let titles = alert.buttons.isEmpty ? ["OK"] : alert.buttons.map(\.title)
        let index = runAlert(message: alert.messageText, informative: alert.informativeText,
                             buttons: titles, for: firstWindowHandle())
        return NSApplication.ModalResponse(rawValue: 1000 + index)
    }

    /// Runs an open or save dialog.
    public func runFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        let window = firstWindowHandle()
        switch options.kind {
        case .open:
            return runOpenPanel(directory: options.directoryPath, for: window).map { [$0] }
        case .save:
            return runSavePanel(directory: options.directoryPath,
                                suggestedName: options.fileName, for: window).map { [$0] }
        }
    }

    /// Runs a context menu at a screen point and returns the chosen item.
    ///
    /// GTK popover menus are asynchronous — they hand control back immediately
    /// and report the choice through the item's own action — so there is no
    /// selection to return synchronously here.
    public func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? { nil }

    /// Runs the font panel. GTK4.6's font chooser is available, but the core's
    /// `NSFont` carries a family/size/weight triple that the dialog's Pango
    /// description does not round-trip cleanly, so the panel is not shown.
    public func runFontChooser(initialFont: NSFont?) -> NSFont? { nil }

    /// Runs a modal event loop for a window.
    public func runModal(for handle: NativeHandle) -> Int {
        showWindow(handle)
        let loop = g_main_loop_new(nil, gboolean(0))
        pushNestedLoop(loop)
        g_main_loop_run(loop)
        popNestedLoop()
        return coreSeam.modalCode
    }

    /// Ends the innermost modal loop.
    public func stopModal(withCode code: Int) {
        coreSeam.modalCode = code
        guard let loop = nestedLoops.last else { return }
        guard stoppingNestedLoops.insert(loop).inserted else { return }
        let box = DeferredLoopQuitBox(loop: loop)
        g_idle_add({ userData in
            guard let userData else { return gboolean(0) }
            let box = Unmanaged<DeferredLoopQuitBox>
                .fromOpaque(userData).takeRetainedValue()
            g_main_loop_quit(box.loop)
            return gboolean(0)
        }, Unmanaged.passRetained(box).toOpaque())
    }

    /// Prints a view.
    public func runPrintOperation(for handle: NativeHandle, jobName: String,
                                  contentSize: NSSize) -> Bool {
        runPrintOperation(view: handle, jobTitle: jobName, parent: firstWindowHandle())
    }

    /// Dismisses a popover on the next click outside it. GTK popovers close
    /// themselves on an outside click, so no extra grab is needed.
    public func beginOutsideClickDismiss(for handle: NativeHandle,
                                         onDismiss: @escaping () -> Void) {}

    /// Ends outside-click dismissal.
    public func endOutsideClickDismiss() {}

}

#endif

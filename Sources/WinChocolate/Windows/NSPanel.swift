/// A panel-style top-level window.
///
/// Panels keep AppKit's auxiliary-window contract: they can float above the
/// application's normal windows, never become the main window, and can hide
/// while the application is inactive. The classic backend realizes floating
/// panels as topmost tool windows without a taskbar presence.
open class NSPanel: NSWindow {
    /// Whether the panel floats above normal document windows.
    open var isFloatingPanel: Bool = false {
        didSet {
            level = isFloatingPanel ? .floating : .normal
        }
    }

    /// Whether the panel hides when the application deactivates.
    open var hidesOnDeactivate: Bool = false {
        didSet {
            guard let nativeHandle else {
                return
            }

            nativeBackend.setHidesOnDeactivate(hidesOnDeactivate, for: nativeHandle)
        }
    }

    /// Whether the panel should become key only when a child view needs focus.
    open var becomesKeyOnlyIfNeeded: Bool = false

    /// Whether the panel accepts interaction while a modal session is active.
    open var worksWhenModal: Bool = false

    /// Panels do not own the application menu bar.
    open override var usesMainMenu: Bool {
        false
    }

    /// Panels never become the application's main window.
    open override var canBecomeMain: Bool {
        false
    }

    /// A `becomesKeyOnlyIfNeeded` panel becomes key only when it hosts an
    /// editable view that needs first-responder status.
    open override var canBecomeKey: Bool {
        guard becomesKeyOnlyIfNeeded else {
            return true
        }

        return contentView.map { NSPanel.containsEditableView($0) } ?? false
    }

    /// Whether a view tree contains an editable text control.
    private static func containsEditableView(_ view: NSView) -> Bool {
        if let field = view as? NSTextField, field.isEditable {
            return true
        }
        if let textView = view as? NSTextView, textView.isEditable {
            return true
        }
        return view.subviews.contains { containsEditableView($0) }
    }

    /// Creates a panel using AppKit's designated initializer shape.
    public override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    /// Creates a panel using an explicit backend.
    public override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        nativeBackend: NativeControlBackend
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag, nativeBackend: nativeBackend)
    }

    /// Realizes the panel peer and applies panel-only window state.
    @discardableResult
    open override func realizeNativePeer() -> NativeHandle {
        let wasRealized = nativeHandle != nil
        let handle = super.realizeNativePeer()
        if !wasRealized && hidesOnDeactivate {
            nativeBackend.setHidesOnDeactivate(true, for: handle)
        }
        return handle
    }

    /// Orders the panel front even when the app is not active.
    open func orderFrontRegardless() {
        let handle = realizeNativePeer()
        nativeBackend.showWindow(handle)
    }
}

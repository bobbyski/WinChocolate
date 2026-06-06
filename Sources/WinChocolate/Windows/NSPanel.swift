/// A panel-style top-level window.
///
/// This first slice preserves AppKit's `NSPanel` name and common panel state.
/// The classic backend currently creates panels through the same top-level
/// window path as `NSWindow`; richer tool-window styling can layer on later.
open class NSPanel: NSWindow {
    /// Whether the panel floats above normal document windows.
    open var isFloatingPanel: Bool = false

    /// Whether the panel hides when the application deactivates.
    open var hidesOnDeactivate: Bool = false

    /// Whether the panel should become key only when a child view needs focus.
    open var becomesKeyOnlyIfNeeded: Bool = false

    /// Whether the panel accepts interaction while a modal session is active.
    open var worksWhenModal: Bool = false

    /// Panels do not own the application menu bar.
    open override var usesMainMenu: Bool {
        false
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

    /// Orders the panel front even when the app is not active.
    open func orderFrontRegardless() {
        let handle = realizeNativePeer()
        nativeBackend.showWindow(handle)
    }
}

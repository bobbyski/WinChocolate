#if canImport(CGTK)
import CGTK
import Foundation

/// Linux backend: maps the AppKit-shaped seam onto native GTK4 widgets.
///
/// ```text
///   NSWindow             ->  GtkWindow (its child is the content view's GtkFixed)
///   NSView               ->  GtkFixed  (absolute child placement, like AppKit)
///   NSButton             ->  GtkButton
///   NSTextField (label)  ->  GtkLabel
/// ```
///
/// GTK is C/GObject. The `as*` helpers stand in for GTK's upcast macros
/// (`GTK_WINDOW()`, `GTK_BUTTON()`, …), which don't survive the C→Swift import;
/// every GObject begins with a `GTypeInstance`, so the reinterpret is safe.
///
/// The event loop uses a plain `GMainLoop` (not `GtkApplication`) so the
/// create-window-then-run ordering matches AppKit's, instead of GTK's
/// activate-callback model.
public final class GTKNativeControlBackend: NativeControlBackend {

    private var nextRaw: UInt = 1
    private var widgets: [UInt: OpaquePointer] = [:]   // handle -> GtkWidget*
    private var kinds: [UInt: InMemoryNativeControlBackend.Kind] = [:]
    private var frames: [UInt: NSRect] = [:]
    private var mainLoop: OpaquePointer?   // GMainLoop* (opaque in the GTK import)

    /// Connects to the display and initializes GTK. Only construct this when a
    /// display is available (the demo/app), never in headless tests.
    public init() {
        gtk_init()
    }

    // MARK: Handle bookkeeping
    private func allocate(_ widget: UnsafeMutablePointer<GtkWidget>, _ kind: InMemoryNativeControlBackend.Kind, frame: NSRect) -> NativeHandle {
        defer { nextRaw += 1 }
        widgets[nextRaw] = OpaquePointer(widget)
        kinds[nextRaw] = kind
        frames[nextRaw] = frame
        return NativeHandle(rawValue: nextRaw)
    }
    private func widget(_ h: NativeHandle) -> OpaquePointer? { widgets[h.rawValue] }

    // MARK: Pointer upcasts (stand-ins for GTK_*() macros)
    private func asWidget(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWidget> { .init(p) }
    private func asWindow(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWindow> { .init(p) }
    private func asFixed(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFixed> { .init(p) }
    private func asButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkButton> { .init(p) }
    // NOTE: GtkLabel and GMainLoop are opaque in the GTK4 Swift import (no
    // nominal type), so their functions take/return OpaquePointer directly.

    // MARK: Application lifecycle
    public func runApplication() {
        let loop = g_main_loop_new(nil, gboolean(0))   // OpaquePointer!
        mainLoop = loop
        g_main_loop_run(loop)
    }
    public func terminateApplication() {
        guard let loop = mainLoop else { return }
        g_main_loop_quit(loop)
    }

    // MARK: Windows
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let win = gtk_window_new()!
        let h = allocate(win, .window, frame: frame)
        let p = widget(h)!
        gtk_window_set_title(asWindow(p), title)
        gtk_window_set_default_size(asWindow(p), Int32(frame.width), Int32(frame.height))
        return h
    }
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        guard let w = widget(window), let v = widget(view) else { return }
        gtk_window_set_child(asWindow(w), asWidget(v))
    }
    public func showWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_present(asWindow(w))
    }
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_title(asWindow(w), title)
    }
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), actionBoxDestroy, GConnectFlags(rawValue: 0)
        )
    }

    // MARK: Views & controls
    public func createView(frame: NSRect) -> NativeHandle {
        allocate(gtk_fixed_new()!, .view, frame: frame)
    }
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let b = gtk_button_new_with_label(title)!
        gtk_widget_set_size_request(b, Int32(frame.width), Int32(frame.height))
        return allocate(b, .button, frame: frame)
    }
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let l = gtk_label_new(text)!
        gtk_widget_set_size_request(l, Int32(frame.width), Int32(frame.height))
        return allocate(l, .label, frame: frame)
    }
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        guard let p = widget(parent), let c = widget(child) else { return }
        let f = frames[child.rawValue] ?? .zero
        // NOTE: GTK's origin is top-left; AppKit's is bottom-left. Y-flip is a
        // Phase L4 parity item — for now frames are placed as given (top-left).
        gtk_fixed_put(asFixed(p), asWidget(c), Double(f.origin.x), Double(f.origin.y))
    }

    // MARK: Mutators
    public func setText(_ text: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .button: gtk_button_set_label(asButton(w), text)
        case .label:  gtk_label_set_text(w, text)   // takes OpaquePointer (GtkLabel*)
        case .window: gtk_window_set_title(asWindow(w), text)
        default: break
        }
    }
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        frames[handle.rawValue] = frame
        guard let w = widget(handle) else { return }
        gtk_widget_set_size_request(asWidget(w), Int32(frame.width), Int32(frame.height))
    }
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_sensitive(asWidget(w), gboolean(isEnabled ? 1 : 0))
    }
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        if kinds[r] == .window, let w = widgets[r] {
            gtk_window_destroy(asWindow(w))
        }
        widgets[r] = nil; kinds[r] = nil; frames[r] = nil
    }

    // MARK: Events
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "clicked",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), actionBoxDestroy, GConnectFlags(rawValue: 0)
        )
    }
}

// MARK: - GObject signal glue
//
// GTK signal handlers must be bare C function pointers, so the Swift closure is
// boxed and passed as `user_data`; a destroy-notify releases the box when the
// signal is disconnected. These live at file scope because @convention(c)
// closures cannot capture context.

private final class ActionBox {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}

/// Handler for `GtkButton::clicked` — `void (*)(GtkButton*, gpointer)`.
private let gtkActionTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
}

/// Handler for `GtkWindow::close-request` — returns gboolean (false = allow close).
private let gtkCloseRequestTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> gboolean = { _, userData in
    if let userData {
        Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
    }
    return gboolean(0)
}

/// Releases the boxed closure when GLib tears the signal connection down.
private let actionBoxDestroy: GClosureNotify = { data, _ in
    guard let data else { return }
    Unmanaged<ActionBox>.fromOpaque(data).release()
}
#endif

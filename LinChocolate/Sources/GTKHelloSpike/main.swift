// LinChocolate harness spike — validation spikes S1/S2 from
// Docs/LinChocolateSubstrate.md. This is NOT framework code; it exists only to
// prove the Ring 1 inner loop end to end:
//
//   S1 · Swift builds against GTK4 through C-interop.
//   S2 · The resulting window renders on the Mac via XQuartz.
//
// Run it with ../run-linux.sh (which forwards DISPLAY to XQuartz and defaults
// GSK_RENDERER=cairo, since GTK4's GL renderer is unreliable over XQuartz).

import CGTK

/// Reinterpret one GTK object pointer as another.
///
/// GTK's C API leans on macros like `GTK_WINDOW()` and `G_APPLICATION()` to
/// upcast between object structs. Those macros don't survive the C→Swift
/// import, so we reinterpret the pointer explicitly. Every GObject begins with
/// a `GTypeInstance`, so upcasting to a base type is layout-safe.
@inline(__always)
private func cast<From, To>(_ pointer: UnsafeMutablePointer<From>) -> UnsafeMutablePointer<To> {
    UnsafeMutablePointer<To>(OpaquePointer(pointer))
}

/// Builds the window when the application activates.
///
/// This must be a bare C function pointer — no captured Swift state — so it is
/// declared `@convention(c)` and handed to GLib as a `GCallback`.
private let onActivate: @convention(c) (
    UnsafeMutablePointer<GtkApplication>?, gpointer?
) -> Void = { app, _ in
    guard let app, let widget = gtk_application_window_new(app) else { return }

    let window: UnsafeMutablePointer<GtkWindow> = cast(widget)
    gtk_window_set_title(window, "Hello LinChocolate")
    gtk_window_set_default_size(window, 480, 220)

    let label = gtk_label_new("LinChocolate harness: GTK4 + Swift is alive.")
    gtk_window_set_child(window, label)

    gtk_window_present(window)
}

let app = gtk_application_new("dev.linchocolate.harness", G_APPLICATION_DEFAULT_FLAGS)
defer { g_object_unref(app) }

_ = g_signal_connect_data(
    app,                                            // instance
    "activate",
    unsafeBitCast(onActivate, to: GCallback.self),  // GTK expects a bare GCallback
    nil,                                            // user data
    nil,                                            // destroy notify
    GConnectFlags(rawValue: 0)
)

let application: UnsafeMutablePointer<GApplication> = cast(app!)
let status = g_application_run(application, 0, nil)
exit(status)

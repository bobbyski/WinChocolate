// Backend selection (Docs/RADICALLY_DIFFERENT_UI_SPIKE.md, Step 1).
//
// Which `NativeControlBackend` fronts the shared core is normally decided by
// the platform: Win32 on Windows, GTK on Linux, the browser DOM under WASI.
// The terminal backend is the exception — a terminal is available on *every*
// desktop OS, so the same binary could reasonably drive either the GUI or a
// cell grid, and nothing about the platform says which the user wanted.
//
// So there is exactly one runtime override, read exactly once, at the single
// place the backend is instantiated (`NSApplication.init`). Everything else in
// the framework stays free of backend conditionals.
//
//     CHOCOLATE_BACKEND=tui           environment variable
//     --chocolate-backend=tui         launch argument (wins over the variable)
//
// **Absence means today's behaviour, exactly.** An unset, empty, or unknown
// value selects the platform default, so an app that never heard of this
// setting behaves as it always did. An unknown value additionally warns rather
// than failing — ground rule 4, degrade visibly, never silently.

#if USE_WIN_FOUNDATION
import WinFoundation
#else
import Foundation
#endif

/// A backend the caller can ask for by name.
///
/// The GUI cases exist so a request can be *explicit* — most usefully
/// `inmemory`, which is otherwise reachable only by falling off the end of the
/// platform switch, which is how a GUI-less Linux build once shipped.
public enum ChocolateBackendRequest: String, Sendable {
    /// The Win32 backend.
    case win32
    /// The GTK backend.
    case gtk
    /// The terminal backend, driven by TUIKit.
    case tui
    /// The browser DOM backend, driven by SwiftDOM.
    case wasm
    /// The headless recording backend used by tests.
    case inmemory
}

/// Reads the caller's backend request, or `nil` for "use the platform default".
///
/// The launch argument is checked before the environment variable so a single
/// run can override an exported setting.
public func chocolateBackendRequest() -> ChocolateBackendRequest? {
    let argumentPrefix = "--chocolate-backend="
    let raw = CommandLine.arguments
        .first(where: { $0.hasPrefix(argumentPrefix) })
        .map { String($0.dropFirst(argumentPrefix.count)) }
        ?? ProcessInfo.processInfo.environment["CHOCOLATE_BACKEND"]

    guard let raw else { return nil }
    let name = raw.trimmingCharacters(in: .whitespaces).lowercased()
    guard !name.isEmpty else { return nil }

    guard let request = ChocolateBackendRequest(rawValue: name) else {
        chocolateBackendWarn("unknown backend '\(raw)' requested; using the platform default. "
                             + "Known values: win32, gtk, tui, wasm, inmemory.")
        return nil
    }
    return request
}

/// Reports a selection problem on the way to the platform default.
///
/// Selection runs before any window exists, so there is nowhere to show this
/// but the console — which is also the one place a terminal user is certain to
/// be looking.
func chocolateBackendWarn(_ message: String) {
    print("[ChocolateKit] \(message)")
}

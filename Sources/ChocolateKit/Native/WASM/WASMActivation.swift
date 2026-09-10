#if canImport(JavaScriptKit)

import JavaScriptKit

// The page's focus is this app's activation.
//
// AppKit dims accent-colored controls when the app stops being frontmost, and
// ActiveUI's drawn tier reads `NSApplication.shared.isActive` to do the same.
// A browser tab has an exact equivalent — the window's focus — so reporting it
// costs two listeners and makes a themed window in a background tab look the
// way a background window looks everywhere else.

extension WASMNativeControlBackend {

    /// Starts reporting the page's focus as the application's activation.
    ///
    /// Called once, when the backend takes over the page. Like the clipboard
    /// watcher, the closures are kept alive for the backend's lifetime — a
    /// `JSClosure` that goes out of scope stops being called, silently.
    internal func beginWatchingPageActivation() {
        guard let window = JSObject.global.window.object,
              let addEventListener = window.addEventListener.function else { return }

        for (event, active) in [("focus", true), ("blur", false)] {
            let handler = JSClosure { _ in
                MainActor.assumeIsolated {
                    NSApplication.shared.winSetActive(active)
                }
                return .undefined
            }
            activationListeners.append(handler)
            _ = addEventListener(this: window, event, handler)
        }

        // The page may already be in the background when the app starts — a
        // tab restored on launch, or one opened behind the current one. Asking
        // once means the first paint is right rather than right-after-the-
        // first-focus-change.
        if let hasFocus = JSObject.global.document.object?.hasFocus.function,
           let focused = hasFocus(this: JSObject.global.document.object!).boolean {
            MainActor.assumeIsolated {
                NSApplication.shared.winSetActive(focused)
            }
        }
    }
}

#endif

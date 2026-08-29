// The system clipboard, from a page.
//
// **The shapes do not match, and pretending they do would be the bug.**
// `NativeControlBackend`'s clipboard is synchronous — `clipboardString()`
// returns a value — because that is what `NSPasteboard` is. A browser's
// Clipboard API is asynchronous and permission-gated in both directions, and
// there is no way to await it from inside a synchronous call without
// deadlocking the one thread the page has.
//
// So the in-process clipboard stays the source of truth for reads, and this
// layer keeps it in step with the system one at the two moments a browser
// actually allows it:
//
//   * a write goes out to `navigator.clipboard.writeText` as well, so copying
//     out of the app reaches other applications;
//   * a `paste` event carries the system clipboard's text with it, so pasting
//     into the app gets what the user copied elsewhere.
//
// What is *not* possible is reading the system clipboard at an arbitrary
// moment. An app that copies in one window and pastes in another is served by
// the in-process store; an app that expects `NSPasteboard.general.string` to
// reflect a copy made in another *application*, with no paste gesture, is not
// — and cannot be, on this platform.
//
// The two overrides live in `WASMNativeControlBackend.swift`'s class body:
// Swift cannot override a class method from an extension.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// Hands text to the browser's clipboard, if it will take it.
    ///
    /// Fire and forget, and deliberately so: the write is allowed only inside a
    /// user gesture, the promise rejects when it is not, and there is nothing
    /// useful to do about that at this depth. The in-process clipboard has the
    /// text either way, so the app's own copy and paste keep working — the
    /// failure mode to prefer over taking the app down for a permission.
    internal func writeSystemClipboard(_ text: String) {
        guard let navigator = JSObject.global.navigator.object else { return }
        let clipboard = navigator.clipboard
        guard !clipboard.isNull, !clipboard.isUndefined,
              let object = clipboard.object,
              let writeText = object.writeText.function else { return }
        let promise = writeText(this: object, text)
        // A rejected promise with no handler is an unhandled rejection in the
        // console, which reads as an error the app failed to catch. It is not
        // one: refusing the clipboard is the browser working as designed.
        if let thenable = promise.object, let rejected = thenable.catch.function {
            _ = rejected(this: thenable, JSClosure { _ in .undefined })
        }
    }

    /// Starts listening for `paste`, so the in-process clipboard learns what
    /// the user copied in another application.
    ///
    /// Called once, when the backend takes over the page. The closure is kept
    /// alive for the backend's lifetime — a `JSClosure` that goes out of scope
    /// stops being called, silently.
    internal func beginWatchingSystemClipboard() {
        guard let document = JSObject.global.document.object,
              let addEventListener = document.addEventListener.function else { return }
        let handler = JSClosure { [weak self] arguments in
            guard let self, let event = arguments.first?.object else { return .undefined }
            let clipboardData = event.clipboardData
            guard let data = clipboardData.object,
                  let getData = data.getData.function,
                  let text = getData(this: data, "text/plain").string,
                  !text.isEmpty else { return .undefined }
            // Only the text: the app reads richer formats from its own store,
            // and a paste from outside carries nothing else this framework
            // understands.
            self.recordPastedText(text)
            return .undefined
        }
        clipboardListeners.append(handler)
        _ = addEventListener(this: document, "paste", handler)
    }
}

#endif

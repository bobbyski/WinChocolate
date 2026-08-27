// Remembering where a window was.
//
// AppKit's `setFrameAutosaveName` is one of those APIs that looks like a
// convenience and is really a promise: an app that sets it opens where the user
// left it, forever, on every launch. ChocolateKit had no equivalent, so every
// non-Apple build opened centred at the content size every single time.
//
// The whole feature is two lines of arithmetic and one persisted string; what
// it needed was somewhere durable to put the string, which is what
// `NativeControlBackend.persistentValue(forKey:)` now is.

import Foundation

extension NSWindow {
    /// AppKit's defaults key for an autosaved frame.
    ///
    /// The spelling is AppKit's on purpose. On a Mac this framework is not in
    /// the loop at all — real AppKit is — so a window that moves between the
    /// two reads back the same key rather than forgetting itself once.
    private static func frameKey(for name: String) -> String {
        "NSWindow Frame \(name)"
    }

    /// The autosave name, or the empty string when the window does not autosave.
    public var frameAutosaveName: String {
        winFrameAutosaveName
    }

    /// Starts autosaving this window's frame under a name, and restores the
    /// frame already saved under it.
    ///
    /// **Restores immediately**, which is what makes the one-line AppKit usage
    /// work: a window is created at its designed size, given an autosave name,
    /// and is already back where the user left it by the next statement.
    ///
    /// - Returns: `false` when another window is already autosaving under this
    ///   name — AppKit's answer, and for AppKit's reason: two windows sharing a
    ///   name would fight over one stored frame and neither would be restored
    ///   reliably.
    @discardableResult
    public func setFrameAutosaveName(_ name: String) -> Bool {
        if name.isEmpty {
            winFrameAutosaveName = ""
            return true
        }
        let taken = NSApplication.shared.windows.contains {
            $0 !== self && $0.winFrameAutosaveName == name
        }
        guard !taken else { return false }

        winFrameAutosaveName = name
        setFrameUsingName(name)
        return true
    }

    /// Writes the current frame under a name, whether or not this window
    /// autosaves.
    public func saveFrame(usingName name: String) {
        guard !name.isEmpty else { return }
        NSApplication.shared.nativeBackend.setPersistentValue(
            Self.frameString(from: frame),
            forKey: Self.frameKey(for: name)
        )
    }

    /// Restores the frame saved under a name.
    ///
    /// - Returns: `false` when nothing was saved under that name, which is
    ///   simply a first launch.
    @discardableResult
    public func setFrameUsingName(_ name: String) -> Bool {
        guard !name.isEmpty,
              let text = NSApplication.shared.nativeBackend
                  .persistentValue(forKey: Self.frameKey(for: name)),
              let saved = Self.frame(fromString: text) else {
            return false
        }

        // Restoring must not immediately re-save: the write is the same value,
        // but going through `setFrame` twice for one restore is the kind of
        // thing that turns into a loop the first time someone adds a clamp.
        winIsRestoringFrame = true
        setFrame(saved, display: true)
        winIsRestoringFrame = false
        return true
    }

    /// Called from every path that changes the frame.
    internal func winAutosaveFrameIfNeeded() {
        guard !winIsRestoringFrame, !winFrameAutosaveName.isEmpty else { return }
        saveFrame(usingName: winFrameAutosaveName)
    }

    // MARK: - AppKit's frame string

    /// AppKit's format: the window frame followed by the screen frame it was
    /// saved against, all integers, space separated.
    ///
    /// The screen half is not decoration. A frame saved on a 5K display and
    /// restored on a laptop describes a window that is entirely off-screen, and
    /// the only way to notice is to have written down what the screen was.
    private static func frameString(from rect: NSRect) -> String {
        let screen = NSApplication.shared.nativeBackend.primaryScreenFrame()
        return "\(Int(rect.origin.x)) \(Int(rect.origin.y)) "
            + "\(Int(rect.size.width)) \(Int(rect.size.height)) "
            + "\(Int(screen.origin.x)) \(Int(screen.origin.y)) "
            + "\(Int(screen.size.width)) \(Int(screen.size.height))"
    }

    /// Parses a saved frame, and refuses one that would not be usable now.
    private static func frame(fromString text: String) -> NSRect? {
        let parts = text.split(separator: " ").compactMap { Double($0) }
        guard parts.count >= 4 else { return nil }
        let saved = NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        guard saved.width > 0, saved.height > 0 else { return nil }

        // A window bigger than the current screen, or sitting past its edge, is
        // a frame from a display that is no longer attached. Dropping it puts
        // the window back at its designed size rather than somewhere the user
        // cannot reach it — which is the failure this remembers to avoid, not
        // an edge case: closing a laptop lid is how most people hit it.
        let screen = NSApplication.shared.nativeBackend.primaryScreenFrame()
        if !screen.isEmpty {
            guard saved.width <= screen.width, saved.height <= screen.height,
                  saved.origin.x >= screen.origin.x - saved.width / 2,
                  saved.origin.y >= screen.origin.y - saved.height / 2,
                  saved.origin.x < screen.maxX, saved.origin.y < screen.maxY else {
                return nil
            }
        }
        return saved
    }
}

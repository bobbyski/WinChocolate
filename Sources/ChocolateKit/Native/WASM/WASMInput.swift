// Mouse, keyboard, focus and text-change plumbing.
//
// Up to here the backend has been mostly *output*: build DOM, push frames,
// paint. This file is the other direction — turning DOM events back into the
// `NSEvent`s the responder chain expects, so a view's `mouseDown(with:)` or
// `keyDown(with:)` actually runs.
//
// Two conversions matter and are done once each:
//
//   * **Coordinates.** AppKit hands a view's mouse handlers a point in *window*
//     coordinates, not view-local ones. `getBoundingClientRect` gives the
//     element's position in the viewport, so the window's own rect is
//     subtracted to land in the window's space.
//   * **Modifiers.** A browser reports `metaKey` for Command on a Mac and for
//     the Windows key elsewhere; AppKit's `.command` is the same idea, so they
//     map directly and Control stays Control.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// The modifier flags carried by a DOM event.
    internal static func modifiers(from event: Event) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if event.rawValue.shiftKey.boolean == true { flags.insert(.shift) }
        if event.rawValue.ctrlKey.boolean == true { flags.insert(.control) }
        if event.rawValue.altKey.boolean == true { flags.insert(.option) }
        if event.rawValue.metaKey.boolean == true { flags.insert(.command) }
        return flags
    }

    /// A DOM pointer position converted into the handle's window coordinates.
    internal func windowPoint(_ event: Event, for handle: NativeHandle) -> NSPoint {
        guard let window = windowHandle(containing: handle),
              let windowElement = elements[window] else {
            return NSMakePoint(CGFloat(event.clientX), CGFloat(event.clientY))
        }

        let rect = windowElement.getBoundingClientRect()
        return NSMakePoint(CGFloat(event.clientX) - CGFloat(rect.left),
                           CGFloat(event.clientY) - CGFloat(rect.top))
    }

    /// Walks up the recorded parent chain to the window a view belongs to.
    internal func windowHandle(containing handle: NativeHandle) -> NativeHandle? {
        var current: NativeHandle? = handle
        var hops = 0
        // Bounded: a malformed parent chain must not hang the page.
        while let candidate = current, hops < 64 {
            if records[candidate]?.kind == "window" { return candidate }
            current = records[candidate]?.parent
            hops += 1
        }
        return nil
    }

    /// Builds an `NSEvent` for a pointer event on a handle.
    internal func mouseEvent(_ type: NSEvent.EventType, _ event: Event,
                             for handle: NativeHandle) -> NSEvent {
        NSEvent(type: type,
                locationInWindow: windowPoint(event, for: handle),
                modifierFlags: Self.modifiers(from: event),
                clickCount: Int(event.rawValue.detail.number ?? 1))
    }

    /// Attaches one pointer listener, keeping its token for `destroyControl`.
    internal func onPointer(_ name: EventName, _ handle: NativeHandle,
                            _ body: @escaping (Event) -> Void) {
        guard let element = elements[handle] else { return }
        listeners[handle, default: []].append(element.addEventListener(name) { body($0) })
    }

    /// Builds an `NSEvent` for a keyboard event.
    ///
    /// `event.key` is the *character* ("a", "Enter"), and `event.keyCode` is the
    /// legacy numeric code AppKit's `keyCode` most nearly corresponds to.
    internal static func keyEvent(_ type: NSEvent.EventType, _ event: Event) -> NSEvent {
        let characters = event.rawValue.key.string
        return NSEvent(type: type,
                       locationInWindow: .zero,
                       keyCode: UInt16(event.rawValue.keyCode.number ?? 0),
                       // A named key like "Enter" is not a character AppKit
                       // would deliver; only single characters are passed on.
                       characters: (characters?.count == 1) ? characters : nil,
                       modifierFlags: modifiers(from: event))
    }
}

#endif

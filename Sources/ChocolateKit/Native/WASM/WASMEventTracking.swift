// Modal event tracking, as far as a browser can honestly go
// (Docs/EVENT_TRACKING.md).
//
// AppKit's `NSWindow.trackEvents` re-enters the event loop: the call blocks,
// events are pulled out of the queue one at a time, and it returns when the
// handler says stop. **A page cannot do that.** JavaScript runs to completion
// on a single thread; a loop that waited for the next pointer event would stop
// the thread that delivers pointer events, and the tab would hang. There is no
// clever way around it — this is the execution model, not a missing API.
//
// So the browser's answer is the one the platform actually supports: the
// session is *asynchronous*. `beginEventTracking` attaches listeners, returns
// true immediately, and delivers events on later turns of the page's loop. The
// handler sees exactly the events it would have seen, in order, and gets its
// terminating `nil` — everything except the blocking.
//
// Two details make it behave like a real drag rather than a sequence of clicks:
//
//   * **Pointer capture.** Without it the drag stops the moment the pointer
//     leaves the element it started on — which for a torn-off palette is
//     immediately, because the thing being dragged moves out from under the
//     cursor. `setPointerCapture` redirects every later event for that pointer
//     to the capturing element regardless of what is underneath.
//   * **Listeners on the desktop, not the window.** The pointer routinely
//     travels outside the window being dragged; the desktop is the element that
//     spans everywhere it can go.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// One asynchronous tracking session's live state.
    ///
    /// Held as a class so the listeners, which outlive the call that made them,
    /// can end the session they belong to and not some later one.
    final class EventTrackingSession {
        let mask: NSEvent.EventTypeMask
        let handler: (NSEvent?) -> NativeEventTrackingDisposition
        var listeners: [EventListener] = []
        var pointerID: Double?
        var isFinished = false

        init(mask: NSEvent.EventTypeMask,
             handler: @escaping (NSEvent?) -> NativeEventTrackingDisposition) {
            self.mask = mask
            self.handler = handler
        }
    }

    /// Starts an asynchronous tracking session over the desktop.
    ///
    /// Returns false when there is no desktop yet — before the application has
    /// run there is nothing to attach to, and claiming the session would leave
    /// the caller waiting for events that cannot arrive.
    public func beginEventTracking(
        matching mask: NSEvent.EventTypeMask,
        for window: NativeHandle,
        handler: @escaping (NSEvent?) -> NativeEventTrackingDisposition
    ) -> Bool {
        guard let desktop else { return false }

        // One session at a time, as in AppKit: a nested loop cannot be
        // re-entered either. An existing session is ended first, so its caller
        // gets its terminating nil rather than being abandoned mid-drag.
        finishEventTracking()

        let session = EventTrackingSession(mask: mask, handler: handler)
        eventTracking = session

        session.listeners.append(desktop.addEventListener(.pointermove) { [weak self] event in
            self?.deliverTracked(.leftMouseDragged, event, for: window, to: session, capturing: desktop)
        })
        session.listeners.append(desktop.addEventListener(.pointerup) { [weak self] event in
            self?.deliverTracked(.leftMouseUp, event, for: window, to: session, capturing: desktop)
        })
        // A pointer the browser takes away — a system gesture, a lost window —
        // ends the session rather than leaving it listening forever.
        session.listeners.append(desktop.addEventListener(.pointercancel) { [weak self] _ in
            self?.finishEventTracking()
        })

        return true
    }

    /// Converts one DOM pointer event and hands it to the session.
    private func deliverTracked(
        _ type: NSEvent.EventType,
        _ event: Event,
        for window: NativeHandle,
        to session: EventTrackingSession,
        capturing desktop: Element
    ) {
        // A listener that outlived its session must do nothing: `deinit` on the
        // token removes it, but a queued event can still arrive first.
        guard !session.isFinished, eventTracking === session else { return }
        guard session.mask.winMatches(type) else { return }

        // Captured on the first tracked event rather than at set-up: the
        // pointer id is a property of the event, and there is no event yet when
        // the session starts.
        if session.pointerID == nil {
            let pointerID = event.rawValue.pointerId.number ?? 0
            session.pointerID = pointerID
            _ = desktop.rawValue.setPointerCapture?(pointerID)
        }

        // The drag owns the pointer; the page must not also select text or
        // start its own native drag underneath it.
        event.preventDefault()

        let tracked = mouseEvent(type, event, for: window)
        if session.handler(tracked) == .stop {
            finishEventTracking(deliverTerminator: true)
        }
    }

    /// Ends the current session, releasing capture and delivering the
    /// terminating `nil` exactly once.
    ///
    /// Internal rather than private: `runApplication`'s teardown ends any live
    /// session, so a page being torn down does not leave a caller waiting.
    internal func finishEventTracking(deliverTerminator: Bool = true) {
        guard let session = eventTracking, !session.isFinished else { return }
        session.isFinished = true
        eventTracking = nil

        if let pointerID = session.pointerID, let desktop {
            _ = desktop.rawValue.releasePointerCapture?(pointerID)
        }
        // Dropping the tokens removes the listeners — that is what their
        // `deinit` is for, and the reason they were held in the first place.
        session.listeners.removeAll()

        if deliverTerminator {
            _ = session.handler(nil)
        }
    }
}

#endif

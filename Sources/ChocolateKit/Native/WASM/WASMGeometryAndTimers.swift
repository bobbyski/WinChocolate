// Flipped coordinates, native timers, and scroll geometry.
//
// Three seams that share a theme: each is somewhere the browser's model and
// AppKit's model differ by exactly one rule, applied in exactly one place.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    // MARK: - Flipped coordinates

    /// The top edge, in DOM terms, of a child frame inside its parent.
    ///
    /// `NSView.isFlipped` is `true` by default in this framework, which matches
    /// the DOM, so this is the identity for almost every view. It stops being
    /// the identity the moment a view overrides `isFlipped` to `false` — then
    /// its children are measured from the *bottom* edge, and a child placed at
    /// y=0 belongs at the bottom of the box rather than the top.
    ///
    /// The inversion needs the parent's height, so it lives here rather than at
    /// each call site, and it is applied once: in `setFrame`.
    internal func domTop(of frame: NSRect, in parent: NativeHandle?) -> CGFloat {
        guard let parent, unflippedViews.contains(parent),
              let parentHeight = records[parent]?.frame.size.height else {
            return frame.origin.y
        }

        return parentHeight - frame.origin.y - frame.size.height
    }

    /// Records a view's flip state and re-places its children if it changed.
    ///
    /// Flipping a view does not change any child's frame, but it changes what
    /// every child's `y` *means* — so the children must be re-placed from
    /// frames they still hold. The same is true when an unflipped view's height
    /// changes, which `setFrame` handles.
    internal func applyViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        let wasUnflipped = unflippedViews.contains(handle)
        if flipped {
            unflippedViews.remove(handle)
        } else {
            unflippedViews.insert(handle)
        }
        if wasUnflipped != !flipped {
            replaceChildren(of: handle)
        }
    }

    /// Re-places every child of a view from its unchanged frame.
    internal func replaceChildren(of parent: NativeHandle) {
        for (handle, record) in records where record.parent == parent {
            guard let element = elements[handle] else { continue }
            _ = element.setStyle("top", "\(domTop(of: record.frame, in: parent))px")
        }
    }

    // MARK: - Native timers

    /// Schedules a repeating timer on the browser's clock.
    ///
    /// This is the whole reason `Timer.scheduledTimer` can work in a page:
    /// Foundation's run loop does not exist on WASI, so the framework routes
    /// repeating timers through this seam instead. Without it the demo's
    /// one-second tick is simply dead — which is what it was until now.
    internal func startNativeTimer(intervalMilliseconds: Int,
                                   action: @escaping () -> Void) -> UInt {
        let identifier = nextWASMTimerIdentifier
        nextWASMTimerIdentifier += 1
        guard DOM.isBrowser else { return identifier }

        // Held in a table, not discarded: SwiftDOM retains an interval until it
        // is cleared, and cancelling needs the token back.
        nativeTimers[identifier] = DOM.window.setInterval(milliseconds: max(0, intervalMilliseconds)) {
            action()
        }
        return identifier
    }

    /// Cancels a repeating timer.
    internal func stopNativeTimer(_ identifier: UInt) {
        nativeTimers.removeValue(forKey: identifier)?.cancel()
    }

    // MARK: - Scroll geometry

    /// Sizes a scroll view's document so the browser knows how far it scrolls.
    ///
    /// The scrollable extent is the *document* element's size, never the
    /// viewport's — an absolutely-positioned child contributes nothing
    /// reliable, so a scroll view whose document is unsized clips its content
    /// and refuses to scroll, which is exactly how these nine behaved.
    internal func applyScrollContentSize(_ contentSize: NSSize, for handle: NativeHandle) {
        _ = scrollDocuments[handle]?
            .setStyle("width", "\(contentSize.width)px")
            .setStyle("height", "\(contentSize.height)px")
    }

    /// Moves a scroll view's visible origin.
    internal func applyScrollContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        guard let viewport = elements[handle] else { return }
        viewport.scrollLeft = Double(offset.x)
        viewport.scrollTop = Double(offset.y)
    }
}

#endif

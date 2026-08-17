// Timer simulation and the shared internal helpers.
//
// The overridable half of this file — modal stop, wrapped text measurement,
// indeterminate progress, cursors, the native timer seam, key equivalents and
// context menus — moved to the class body in
// `InMemoryNativeControlBackendState.swift`. See the note there.
extension InMemoryNativeControlBackend {
    /// A recorded run-loop timer request.
    public struct ScheduledTimer: Equatable, Sendable {
        /// The timer identifier handed back to the scheduler.
        public let identifier: UInt

        /// The requested firing interval in milliseconds.
        public let intervalMilliseconds: Int
    }

    /// Fires a scheduled timer's action, standing in for a message-loop tick.
    /// Pair with `scheduledTimers` to test timer-coalesced code headlessly:
    /// schedule through the run loop, then `fireTimer(id)` (or `fireDueTimers`)
    /// to pump one tick deterministically.
    public func fireTimer(_ identifier: UInt) {
        timerActions[identifier]?()
    }

    /// Fires every scheduled timer's action once — a whole "message-loop tick"
    /// for headless tests of coalesced re-render paths (a Timer-batched layout
    /// pass fires here rather than waiting on a real run loop). Iterates a
    /// snapshot so a timer that reschedules during its action doesn't recurse.
    public func fireDueTimers() {
        for timer in scheduledTimers {
            timerActions[timer.identifier]?()
        }
    }

    internal func flattenedItems(of menu: NSMenu) -> [NSMenuItem] {
        var flattened: [NSMenuItem] = []
        for item in menu.items {
            flattened.append(item)
            if let submenu = item.submenu {
                flattened.append(contentsOf: flattenedItems(of: submenu))
            }
        }
        return flattened
    }

    internal func makeHandle(kind: String, text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = NativeHandle(rawValue: nextRawHandle)
        nextRawHandle += 1
        records[handle] = Record(
            kind: kind,
            text: text,
            frame: frame,
            parent: parent
        )
        return handle
    }

    internal func toolbarItemWidth(_ item: NativeToolbarItem, toolbarWidth: CGFloat) -> CGFloat {
        if item.isFlexibleSpace {
            return max(24, toolbarWidth / 4)
        }
        if let customViewWidth = item.customViewWidth {
            return customViewWidth
        }
        if item.isSeparator {
            return 8
        }

        let iconWidth: CGFloat = item.imageName == nil ? 0 : 24
        let labelWidth = CGFloat(max(28, item.label.count * 6))
        return max(iconWidth, labelWidth) + 20
    }
}

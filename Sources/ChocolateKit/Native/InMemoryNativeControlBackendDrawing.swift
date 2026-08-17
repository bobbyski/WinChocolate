extension InMemoryNativeControlBackend {
    /// Records a modal stop request.
    public func stopModal(withCode code: Int) {
        modalStopCodes.append(code)
    }

    /// Deterministic word-wrap estimate: the single-line metrics (`0.55 ×
    /// pointSize` per character, `1.35 × pointSize` per line) greedily packed
    /// into `maxWidth`-wide lines. Height is line count × line height; width is
    /// the widest packed line (≤ `maxWidth`).
    public func measureText(_ text: String, font: NativeFontSpec, wrappingAt maxWidth: CGFloat) -> NSSize {
        let charWidth = font.size * 0.55
        let lineHeight = font.size * 1.35
        guard maxWidth > 0, charWidth > 0 else {
            return measureText(text, font: font)
        }

        let maxChars = max(1, Int(maxWidth / charWidth))
        var lineCount = 0
        var widestChars = 0
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var currentChars = 0
            var lineStarted = false
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let addition = lineStarted ? word.count + 1 : word.count
                if lineStarted, currentChars + addition > maxChars {
                    lineCount += 1
                    widestChars = max(widestChars, currentChars)
                    currentChars = word.count
                } else {
                    currentChars += addition
                }
                lineStarted = true
            }
            lineCount += 1
            widestChars = max(widestChars, currentChars)
        }

        let width = min(CGFloat(widestChars) * charWidth, maxWidth)
        return NSMakeSize(width, CGFloat(max(lineCount, 1)) * lineHeight)
    }

    /// Records native progress indeterminate state.

    public func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool, for handle: NativeHandle) {
        progressIndeterminateStates[handle] = (isIndeterminate, animating)
    }

    /// Records a cursor request.
    public func setCursor(named name: String) {
        cursorNames.append(name)
    }

    /// Records a view's hover cursor regions.
    public func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle) {
        cursorRegions[handle] = regions
    }

    /// A recorded run-loop timer request.
    public struct ScheduledTimer: Equatable, Sendable {
        /// The timer identifier handed back to the scheduler.
        public let identifier: UInt

        /// The requested firing interval in milliseconds.
        public let intervalMilliseconds: Int
    }

    /// Records a run-loop timer request.
    public func scheduleNativeTimer(intervalMilliseconds: Int, action: @escaping () -> Void) -> UInt {
        let identifier = nextTimerIdentifier
        nextTimerIdentifier += 1
        scheduledTimers.append(ScheduledTimer(identifier: identifier, intervalMilliseconds: intervalMilliseconds))
        timerActions[identifier] = action
        return identifier
    }

    /// Records a run-loop timer cancellation.
    public func cancelNativeTimer(_ identifier: UInt) {
        timerActions.removeValue(forKey: identifier)
        canceledTimerIdentifiers.append(identifier)
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

    /// Records the key-equivalent handler.
    public func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {
        keyEquivalentHandler = handler
    }

    /// Records the pop request and performs the scripted flat-item selection.
    public func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? {
        poppedContextMenus.append(menu)
        let items = flattenedItems(of: menu)
        guard items.indices.contains(nextContextMenuSelection) else {
            return nil
        }

        let item = items[nextContextMenuSelection]
        _ = item.performAction()
        return item
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

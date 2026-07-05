/// A single-line search field control.
///
/// This first slice preserves the AppKit name and text-change/search action
/// shape while using the same native edit peer as `NSTextField`.
open class NSSearchField: NSTextField {
    /// Recent search strings tracked by the application.
    open var recentSearches: [String] = []

    /// Whether each edit should send the search action.
    open var sendsSearchStringImmediately: Bool = true

    /// Whether Return-style searches should send the whole search string.
    open var sendsWholeSearchString: Bool = true

    /// Creates a search field with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = true
        isSelectable = true
        isBordered = true
        drawsBackground = true
    }

    /// Performs the search action.
    open func performSearch(_ sender: Any?) {
        rememberCurrentSearch()
        sendAction()
    }

    /// Clears the search text and sends the action.
    open func cancelSearch(_ sender: Any?) {
        stringValue = ""
        sendAction()
    }

    /// Ensures native edit changes flow through search-field semantics.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
            if self.sendsSearchStringImmediately {
                self.rememberCurrentSearch()
                self.sendAction()
            }
        }
        return handle
    }

    private func rememberCurrentSearch() {
        guard !stringValue.isEmpty else {
            return
        }

        recentSearches.removeAll { $0 == stringValue }
        recentSearches.insert(stringValue, at: 0)
    }
}

/// An editable combo box control.
///
/// `NSComboBox` preserves AppKit's editable text plus item-list shape and maps
/// to a native Windows combo box in the classic backend.
open class NSComboBox: NSTextField {
    private var items: [String] = []

    /// Swift-native callback invoked when native text changes.
    open var onComboBoxTextChanged: ((NSComboBox) -> Void)?

    /// Whether the combo box completes typed text from its item list.
    ///
    /// The completion candidate is available through `completedString(forPrefix:)`
    /// and, when set, is applied on commit (Return / selection). Live
    /// as-you-type suffix selection over the native combo edit is future work.
    open var completes: Bool = false

    /// How many items the dropdown shows before scrolling.
    open var numberOfVisibleItems: Int = 5 {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setComboBoxVisibleItems(numberOfVisibleItems, for: nativeHandle)
        }
    }

    /// The first item that has `prefix` as a case-insensitive prefix, when the
    /// item extends the prefix. Returns `nil` when nothing completes.
    open func completedString(forPrefix prefix: String) -> String? {
        guard !prefix.isEmpty else {
            return nil
        }

        let lowerPrefix = prefix.lowercased()
        for item in items where item.count > prefix.count && item.lowercased().hasPrefix(lowerPrefix) {
            return item
        }
        return nil
    }

    /// Creates a combo box with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = true
        isSelectable = true
    }

    /// All item object values as strings.
    open var objectValues: [String] {
        items
    }

    /// Number of items.
    open var numberOfItems: Int {
        items.count
    }

    /// Adds one item.
    open func addItem(withObjectValue object: Any) {
        items.append(String(describing: object))
        syncItemsToNative()
    }

    /// Adds multiple items.
    open func addItems(withObjectValues objects: [Any]) {
        items.append(contentsOf: objects.map { String(describing: $0) })
        syncItemsToNative()
    }

    /// Removes all items.
    open func removeAllItems() {
        items.removeAll()
        syncItemsToNative()
    }

    /// Removes one item at an index.
    open func removeItem(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        items.remove(at: index)
        syncItemsToNative()
    }

    /// Returns the item at an index.
    open func itemObjectValue(at index: Int) -> Any {
        items[index]
    }

    /// Returns the index of an item, or `-1`.
    open func indexOfItem(withObjectValue object: Any) -> Int {
        items.firstIndex(of: String(describing: object)) ?? -1
    }

    /// Selects an item by index and copies it into `stringValue`.
    open func selectItem(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        stringValue = items[index]
    }

    /// Creates the native Windows combo-box peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createComboBox(items: items, text: stringValue, frame: frame, parent: parent)
    }

    /// Ensures native text and action bridges are registered.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setComboBoxVisibleItems(numberOfVisibleItems, for: handle)
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
            self.onComboBoxTextChanged?(self)
        }
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(backend.comboBoxText(for: nativeHandle))
            // On commit, complete a partial entry to the first matching item.
            if self.completes, let completed = self.completedString(forPrefix: self.stringValue) {
                self.stringValue = completed
            }
            self.sendAction()
        }
        return handle
    }

    private func syncItemsToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setComboBoxItems(items, text: stringValue, for: nativeHandle)
    }
}

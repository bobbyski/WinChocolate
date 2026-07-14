/// Supplies a data-source-backed combo box with its items.
public protocol NSComboBoxDataSource: NSObjectProtocol {
    /// Returns how many items the combo box shows.
    func numberOfItems(in comboBox: NSComboBox) -> Int

    /// Returns the object value for an item index.
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any?
}

/// The methods a combo-box delegate implements, matching AppKit's shape:
/// text callbacks ride the text-field delegate surface, selection commits
/// arrive through `comboBoxSelectionDidChange`.
public protocol NSComboBoxDelegate: NSTextFieldDelegate {
    /// Tells the delegate the selected item changed.
    func comboBoxSelectionDidChange(_ notification: NSNotification)
}

extension NSComboBoxDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func comboBoxSelectionDidChange(_ notification: NSNotification) {}
}

/// An editable combo box control.
///
/// `NSComboBox` preserves AppKit's editable text plus item-list shape and maps
/// to a native Windows combo box in the classic backend.
open class NSComboBox: NSTextField {
    private var items: [String] = []

    /// Framework-internal edit hook (the font panel tracks its size combo).
    /// Not API: applications use the text-field delegate surface
    /// (`controlTextDidChange(_:)`), as in AppKit.
    var winInternalComboTextChanged: ((NSComboBox) -> Void)?

    /// The data source that supplies items when `usesDataSource` is set.
    open weak var dataSource: NSComboBoxDataSource?

    /// Whether the combo box pulls items from its `dataSource` instead of its
    /// own added-item list.
    open var usesDataSource: Bool = false {
        didSet {
            if usesDataSource {
                reloadData()
            }
        }
    }

    /// Whether the dropdown shows a vertical scroller (native combos always do;
    /// stored for AppKit source compatibility).
    open var hasVerticalScroller: Bool = true

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
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = true
        isSelectable = true
    }

    /// Creates a combo box with a zero frame, matching AppKit's shape.
    public convenience init() {
        self.init(frame: .zero)
    }

    /// The index of the item matching the current text, or `-1`.
    ///
    /// Selection commits copy the picked item into `stringValue`, so the
    /// match against the item list is the selection state.
    open var indexOfSelectedItem: Int {
        items.firstIndex(of: stringValue) ?? -1
    }

    /// The control's natural size (9.2): the widest item (or current text)
    /// measured with the current font, plus the drop-down chevron and padding,
    /// at the standard combo-box height.
    open override var intrinsicContentSize: NSSize {
        let font = self.font ?? NSFont.systemFont(ofSize: 13)
        var widest = stringValue.size(withAttributes: [.font: font]).width
        for value in objectValues {
            widest = max(widest, value.size(withAttributes: [.font: font]).width)
        }
        return NSSize(width: max(widest + 30, 60), height: 26)
    }

    /// All item object values as strings.
    open var objectValues: [String] {
        items
    }

    /// Number of items.
    open var numberOfItems: Int {
        items.count
    }

    /// Rebuilds the item list from the `dataSource` and syncs it to the peer.
    ///
    /// No-ops unless `usesDataSource` is set and a `dataSource` is present.
    open func reloadData() {
        pullItemsFromDataSource()
        syncItemsToNative()
    }

    private func pullItemsFromDataSource() {
        guard usesDataSource, let dataSource else {
            return
        }

        let count = max(0, dataSource.numberOfItems(in: self))
        items = (0..<count).map { index in
            dataSource.comboBox(self, objectValueForItemAt: index).map { String(describing: $0) } ?? ""
        }
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
        // Populate items from the data source before the peer is created so the
        // native combo shows them from the start.
        pullItemsFromDataSource()
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setComboBoxVisibleItems(numberOfVisibleItems, for: handle)
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
            self.winInternalComboTextChanged?(self)
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
            // A commit whose text matches an item is a selection change.
            if self.indexOfSelectedItem >= 0 {
                (self.delegate as? NSComboBoxDelegate)?.comboBoxSelectionDidChange(
                    NSNotification(name: "NSComboBoxSelectionDidChangeNotification", object: self)
                )
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

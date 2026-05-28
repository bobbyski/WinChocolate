/// A pop-up button backed by a native Windows combo box.
///
/// The public surface follows AppKit's common item-title and selected-index
/// workflow while keeping native Windows selection messages behind the backend.
open class NSPopUpButton: NSControl {
    private var titles: [String]
    private var isUpdatingSelectionFromNative = false

    /// The selected item index, or `-1` when there is no selection.
    open var indexOfSelectedItem: Int {
        didSet {
            guard !isUpdatingSelectionFromNative else {
                return
            }

            guard let nativeHandle else {
                return
            }

            realizedBackend?.setPopUpButtonSelectedIndex(indexOfSelectedItem, for: nativeHandle)
        }
    }

    /// The selected item title, when an item is selected.
    open var titleOfSelectedItem: String? {
        guard itemTitles.indices.contains(indexOfSelectedItem) else {
            return nil
        }

        return itemTitles[indexOfSelectedItem]
    }

    /// Creates a pop-up button with a frame.
    public override init(frame frameRect: NSRect) {
        self.titles = []
        self.indexOfSelectedItem = -1
        super.init(frame: frameRect)
    }

    /// Creates a pop-up button with AppKit's common initializer shape.
    public init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        self.titles = []
        self.indexOfSelectedItem = -1
        super.init(frame: buttonFrame)
    }

    /// All item titles in display order.
    open var itemTitles: [String] {
        titles
    }

    /// Returns the number of items.
    open var numberOfItems: Int {
        titles.count
    }

    /// Returns the last item title, if any.
    open var lastItem: String? {
        titles.last
    }

    /// Adds one item title.
    open func addItem(withTitle title: String) {
        titles.append(title)
        if indexOfSelectedItem < 0 {
            indexOfSelectedItem = 0
        }
        syncItemsToNative()
    }

    /// Adds multiple item titles.
    open func addItems(withTitles titles: [String]) {
        self.titles.append(contentsOf: titles)
        if indexOfSelectedItem < 0 && !self.titles.isEmpty {
            indexOfSelectedItem = 0
        }
        syncItemsToNative()
    }

    /// Removes all items.
    open func removeAllItems() {
        titles.removeAll()
        indexOfSelectedItem = -1
        syncItemsToNative()
    }

    /// Removes an item at an index.
    open func removeItem(at index: Int) {
        guard titles.indices.contains(index) else {
            return
        }

        titles.remove(at: index)
        if titles.isEmpty {
            indexOfSelectedItem = -1
        } else if indexOfSelectedItem >= titles.count {
            indexOfSelectedItem = titles.count - 1
        }
        syncItemsToNative()
    }

    /// Removes the first item matching a title.
    open func removeItem(withTitle title: String) {
        guard let index = titles.firstIndex(of: title) else {
            return
        }

        removeItem(at: index)
    }

    /// Returns the title at an item index.
    open func itemTitle(at index: Int) -> String {
        titles[index]
    }

    /// Returns the index of an item title, or `-1` when absent.
    open func indexOfItem(withTitle title: String) -> Int {
        titles.firstIndex(of: title) ?? -1
    }

    /// Selects an item by index.
    open func selectItem(at index: Int) {
        guard titles.indices.contains(index) else {
            return
        }

        indexOfSelectedItem = index
    }

    /// Selects the first item matching a title.
    open func selectItem(withTitle title: String) {
        guard let index = titles.firstIndex(of: title) else {
            return
        }

        selectItem(at: index)
    }

    /// Creates the native Windows pop-up button peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createPopUpButton(items: titles, selectedIndex: indexOfSelectedItem, frame: frame, parent: parent)
    }

    /// Ensures the pop-up button has a native peer and registers selection dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            self.updateSelectionFromNative(backend.popUpButtonSelectedIndex(for: nativeHandle))
            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
        }
        return handle
    }

    private func syncItemsToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setPopUpButtonItems(titles, selectedIndex: indexOfSelectedItem, for: nativeHandle)
    }

    private func updateSelectionFromNative(_ index: Int) {
        isUpdatingSelectionFromNative = true
        indexOfSelectedItem = index
        isUpdatingSelectionFromNative = false
    }
}

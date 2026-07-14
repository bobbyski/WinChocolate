/// A pop-up button backed by a native Windows combo box.
///
/// The public surface follows AppKit's common item-title and selected-index
/// workflow while keeping native Windows selection messages behind the backend.
open class NSPopUpButton: NSControl {
    private var titles: [String]
    private var tags: [Int] = []
    private var enabledStates: [Bool] = []
    private var images: [NSImage?] = []
    private var isUpdatingSelectionFromNative = false

    /// Whether items are automatically enabled/disabled by menu validation.
    ///
    /// When cleared, explicit per-item enabled state (`setItemEnabled(_:at:)`)
    /// applies. Visually graying individual items in the native combo needs
    /// owner-draw (tracked in 8.3); the enabled model is available now.
    open var autoenablesItems: Bool = true

    /// Whether the button acts as a pull-down menu (fixed title) rather than a
    /// pop-up that shows the selected item.
    open private(set) var pullsDown: Bool = false

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
    public required init(frame frameRect: NSRect) {
        self.titles = []
        self.indexOfSelectedItem = -1
        super.init(frame: frameRect)
    }

    /// Creates a pop-up button with AppKit's common initializer shape.
    public init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        self.titles = []
        self.indexOfSelectedItem = -1
        super.init(frame: buttonFrame)
        self.pullsDown = flag
    }

    /// The control's natural size (9.2): the widest item title measured with the
    /// current font, plus the chevron and padding, at the standard pop-up height.
    open override var intrinsicContentSize: NSSize {
        let font = self.font ?? NSFont.systemFont(ofSize: 13)
        let widest = itemTitles.map { $0.size(withAttributes: [.font: font]).width }.max() ?? 0
        return NSSize(width: max(widest + 34, 60), height: 26)
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
        tags.append(0)
        enabledStates.append(true)
        images.append(nil)
        if indexOfSelectedItem < 0 {
            indexOfSelectedItem = 0
        }
        syncItemsToNative()
    }

    /// Adds multiple item titles.
    open func addItems(withTitles titles: [String]) {
        self.titles.append(contentsOf: titles)
        self.tags.append(contentsOf: Array(repeating: 0, count: titles.count))
        self.enabledStates.append(contentsOf: Array(repeating: true, count: titles.count))
        self.images.append(contentsOf: Array<NSImage?>(repeating: nil, count: titles.count))
        if indexOfSelectedItem < 0 && !self.titles.isEmpty {
            indexOfSelectedItem = 0
        }
        syncItemsToNative()
    }

    /// Removes all items.
    open func removeAllItems() {
        titles.removeAll()
        tags.removeAll()
        enabledStates.removeAll()
        images.removeAll()
        indexOfSelectedItem = -1
        syncItemsToNative()
    }

    /// Sets whether the item at an index is enabled (used when
    /// `autoenablesItems` is off).
    open func setItemEnabled(_ enabled: Bool, at index: Int) {
        guard enabledStates.indices.contains(index) else {
            return
        }

        enabledStates[index] = enabled
    }

    /// Returns whether the item at an index is enabled. Always `true` while
    /// `autoenablesItems` is set.
    open func isItemEnabled(at index: Int) -> Bool {
        guard enabledStates.indices.contains(index) else {
            return false
        }

        return autoenablesItems ? true : enabledStates[index]
    }

    /// Sets the image shown beside the item at an index.
    ///
    /// The image is stored on the item model. Rendering item icons and graying
    /// disabled rows inside the native `COMBOBOX` dropdown requires owner-draw
    /// (the modern-appearance engine); the model/selection behavior is complete.
    open func setImage(_ image: NSImage?, forItemAt index: Int) {
        guard images.indices.contains(index) else {
            return
        }

        images[index] = image
    }

    /// Returns the image for the item at an index, if any.
    open func itemImage(at index: Int) -> NSImage? {
        images.indices.contains(index) ? images[index] : nil
    }

    /// Sets the tag for an item at an index.
    package func setTag(_ tag: Int, forItemAt index: Int) {
        guard tags.indices.contains(index) else {
            return
        }

        tags[index] = tag
    }

    /// The tag of the item at an index, or 0 when absent.
    open func tag(atIndex index: Int) -> Int {
        tags.indices.contains(index) ? tags[index] : 0
    }

    /// The tag of the selected item, or 0 when nothing is selected.
    open func selectedTag() -> Int {
        tags.indices.contains(indexOfSelectedItem) ? tags[indexOfSelectedItem] : 0
    }

    /// The index of the first item with a tag, or -1 when absent.
    open func indexOfItem(withTag tag: Int) -> Int {
        tags.firstIndex(of: tag) ?? -1
    }

    /// Selects the first item with a tag, returning whether one was found.
    @discardableResult
    open func selectItem(withTag tag: Int) -> Bool {
        let index = indexOfItem(withTag: tag)
        guard index >= 0 else {
            return false
        }

        selectItem(at: index)
        return true
    }

    /// Removes an item at an index.
    open func removeItem(at index: Int) {
        guard titles.indices.contains(index) else {
            return
        }

        titles.remove(at: index)
        if tags.indices.contains(index) {
            tags.remove(at: index)
        }
        if enabledStates.indices.contains(index) {
            enabledStates.remove(at: index)
        }
        if images.indices.contains(index) {
            images.remove(at: index)
        }
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

    /// Selects a menu item, or clears the selection for `nil`, matching
    /// AppKit's shape. WinChocolate items are title-backed, so a non-nil
    /// item selects by its title.
    open func select(_ item: NSMenuItem?) {
        guard let item else {
            indexOfSelectedItem = -1
            return
        }

        selectItem(withTitle: item.title)
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

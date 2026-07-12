/// An item displayed in an `NSTabView`.
open class NSTabViewItem: NSObject {
    /// Stable item identifier.
    open var identifier: Any?

    /// Visible tab label.
    open var label: String

    /// Optional view associated with this tab.
    open var view: NSView?

    /// Creates a tab-view item with an identifier.
    public init(identifier: Any?) {
        self.identifier = identifier
        self.label = String(describing: identifier ?? "")
        self.view = nil
        super.init()
    }
}

/// The methods a tab-view delegate uses to observe selection, matching
/// AppKit's shape.
public protocol NSTabViewDelegate: AnyObject {
    /// Tells the delegate a tab item was selected.
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?)
}

extension NSTabViewDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {}
}

/// A tab view control.
///
/// This first slice stores AppKit-shaped tab items and maps labels to a native
/// Windows tab control in the classic backend.
open class NSTabView: NSControl {
    private var items: [NSTabViewItem] = []
    private var selectedIndex: Int = -1
    private var isUpdatingSelectionFromNative = false

    /// Swift-native callback invoked when tab selection changes.
    open var onSelectionChanged: ((NSTabView) -> Void)?

    /// The delegate notified when tab selection changes.
    open weak var delegate: NSTabViewDelegate?

    /// The current tab-view items.
    open var tabViewItems: [NSTabViewItem] {
        items
    }

    /// The selected tab item.
    open var selectedTabViewItem: NSTabViewItem? {
        guard items.indices.contains(selectedIndex) else {
            return nil
        }

        return items[selectedIndex]
    }

    /// Creates a tab view with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Adds a tab item.
    open func addTabViewItem(_ tabViewItem: NSTabViewItem) {
        items.append(tabViewItem)
        if selectedIndex < 0 {
            selectedIndex = 0
        }
        syncItemsToNative()
    }

    /// Removes a tab item.
    open func removeTabViewItem(_ tabViewItem: NSTabViewItem) {
        guard let index = items.firstIndex(where: { $0 === tabViewItem }) else {
            return
        }

        items.remove(at: index)
        if items.isEmpty {
            selectedIndex = -1
        } else if selectedIndex >= items.count {
            selectedIndex = items.count - 1
        }
        syncItemsToNative()
    }

    /// Selects a tab item.
    open func selectTabViewItem(_ tabViewItem: NSTabViewItem?) {
        guard let tabViewItem,
              let index = items.firstIndex(where: { $0 === tabViewItem }) else {
            return
        }

        selectTabViewItem(at: index)
    }

    /// Selects a tab item by index.
    open func selectTabViewItem(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        selectedIndex = index
        if !isUpdatingSelectionFromNative, let nativeHandle {
            realizedBackend?.setTabViewSelectedIndex(selectedIndex, for: nativeHandle)
        }
        onSelectionChanged?(self)
        delegate?.tabView(self, didSelect: selectedTabViewItem)
    }

    /// Returns the index of a tab item.
    open func indexOfTabViewItem(_ tabViewItem: NSTabViewItem) -> Int {
        items.firstIndex(where: { $0 === tabViewItem }) ?? -1
    }

    /// Creates the native tab-view peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTabView(items: items.map(\.label), selectedIndex: selectedIndex, frame: frame, parent: parent)
    }

    /// Ensures native selection dispatch is registered.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            self.isUpdatingSelectionFromNative = true
            self.selectedIndex = backend.tabViewSelectedIndex(for: nativeHandle)
            self.isUpdatingSelectionFromNative = false
            _ = self.window?.makeFirstResponder(self)
            self.onSelectionChanged?(self)
            self.sendAction()
        }
        return handle
    }

    private func syncItemsToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTabViewItems(items.map(\.label), selectedIndex: selectedIndex, for: nativeHandle)
    }
}

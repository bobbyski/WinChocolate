/// Data source for an AppKit-shaped collection view.
public protocol NSCollectionViewDataSource: AnyObject {
    /// Returns the number of sections.
    func numberOfSections(in collectionView: NSCollectionView) -> Int

    /// Returns the number of items in a section.
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int

    /// Returns the item view-controller object for an index path.
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem
}

public extension NSCollectionViewDataSource {
    /// Most collection views start with one section.
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }
}

/// Delegate for collection-view selection notifications.
public protocol NSCollectionViewDelegate: AnyObject {
    /// Called after items are selected.
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>)

    /// Called after items are deselected.
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>)
}

public extension NSCollectionViewDelegate {
    /// Default selected-items hook.
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {}

    /// Default deselected-items hook.
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {}
}

/// A simple collection-view item.
open class NSCollectionViewItem: NSObject {
    /// The item's root view.
    open var view: NSView

    /// Application object represented by the item.
    open var representedObject: Any?

    /// Whether the item is currently selected.
    open var isSelected: Bool = false {
        didSet {
            view.backgroundColor = isSelected
                ? NSColor(calibratedRed: 0.82, green: 0.9, blue: 1.0, alpha: 1.0)
                : nil
        }
    }

    /// Creates an item with a default view.
    public override init() {
        self.view = NSView(frame: NSMakeRect(0, 0, 96, 32))
        super.init()
    }
}

/// A grid of reusable item views.
///
/// This first slice composes child views in a fixed-size grid. It preserves the
/// common AppKit data-source and selection surface while richer layouts and
/// item reuse remain future work.
open class NSCollectionView: NSControl {
    /// Object that provides collection items.
    open weak var dataSource: NSCollectionViewDataSource?

    /// Object notified about selection changes.
    open weak var delegate: NSCollectionViewDelegate?

    /// Size assigned to each item view.
    open var itemSize: NSSize = NSMakeSize(112, 34) {
        didSet {
            tile()
        }
    }

    /// Horizontal gap between items.
    open var minimumInteritemSpacing: CGFloat = 8 {
        didSet {
            tile()
        }
    }

    /// Vertical gap between rows.
    open var minimumLineSpacing: CGFloat = 8 {
        didSet {
            tile()
        }
    }

    /// Whether multiple items can be selected.
    open var allowsMultipleSelection: Bool = false

    /// Whether no selection is allowed.
    open var allowsEmptySelection: Bool = true

    /// Current selected index paths.
    public private(set) var selectionIndexPaths: Set<IndexPath> = []

    private var itemsByIndexPath: [IndexPath: NSCollectionViewItem] = [:]
    private var orderedIndexPaths: [IndexPath] = []

    /// Creates a collection view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Creates a native host view for the composed item views.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Reloads all collection items from the data source.
    open func reloadData() {
        for item in itemsByIndexPath.values {
            item.view.removeFromSuperview()
        }

        itemsByIndexPath.removeAll()
        orderedIndexPaths.removeAll()

        let sectionCount = dataSource?.numberOfSections(in: self) ?? 0
        for section in 0..<sectionCount {
            let itemCount = dataSource?.collectionView(self, numberOfItemsInSection: section) ?? 0
            for itemIndex in 0..<itemCount {
                let indexPath = IndexPath(item: itemIndex, section: section)
                guard let item = dataSource?.collectionView(self, itemForRepresentedObjectAt: indexPath) else {
                    continue
                }

                itemsByIndexPath[indexPath] = item
                orderedIndexPaths.append(indexPath)
                addSubview(item.view)
                wireSelectionAction(for: item, at: indexPath)
            }
        }

        selectionIndexPaths = selectionIndexPaths.filter { itemsByIndexPath[$0] != nil }
        updateItemSelectionState()
        tile()
    }

    /// Lays out visible item views.
    open func tile() {
        let availableWidth = max(itemSize.width, frame.size.width)
        let stride = max(1, itemSize.width + minimumInteritemSpacing)
        let columns = max(1, Int((availableWidth + minimumInteritemSpacing) / stride))

        for (offset, indexPath) in orderedIndexPaths.enumerated() {
            guard let item = itemsByIndexPath[indexPath] else {
                continue
            }

            let column = offset % columns
            let row = offset / columns
            let x = CGFloat(column) * (itemSize.width + minimumInteritemSpacing)
            let y = CGFloat(row) * (itemSize.height + minimumLineSpacing)
            item.view.frame = NSMakeRect(x, y, itemSize.width, itemSize.height)
        }
    }

    /// Selects a set of items.
    open func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition = []) {
        let valid = indexPaths.filter { itemsByIndexPath[$0] != nil }
        guard !valid.isEmpty else {
            if allowsEmptySelection {
                deselectAll(nil)
            }
            return
        }

        let oldSelection = selectionIndexPaths
        selectionIndexPaths = allowsMultipleSelection ? selectionIndexPaths.union(valid) : [valid.min(by: compareIndexPaths) ?? valid.first!]
        updateItemSelectionState()

        let selected = selectionIndexPaths.subtracting(oldSelection)
        if !selected.isEmpty {
            delegate?.collectionView(self, didSelectItemsAt: selected)
            sendAction()
        }
    }

    /// Deselects a set of items.
    open func deselectItems(at indexPaths: Set<IndexPath>) {
        let oldSelection = selectionIndexPaths
        selectionIndexPaths.subtract(indexPaths)
        if selectionIndexPaths.isEmpty && !allowsEmptySelection {
            selectionIndexPaths = oldSelection
            return
        }

        updateItemSelectionState()
        let deselected = oldSelection.subtracting(selectionIndexPaths)
        if !deselected.isEmpty {
            delegate?.collectionView(self, didDeselectItemsAt: deselected)
        }
    }

    /// Clears selection.
    open func deselectAll(_ sender: Any?) {
        guard allowsEmptySelection else {
            return
        }

        let oldSelection = selectionIndexPaths
        selectionIndexPaths.removeAll()
        updateItemSelectionState()
        if !oldSelection.isEmpty {
            delegate?.collectionView(self, didDeselectItemsAt: oldSelection)
        }
    }

    /// Returns the item at an index path, when loaded.
    open func item(at indexPath: IndexPath) -> NSCollectionViewItem? {
        itemsByIndexPath[indexPath]
    }

    /// Returns the first index path for an item object.
    open func indexPath(for item: NSCollectionViewItem) -> IndexPath? {
        itemsByIndexPath.first { $0.value === item }?.key
    }

    private func wireSelectionAction(for item: NSCollectionViewItem, at indexPath: IndexPath) {
        if let control = item.view as? NSControl {
            let previousAction = control.onAction
            control.onAction = { [weak self, weak control] _ in
                previousAction?(control ?? NSControl(frame: NSZeroRect))
                self?.selectItems(at: [indexPath])
            }
        } else {
            item.view.registerCollectionClick { [weak self] in
                self?.selectItems(at: [indexPath])
            }
        }
    }

    private func updateItemSelectionState() {
        for (indexPath, item) in itemsByIndexPath {
            item.isSelected = selectionIndexPaths.contains(indexPath)
        }
    }

    private func compareIndexPaths(_ lhs: IndexPath, _ rhs: IndexPath) -> Bool {
        if lhs.section == rhs.section {
            return lhs.item < rhs.item
        }

        return lhs.section < rhs.section
    }
}

public extension NSCollectionView {
    /// Scroll-position options accepted by collection selection APIs.
    struct ScrollPosition: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let top = ScrollPosition(rawValue: 1 << 0)
        public static let centeredVertically = ScrollPosition(rawValue: 1 << 1)
        public static let bottom = ScrollPosition(rawValue: 1 << 2)
        public static let left = ScrollPosition(rawValue: 1 << 3)
        public static let centeredHorizontally = ScrollPosition(rawValue: 1 << 4)
        public static let right = ScrollPosition(rawValue: 1 << 5)
    }
}

private final class CollectionClickView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }
}

private extension NSView {
    func registerCollectionClick(_ action: @escaping () -> Void) {
        if let clickView = self as? CollectionClickView {
            clickView.onClick = action
        }
    }
}

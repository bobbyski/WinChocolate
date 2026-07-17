/// Data source for an AppKit-shaped collection view.
@MainActor
public protocol NSCollectionViewDataSource: NSObjectProtocol {
    /// Returns the number of sections.
    func numberOfSections(in collectionView: NSCollectionView) -> Int

    /// Returns the number of items in a section.
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int

    /// Returns the item view-controller object for an index path.
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem

    /// Returns a supplementary view (e.g. a section header) for an index path.
    ///
    /// The returned view MUST come from
    /// `makeSupplementaryView(ofKind:withIdentifier:for:)` — real AppKit asserts
    /// on any other view. See Issue N in `Docs/AppKitFaithfulnessIssues.md`.
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView
}

public extension NSCollectionViewDataSource {
    /// Most collection views start with one section.
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    /// Default: an empty view (the protocol returns non-optional `NSView`,
    /// exactly as Apple's).
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView {
        NSView()
    }
}

/// Delegate for collection-view selection notifications.
@MainActor
public protocol NSCollectionViewDelegate: NSObjectProtocol {
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

/// Flow-layout delegate that supplies a per-item size (and, later, per-section
/// insets/spacing). Matches `NSCollectionViewDelegateFlowLayout`.
@MainActor
public protocol NSCollectionViewDelegateFlowLayout: NSCollectionViewDelegate {
    /// The size for the item at an index path. Return `.zero` to fall back to
    /// the layout's uniform `itemSize`.
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize
}

public extension NSCollectionViewDelegateFlowLayout {
    /// Default: use the layout's uniform item size.
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        .zero
    }
}

/// A simple collection-view item.
open class NSCollectionViewItem: NSObject {
    /// The item's root view.
    open var view: NSView

    /// Application object represented by the item.
    open var representedObject: Any?

    /// The reuse identifier the item was made with (set by `makeItem`), used to
    /// return it to the correct recycling pool.
    open var identifier: NSUserInterfaceItemIdentifier?

    /// Whether the item is currently selected.
    open var isSelected: Bool = false {
        didSet {
            view.winBackgroundColor = isSelected
                ? NSColor(calibratedRed: 0.82, green: 0.9, blue: 1.0, alpha: 1.0)
                : nil
        }
    }

    /// Creates an item with a default view. `required` so the collection view
    /// can instantiate a registered item class for recycling.
    public required override init() {
        self.view = NSView(frame: NSMakeRect(0, 0, 96, 32))
        super.init()
    }

    /// Called before a recycled item is handed back out. Subclasses reset any
    /// per-use state here (matching AppKit's `NSCollectionViewItem`).
    open func prepareForReuse() {
        isSelected = false
        representedObject = nil
    }
}

/// Marker for views a collection hosts as supplementary elements, matching
/// AppKit's protocol name (the classic slice needs no members).
public protocol NSCollectionViewElement: AnyObject {}

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

    /// The element-kind string type, matching AppKit's name.
    public typealias SupplementaryElementKind = String

    /// The insertion-gap indicator kind requested during drag sessions.
    public static let elementKindInterItemGapIndicator = "NSCollectionElementKindInterItemGapIndicator"

    /// Whether items can be selected by clicking. Stored for AppKit shape;
    /// the classic slice always routes clicks to selection.
    open var isSelectable: Bool = true

    /// The supplementary element kind for a section header.
    ///
    /// The `UI` prefix is not a typo: AppKit's collection view is implemented on
    /// top of the UICollectionView code (hence `UICollectionView.m` in its
    /// assertions), and these are the exact strings Apple vends. Verified by
    /// printing them from real AppKit.
    public static let elementKindSectionHeader: SupplementaryElementKind = "UICollectionElementKindSectionHeader"

    /// The supplementary element kind for a section footer.
    public static let elementKindSectionFooter: SupplementaryElementKind = "UICollectionElementKindSectionFooter"

    /// Hosted supplementary (header) views, by section.
    private var hostedSupplementaryViews: [Int: NSView] = [:]

    /// The layout that arranges items. When set, it overrides the built-in
    /// grid; assign an `NSCollectionViewFlowLayout` for AppKit-style flow.
    open var collectionViewLayout: NSCollectionViewLayout? {
        didSet {
            collectionViewLayout?.collectionView = self
            // The set of supplementary views is layout-driven, so (re)build them
            // when the layout changes; `tile()` then only repositions.
            rebuildSupplementaryViews()
            tile()
        }
    }

    /// Whether multiple items can be selected.
    open var allowsMultipleSelection: Bool = false

    /// Whether no selection is allowed.
    open var allowsEmptySelection: Bool = true

    /// Current selected index paths. Settable, matching AppKit; assignment
    /// syncs each visible item's selected state.
    open var selectionIndexPaths: Set<IndexPath> = [] {
        didSet {
            guard selectionIndexPaths != oldValue else {
                return
            }

            for (path, item) in itemsByIndexPath {
                item.isSelected = selectionIndexPaths.contains(path)
            }
        }
    }

    private var itemsByIndexPath: [IndexPath: NSCollectionViewItem] = [:]
    private var orderedIndexPaths: [IndexPath] = []

    /// Item classes registered for a reuse identifier (for `makeItem`).
    private var itemClassesByIdentifier: [String: NSCollectionViewItem.Type] = [:]
    /// Recycled items available for reuse, keyed by their reuse identifier.
    private var reusePool: [String: [NSCollectionViewItem]] = [:]

    /// View classes registered for a supplementary kind+identifier.
    private var supplementaryClasses: [String: NSView.Type] = [:]
    /// Recycled supplementary views, keyed by kind+identifier.
    private var supplementaryReusePool: [String: [NSView]] = [:]

    /// Joins a kind and an identifier into one pool key. `\u{1}` cannot occur in
    /// either component, so the join is unambiguous.
    private func supplementaryKey(_ kind: SupplementaryElementKind,
                                  _ identifier: NSUserInterfaceItemIdentifier) -> String {
        "\(kind)\u{1}\(identifier.rawValue)"
    }

    /// Creates a collection view.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Creates a native host view for the composed item views.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Registers an item class to instantiate for a reuse identifier. Passing
    /// `nil` unregisters the identifier. Matches AppKit's
    /// `register(_:forItemWithIdentifier:)`.
    open func register(_ itemClass: NSCollectionViewItem.Type?, forItemWithIdentifier identifier: NSUserInterfaceItemIdentifier) {
        if let itemClass {
            itemClassesByIdentifier[identifier.rawValue] = itemClass
        } else {
            itemClassesByIdentifier.removeValue(forKey: identifier.rawValue)
            reusePool.removeValue(forKey: identifier.rawValue)
        }
    }

    /// Registers a view class to instantiate for a supplementary kind+identifier.
    /// Passing `nil` unregisters. Matches AppKit's
    /// `register(_:forSupplementaryViewOfKind:withIdentifier:)`.
    ///
    /// Instantiating the class from its metatype is why `NSView.init(frame:)` is
    /// `required` — the same reason `NSCollectionViewItem.init()` is.
    open func register(_ viewClass: AnyClass?,
                       forSupplementaryViewOfKind kind: SupplementaryElementKind,
                       withIdentifier identifier: NSUserInterfaceItemIdentifier) {
        let key = supplementaryKey(kind, identifier)
        guard let viewClass else {
            supplementaryClasses.removeValue(forKey: key)
            supplementaryReusePool.removeValue(forKey: key)
            return
        }
        guard let viewType = viewClass as? NSView.Type else {
            fatalError("\(viewClass) is not an NSView subclass")
        }
        supplementaryClasses[key] = viewType
    }

    /// Returns a supplementary view for a kind+identifier, recycling one when
    /// available. Data sources MUST vend their header/footer views from here
    /// rather than constructing them: real AppKit raises "the view returned from
    /// -collectionView:viewForSupplementaryElementOfKind: … was not retrieved by
    /// calling -makeSupplementaryViewOfKind:withIdentifier:forIndexPath:", so a
    /// data source that builds its own views works here but crashes on Apple.
    open func makeSupplementaryView(ofKind kind: SupplementaryElementKind,
                                    withIdentifier identifier: NSUserInterfaceItemIdentifier,
                                    for indexPath: IndexPath) -> NSView {
        let key = supplementaryKey(kind, identifier)
        if var pooled = supplementaryReusePool[key], let reused = pooled.popLast() {
            supplementaryReusePool[key] = pooled
            reused.identifier = identifier
            return reused
        }
        guard let viewType = supplementaryClasses[key] else {
            fatalError("""
                no class registered for supplementary view of kind '\(kind)' with \
                identifier '\(identifier.rawValue)' — call \
                register(_:forSupplementaryViewOfKind:withIdentifier:) first
                """)
        }
        let view = viewType.init(frame: .zero)
        view.identifier = identifier
        return view
    }

    /// Returns a recycled item for the identifier if one is available, otherwise
    /// instantiates the registered class (or a base `NSCollectionViewItem`). The
    /// data source calls this inside `itemForRepresentedObjectAt`, exactly as in
    /// AppKit's `makeItem(withIdentifier:for:)`.
    open func makeItem(withIdentifier identifier: NSUserInterfaceItemIdentifier, for indexPath: IndexPath) -> NSCollectionViewItem {
        if var pooled = reusePool[identifier.rawValue], let reused = pooled.popLast() {
            reusePool[identifier.rawValue] = pooled
            reused.prepareForReuse()
            reused.identifier = identifier
            return reused
        }
        let itemClass = itemClassesByIdentifier[identifier.rawValue] ?? NSCollectionViewItem.self
        let item = itemClass.init()
        item.identifier = identifier
        return item
    }

    /// Moves the current items into the reuse pool (keyed by identifier) so the
    /// next `makeItem` can hand them back instead of allocating.
    private func recycleCurrentItems() {
        for item in itemsByIndexPath.values {
            item.view.removeFromSuperview()
            guard let key = item.identifier?.rawValue else {
                continue
            }
            reusePool[key, default: []].append(item)
        }
    }

    /// Reloads all collection items from the data source.
    open func reloadData() {
        recycleCurrentItems()

        itemsByIndexPath.removeAll()
        orderedIndexPaths.removeAll()

        let sectionCount = winMainActor { dataSource?.numberOfSections(in: self) } ?? 0
        for section in 0..<sectionCount {
            let itemCount = winMainActor { dataSource?.collectionView(self, numberOfItemsInSection: section) } ?? 0
            for itemIndex in 0..<itemCount {
                let indexPath = IndexPath(item: itemIndex, section: section)
                guard let item = winMainActor({ dataSource?.collectionView(self, itemForRepresentedObjectAt: indexPath) }) else {
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
        rebuildSupplementaryViews()
        tile()
    }

    /// Lays out visible item views, delegating to `collectionViewLayout` when
    /// set (AppKit flow/custom layout) and falling back to the built-in grid.
    open func tile() {
        if let layout = collectionViewLayout {
            layout.prepare()
            for (indexPath, item) in itemsByIndexPath {
                if let attr = layout.layoutAttributesForItem(at: indexPath) {
                    item.view.frame = attr.frame
                }
            }
            positionSupplementaryViews(with: layout)
            sizeToContentIfScrolled(layout.collectionViewContentSize)
            return
        }

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

    /// When the collection view is a scroll view's document view, grows it to
    /// the layout's content size so the scroll view can scroll the items.
    private func sizeToContentIfScrolled(_ contentSize: NSSize) {
        guard let scrollView = enclosingScrollView else {
            return
        }
        let width = max(scrollView.contentView.bounds.size.width, contentSize.width)
        let height = max(scrollView.contentView.bounds.size.height, contentSize.height)
        if frame.size.width != width || frame.size.height != height {
            frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: width, height: height)
        }
        scrollView.tile()
    }

    /// (Re)builds the hosted supplementary views the data source vends, keyed by
    /// a per-section header/footer slot. Called only when the *set* of views can
    /// change (`reloadData`, layout swap) — NOT on every `tile()`. Between
    /// rebuilds the views are reused and merely repositioned, so re-layout
    /// (item-size/spacing changes, scrolling) never re-asks the data source or
    /// re-allocates supplementary views.
    ///
    /// Views the data source vends now come from `makeSupplementaryView`, so
    /// retire each one into the reuse pool here (keyed by the kind its slot
    /// encodes plus the identifier `makeSupplementaryView` stamped on it) rather
    /// than dropping it — otherwise every rebuild would allocate afresh.
    private func rebuildSupplementaryViews() {
        for (key, view) in hostedSupplementaryViews {
            view.removeFromSuperview()
            let kind = (key % 2 == 0) ? Self.elementKindSectionHeader : Self.elementKindSectionFooter
            if let identifier = view.identifier {
                supplementaryReusePool[supplementaryKey(kind, identifier), default: []].append(view)
            }
        }
        hostedSupplementaryViews.removeAll()

        // Supplementary views are layout-driven; the built-in grid has none.
        guard collectionViewLayout != nil else {
            return
        }

        let sectionCount = winMainActor { dataSource?.numberOfSections(in: self) } ?? 0
        for section in 0..<sectionCount {
            let indexPath = IndexPath(item: 0, section: section)
            for (offset, kind) in [Self.elementKindSectionHeader, Self.elementKindSectionFooter].enumerated() {
                guard let view = winMainActor({ dataSource?.collectionView(self, viewForSupplementaryElementOfKind: kind, at: indexPath) }) else {
                    continue
                }
                addSubview(view)
                // Key headers and footers into disjoint slots per section.
                hostedSupplementaryViews[section * 2 + offset] = view
            }
        }
    }

    /// Repositions the already-hosted supplementary views to their current
    /// layout frames. A view the layout no longer reserves space for collapses
    /// to a zero frame (kept alive for reuse rather than destroyed).
    private func positionSupplementaryViews(with layout: NSCollectionViewLayout) {
        for (key, view) in hostedSupplementaryViews {
            let section = key / 2
            let kind = (key % 2 == 0) ? Self.elementKindSectionHeader : Self.elementKindSectionFooter
            if let attr = layout.layoutAttributesForSupplementaryView(ofKind: kind, at: IndexPath(item: 0, section: section)) {
                view.frame = attr.frame
            } else {
                view.frame = .zero
            }
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
            winMainActor { delegate?.collectionView(self, didSelectItemsAt: selected) }
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
            winMainActor { delegate?.collectionView(self, didDeselectItemsAt: deselected) }
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
            winMainActor { delegate?.collectionView(self, didDeselectItemsAt: oldSelection) }
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
            let previousAction = control.winInternalAction
            control.winInternalAction = { [weak self, weak control] _ in
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

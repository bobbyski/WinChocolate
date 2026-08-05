import Foundation

/// AppKit-shaped collection data source. This slice renders items as text
/// tiles: `representedObjectForItemAt` supplies each item's content (AppKit's
/// full `NSCollectionViewItem` view-controller pipeline is a later parity item).
public protocol NSCollectionViewDataSource: AnyObject {
    /// The number of items in `section`.
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int
    /// The item content at a flat index (text-tile pipeline).
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any?
    /// The number of sections. Optional (defaulted to 1), as on Apple.
    func numberOfSections(in collectionView: NSCollectionView) -> Int
    /// AppKit's view-controller item shape. Optional (defaulted); when a data
    /// source implements it instead of `representedObjectForItemAt`, the
    /// default below bridges the item's text into the text-tile pipeline.
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem
    /// AppKit's supplementary header/footer hook. Optional (defaulted).
    ///
    /// Returns non-optional `NSView`, exactly as Apple declares it. The view
    /// MUST come from `makeSupplementaryView(ofKind:withIdentifier:for:)` —
    /// real AppKit raises an assertion for any other view (see Issue N in
    /// `Docs/AppKitFaithfulnessIssues.md`).
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView
}

public extension NSCollectionViewDataSource {
    /// Default: bridges AppKit-shaped sources by building the item and pulling its text.
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any? {
        // Bridge AppKit-shaped sources: build the item and pull its text.
        let item = self.collectionView(collectionView, itemForRepresentedObjectAt: IndexPath(item: index, section: 0))
        return item.textField?.stringValue ?? item.representedObject
    }
    /// Default: one section.
    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    /// Default: an empty `NSCollectionViewItem`.
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        NSCollectionViewItem()
    }
    /// Default: a zero-frame placeholder view.
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        NSView(frame: .zero)
    }
}

/// AppKit-shaped grid collection (GtkGridView in a scroller, 3–4 columns).
/// Single-item selection in this slice.
open class NSCollectionView: NSView {

    /// The kind of a supplementary view (header/footer). AppKit declares this
    /// as a `String` typealias, not a distinct type.
    public typealias SupplementaryElementKind = String

    /// The supplementary element kind for a section header.
    ///
    /// The `UI` prefix is not a typo: AppKit's collection view is built on the
    /// UICollectionView implementation, and these are the exact strings Apple
    /// vends. Verified by printing them from real AppKit.
    public static let elementKindSectionHeader: SupplementaryElementKind = "UICollectionElementKindSectionHeader"

    /// The supplementary element kind for a section footer.
    public static let elementKindSectionFooter: SupplementaryElementKind = "UICollectionElementKindSectionFooter"

    /// The insertion-gap indicator kind requested during drag sessions.
    public static let elementKindInterItemGapIndicator: SupplementaryElementKind = "NSCollectionElementKindInterItemGapIndicator"

    /// Supplies item count and content. Assigning reloads.
    public weak var dataSource: NSCollectionViewDataSource? {
        didSet { reloadData() }
    }

    /// Classes registered for supplementary views, keyed by kind+identifier.
    private var supplementaryClasses: [String: NSView.Type] = [:]

    /// Recycled supplementary views, keyed by kind+identifier.
    private var supplementaryReusePool: [String: [NSView]] = [:]

    private func supplementaryKey(_ kind: SupplementaryElementKind,
                                  _ identifier: NSUserInterfaceItemIdentifier) -> String {
        // \u{1} can't occur in either component, so the join is unambiguous.
        "\(kind)\u{1}\(identifier.rawValue)"
    }

    /// Registers `viewClass` as the class to instantiate when the data source
    /// asks for a supplementary view of `kind` with `identifier`. Passing nil
    /// unregisters. Mirrors AppKit exactly.
    ///
    /// Instantiating the class from its metatype is why `NSView.init(frame:)`
    /// is `required` — see Issue N in `Docs/AppKitFaithfulnessIssues.md`.
    public func register(_ viewClass: AnyClass?,
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

    /// Returns a supplementary view of `kind` for `identifier`, recycling one
    /// when available. The data source MUST vend its header/footer views from
    /// here rather than constructing them: real AppKit asserts otherwise, and
    /// matching that contract is the whole point of this API.
    public func makeSupplementaryView(ofKind kind: SupplementaryElementKind,
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
                no class registered for supplementary view of kind '\(kind)' \
                with identifier '\(identifier.rawValue)' — call \
                register(_:forSupplementaryViewOfKind:withIdentifier:) first
                """)
        }
        let view = viewType.init(frame: .zero)
        view.identifier = identifier
        return view
    }

    private var backingSelection = -1

    /// The selected item indexes (AppKit shape; single selection for now).
    public var selectionIndexes: IndexSet {
        backingSelection >= 0 ? IndexSet(integer: backingSelection) : IndexSet()
    }

    /// The selected item index (−1 when nothing is selected).
    public var selectedIndex: Int { backingSelection }

    /// Called when the user changes the selection.
    public var onSelectionChange: ((NSCollectionView) -> Void)?

    /// Layout + delegate (accepted for API parity; the grid layout is native).
    public var collectionViewLayout: NSCollectionViewLayout?

    /// The collection delegate; selections arrive via
    /// `collectionView(_:didSelectItemsAt:)`, as on Apple.
    public weak var delegate: NSCollectionViewDelegate?
    /// Selects the given items (accepted for API parity; not yet implemented).
    public func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: Int) {}

    /// The materialized items, in index order — what Apple's collection keeps
    /// and `item(at:)` returns. Rebuilt by `reloadData()`.
    private var materializedItems: [NSCollectionViewItem] = []

    /// The item at `indexPath` (AppKit's `item(at:)`), nil when out of range.
    public func item(at indexPath: IndexPath) -> NSCollectionViewItem? {
        // Flatten section+item the same way `reloadData` materialized them.
        var flat = indexPath.item
        for section in 0..<min(indexPath.section, sectionItemCounts.count) {
            flat += sectionItemCounts[section]
        }
        return materializedItems.indices.contains(flat) ? materializedItems[flat] : nil
    }

    /// The item at a flat index.
    public func item(at index: Int) -> NSCollectionViewItem? {
        materializedItems.indices.contains(index) ? materializedItems[index] : nil
    }

    /// The selected item index paths (AppKit's shape; single selection).
    public var selectionIndexPaths: Set<IndexPath> {
        get { backingSelection >= 0 ? [indexPath(forFlatIndex: backingSelection)] : [] }
        set { backingSelection = newValue.first?.item ?? -1 }
    }

    /// Creates an empty collection view.
    public required init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createCollectionView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        // Items host their real views (Apple's model: the demo's items are
        // push buttons, and they must render as buttons). Items with a
        // zero-frame view fall back to the text provider below.
        backend.setCollectionItemViewProvider(for: handle) { [weak self] index in
            guard let self, self.materializedItems.indices.contains(index) else { return nil }
            let view = self.materializedItems[index].view
            guard view.frame.size != .zero else { return nil }
            return view.handle
        }
        backend.setCollectionItemProvider(for: handle) { [weak self] index in
            guard let self, let dataSource = self.dataSource else { return "" }
            let value = dataSource.collectionView(self, representedObjectForItemAt: index)
            return value.map { String(describing: $0) } ?? ""
        }
        backend.setSelectionChangeAction(for: handle) { [weak self] index in
            guard let self else { return }
            self.backingSelection = index      // sync silently
            if let item = self.item(at: index) { item.isSelected = true }
            self.onSelectionChange?(self)
            if index >= 0 {
                self.delegate?.collectionView(self, didSelectItemsAt: [self.indexPath(forFlatIndex: index)])
            }
        }
    }

    /// Re-queries the data source, materializing every item (they host real
    /// views), and re-renders.
    public func reloadData() {
        guard let dataSource else {
            materializedItems = []
            sectionItemCounts = []
            backend.setCollectionItemCount(0, for: handle)
            return
        }
        // AppKit decides whether a section HAS a header/footer from the layout's
        // reference size — a zero height means "no band", and the data source is
        // never asked. Honour that, or every collection would sprout bands.
        let flow = collectionViewLayout as? NSCollectionViewFlowLayout
        // Which dimension of the reference size matters depends on the scroll
        // direction: a vertically scrolling collection puts full-width bands
        // above/below its sections (their HEIGHT), while a horizontally
        // scrolling one puts full-height bands beside them (their WIDTH). The
        // demo's `NSMakeSize(0, 24)` therefore means "bands when scrolling
        // vertically, none when scrolling horizontally" — which is exactly what
        // AppKit renders.
        let scrollsHorizontally = flow?.scrollDirection == .horizontal
        let headerExtent = scrollsHorizontally
            ? (flow?.headerReferenceSize.width ?? 0) : (flow?.headerReferenceSize.height ?? 0)
        let footerExtent = scrollsHorizontally
            ? (flow?.footerReferenceSize.width ?? 0) : (flow?.footerReferenceSize.height ?? 0)
        let wantsHeader = headerExtent > 0
        let wantsFooter = footerExtent > 0

        let sectionCount = max(1, dataSource.numberOfSections(in: self))
        materializedItems = []
        sectionItemCounts = []
        supplementaryViews = []
        var specs: [NativeCollectionSection] = []

        for section in 0..<sectionCount {
            let count = dataSource.collectionView(self, numberOfItemsInSection: section)
            let path = IndexPath(item: 0, section: section)
            var header: NSView?
            var footer: NSView?
            if wantsHeader {
                header = dataSource.collectionView(
                    self, viewForSupplementaryElementOfKind: Self.elementKindSectionHeader, at: path)
            }
            if wantsFooter {
                footer = dataSource.collectionView(
                    self, viewForSupplementaryElementOfKind: Self.elementKindSectionFooter, at: path)
            }
            // Items are materialized FLAT, in section order — the backend's
            // view/text providers address them by that flat index.
            for item in 0..<count {
                let path = IndexPath(item: item, section: section)
                let collectionItem = dataSource.collectionView(self, itemForRepresentedObjectAt: path)
                // AppKit sizes each item from the layout — uniform `itemSize`, or
                // the flow delegate's per-item override. Without this the item's
                // own construction size sticks and the layout controls do nothing.
                if let flow {
                    var size = (delegate as? NSCollectionViewDelegateFlowLayout)?
                        .collectionView(self, layout: flow, sizeForItemAt: path) ?? .zero
                    if size == .zero { size = flow.itemSize }
                    if size != .zero {
                        collectionItem.view.frame = NSMakeRect(0, 0, size.width, size.height)
                    }
                }
                materializedItems.append(collectionItem)
            }
            sectionItemCounts.append(count)
            // Hold the bands: they are plain Swift views whose native widgets the
            // collection only hosts, so something must keep them alive.
            if let header { supplementaryViews.append(header) }
            if let footer { supplementaryViews.append(footer) }
            specs.append(NativeCollectionSection(header: header?.handle,
                                                 footer: footer?.handle,
                                                 itemCount: count))
        }
        if let flow {
            backend.setCollectionFlow(interitemSpacing: Double(flow.minimumInteritemSpacing),
                                      lineSpacing: Double(flow.minimumLineSpacing),
                                      horizontal: flow.scrollDirection == .horizontal,
                                      for: handle)
        }
        backend.setCollectionSections(specs, for: handle)
    }

    /// Items per section, in order — maps a flat index to an `IndexPath`.
    private var sectionItemCounts: [Int] = []
    /// The section bands currently hosted (retained; the backend only hosts them).
    private var supplementaryViews: [NSView] = []

    /// Converts a flat item index into its `IndexPath` (AppKit's addressing).
    func indexPath(forFlatIndex index: Int) -> IndexPath {
        var remaining = index
        for (section, count) in sectionItemCounts.enumerated() {
            if remaining < count { return IndexPath(item: remaining, section: section) }
            remaining -= count
        }
        return IndexPath(item: index, section: 0)
    }
}


/// AppKit's collection delegate (the selection slice the demo drives).
public protocol NSCollectionViewDelegate: AnyObject {
    /// Called after the user changes the selection.
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>)
}

public extension NSCollectionViewDelegate {
    /// Default: no-op.
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {}
}

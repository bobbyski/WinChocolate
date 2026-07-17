import Foundation

/// AppKit-shaped collection data source. This slice renders items as text
/// tiles: `representedObjectForItemAt` supplies each item's content (AppKit's
/// full `NSCollectionViewItem` view-controller pipeline is a later parity item).
public protocol NSCollectionViewDataSource: AnyObject {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int
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
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any? {
        // Bridge AppKit-shaped sources: build the item and pull its text.
        let item = self.collectionView(collectionView, itemForRepresentedObjectAt: IndexPath(item: index, section: 0))
        return item.textField?.stringValue ?? item.representedObject
    }
    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        NSCollectionViewItem()
    }
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
            reused.identifier = identifier.rawValue
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
        view.identifier = identifier.rawValue
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
    public func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: Int) {}

    /// Creates an empty collection view.
    public required init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createCollectionView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setCollectionItemProvider(for: handle) { [weak self] index in
            guard let self, let dataSource = self.dataSource else { return "" }
            let value = dataSource.collectionView(self, representedObjectForItemAt: index)
            return value.map { String(describing: $0) } ?? ""
        }
        backend.setSelectionChangeAction(for: handle) { [weak self] index in
            guard let self else { return }
            self.backingSelection = index      // sync silently
            self.onSelectionChange?(self)
            if index >= 0 {
                self.delegate?.collectionView(self, didSelectItemsAt: [IndexPath(item: index, section: 0)])
            }
        }
    }

    /// Re-queries the data source and re-renders the tiles.
    public func reloadData() {
        let count = dataSource?.collectionView(self, numberOfItemsInSection: 0) ?? 0
        backend.setCollectionItemCount(count, for: handle)
    }
}


/// AppKit's collection delegate (the selection slice the demo drives).
public protocol NSCollectionViewDelegate: AnyObject {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>)
}

public extension NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {}
}

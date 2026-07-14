import Foundation

/// AppKit-shaped collection data source. This slice renders items as text
/// tiles: `representedObjectForItemAt` supplies each item's content (AppKit's
/// full `NSCollectionViewItem` view-controller pipeline is a later parity item).
public protocol NSCollectionViewDataSource: AnyObject {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any?
    /// AppKit's view-controller item shape. Optional (defaulted); when a data
    /// source implements it instead of `representedObjectForItemAt`, the
    /// default below bridges the item's text into the text-tile pipeline.
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem
    /// AppKit's supplementary header/footer hook. Optional (defaulted).
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView?
}

public extension NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any? {
        // Bridge AppKit-shaped sources: build the item and pull its text.
        let item = self.collectionView(collectionView, itemForRepresentedObjectAt: IndexPath(item: index, section: 0))
        return item.textField?.stringValue ?? item.representedObject
    }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        NSCollectionViewItem()
    }
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView? { nil }
}

/// AppKit-shaped grid collection (GtkGridView in a scroller, 3–4 columns).
/// Single-item selection in this slice.
public final class NSCollectionView: NSView {

    /// Supplies item count and content. Assigning reloads.
    public weak var dataSource: NSCollectionViewDataSource? {
        didSet { reloadData() }
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
    public weak var delegate: (AnyObject)?
    public func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: Int) {}

    /// Creates an empty collection view.
    public override init(frame: NSRect) {
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
        }
    }

    /// Re-queries the data source and re-renders the tiles.
    public func reloadData() {
        let count = dataSource?.collectionView(self, numberOfItemsInSection: 0) ?? 0
        backend.setCollectionItemCount(count, for: handle)
    }
}

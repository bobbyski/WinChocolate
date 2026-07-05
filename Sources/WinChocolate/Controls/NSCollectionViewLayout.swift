/// The computed geometry for one collection-view item or supplementary view.
open class NSCollectionViewLayoutAttributes {
    /// The item's frame in the collection view's coordinate space.
    open var frame: NSRect = .zero

    /// The index path this attribute describes.
    open var indexPath: IndexPath

    /// The supplementary element kind (e.g. a section header), or `nil` for a
    /// regular item.
    open var representedElementKind: String?

    public init(forItemWith indexPath: IndexPath) {
        self.indexPath = indexPath
    }
}

/// Abstract base for collection-view layouts. A layout maps index paths to
/// frames and reports the total content size the collection view scrolls.
open class NSCollectionViewLayout {
    /// The collection view this layout arranges (set when assigned).
    open weak var collectionView: NSCollectionView?

    public init() {}

    /// Recomputes cached geometry. Called before laying out.
    open func prepare() {}

    /// The frame geometry for an item, or `nil` when unknown.
    open func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        nil
    }

    /// The frame geometry for a supplementary view (e.g. a section header).
    open func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        nil
    }

    /// The total size the content occupies (drives scrolling).
    open var collectionViewContentSize: NSSize {
        .zero
    }
}

/// The scrolling axis a flow layout wraps against.
public enum NSCollectionViewScrollDirection: Sendable {
    case vertical
    case horizontal
}

/// A line-wrapping grid layout, matching `NSCollectionViewFlowLayout`.
///
/// Items flow left-to-right into rows (vertical scroll) or top-to-bottom into
/// columns (horizontal scroll), wrapping when the next item would exceed the
/// available extent. Each section is inset and stacked after the previous one.
open class NSCollectionViewFlowLayout: NSCollectionViewLayout {
    public override init() {
        super.init()
    }

    /// The size for every item (per-item sizing via delegate is a follow-up).
    open var itemSize: NSSize = NSMakeSize(112, 34) {
        didSet { collectionView?.tile() }
    }

    /// Minimum spacing between items on the same line.
    open var minimumInteritemSpacing: CGFloat = 8 {
        didSet { collectionView?.tile() }
    }

    /// Minimum spacing between lines.
    open var minimumLineSpacing: CGFloat = 8 {
        didSet { collectionView?.tile() }
    }

    /// Margin around each section's items.
    open var sectionInset: NSEdgeInsets = NSEdgeInsetsMake(0, 0, 0, 0) {
        didSet { collectionView?.tile() }
    }

    /// The axis items wrap against.
    open var scrollDirection: NSCollectionViewScrollDirection = .vertical {
        didSet { collectionView?.tile() }
    }

    /// The size reserved for each section's header supplementary view. Height is
    /// used for vertical scroll, width for horizontal. `.zero` = no headers.
    open var headerReferenceSize: NSSize = .zero {
        didSet { collectionView?.tile() }
    }

    private var attributes: [IndexPath: NSCollectionViewLayoutAttributes] = [:]
    private var headerAttributes: [Int: NSCollectionViewLayoutAttributes] = [:]
    private var contentSize: NSSize = .zero

    open override var collectionViewContentSize: NSSize {
        contentSize
    }

    open override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        attributes[indexPath]
    }

    open override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard elementKind == NSCollectionView.elementKindSectionHeader else {
            return nil
        }
        return headerAttributes[indexPath.section]
    }

    open override func prepare() {
        attributes.removeAll()
        headerAttributes.removeAll()
        guard let collectionView, let dataSource = collectionView.dataSource else {
            contentSize = .zero
            return
        }

        // The available cross-axis extent: width for vertical scroll (viewport
        // or item width, whichever is larger), height for horizontal scroll.
        let viewport = collectionView.enclosingScrollView?.contentView.bounds.size ?? collectionView.frame.size
        let sectionCount = dataSource.numberOfSections(in: collectionView)

        // Per-item size hook (variable-size flow), falling back to `itemSize`.
        let flowDelegate = collectionView.delegate as? NSCollectionViewDelegateFlowLayout
        func size(at indexPath: IndexPath) -> NSSize {
            if let delegateSize = flowDelegate?.collectionView(collectionView, layout: self, sizeForItemAt: indexPath),
               delegateSize.width > 0, delegateSize.height > 0 {
                return delegateSize
            }
            return itemSize
        }

        if scrollDirection == .vertical {
            let available = max(itemSize.width, viewport.width)
            var y: CGFloat = 0
            var maxX: CGFloat = 0
            for section in 0..<sectionCount {
                // Section header spans the full width at the top of the section.
                if headerReferenceSize.height > 0 {
                    let header = NSCollectionViewLayoutAttributes(forItemWith: IndexPath(item: 0, section: section))
                    header.representedElementKind = NSCollectionView.elementKindSectionHeader
                    header.frame = NSMakeRect(0, y, available, headerReferenceSize.height)
                    headerAttributes[section] = header
                    y += headerReferenceSize.height
                    maxX = max(maxX, available)
                }
                y += sectionInset.top
                let count = dataSource.collectionView(collectionView, numberOfItemsInSection: section)
                let rightEdge = available - sectionInset.right
                var x = sectionInset.left
                var lineHeight: CGFloat = 0
                var firstInLine = true
                for itemIndex in 0..<count {
                    let indexPath = IndexPath(item: itemIndex, section: section)
                    let itemSize = size(at: indexPath)
                    // Wrap to a new line when the item would overflow the row.
                    if !firstInLine, x + itemSize.width > rightEdge {
                        y += lineHeight + minimumLineSpacing
                        x = sectionInset.left
                        lineHeight = 0
                        firstInLine = true
                    }
                    let attr = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
                    attr.frame = NSMakeRect(x, y, itemSize.width, itemSize.height)
                    attributes[indexPath] = attr
                    maxX = max(maxX, x + itemSize.width)
                    x += itemSize.width + minimumInteritemSpacing
                    lineHeight = max(lineHeight, itemSize.height)
                    firstInLine = false
                }
                y += lineHeight + sectionInset.bottom
            }
            contentSize = NSMakeSize(max(available, maxX + sectionInset.right), y)
        } else {
            let available = max(itemSize.height, viewport.height)
            var x: CGFloat = 0
            var maxY: CGFloat = 0
            for section in 0..<sectionCount {
                x += sectionInset.left
                let count = dataSource.collectionView(collectionView, numberOfItemsInSection: section)
                let usable = max(itemSize.height, available - sectionInset.top - sectionInset.bottom)
                let perColumn = max(1, Int((usable + minimumLineSpacing) / (itemSize.height + minimumLineSpacing)))
                for itemIndex in 0..<count {
                    let row = itemIndex % perColumn
                    let col = itemIndex / perColumn
                    let itemX = x + CGFloat(col) * (itemSize.width + minimumInteritemSpacing)
                    let itemY = sectionInset.top + CGFloat(row) * (itemSize.height + minimumLineSpacing)
                    let attr = NSCollectionViewLayoutAttributes(forItemWith: IndexPath(item: itemIndex, section: section))
                    attr.frame = NSMakeRect(itemX, itemY, itemSize.width, itemSize.height)
                    attributes[attr.indexPath] = attr
                    maxY = max(maxY, itemY + itemSize.height)
                }
                let cols = count == 0 ? 0 : (count - 1) / perColumn + 1
                if cols > 0 {
                    x += CGFloat(cols) * itemSize.width + CGFloat(cols - 1) * minimumInteritemSpacing
                }
                x += sectionInset.right
            }
            contentSize = NSMakeSize(x, max(available, maxY + sectionInset.bottom))
        }
    }
}

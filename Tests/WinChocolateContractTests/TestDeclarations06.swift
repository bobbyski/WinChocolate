import WinChocolate

@MainActor
func testBrowserDrawsBranchIndicatorOnNonLeafRows() {
    let backend = InMemoryNativeControlBackend()
    let browser = NSBrowser(frame: NSMakeRect(0, 0, 320, 120))
    let delegate = LeafBranchBrowserDelegate()
    browser.delegate = delegate
    browser.defaultColumnWidth = 150
    browser.loadColumnZero()
    _ = browser.realizeNativePeer(in: backend, parent: nil)

    // Reach column 0's drawn list (the scroll view's document view).
    guard let column0 = browser.subviews.compactMap({ $0 as? NSScrollView }).first,
          let table = column0.documentView as? NSTableView,
          let handle = table.nativeHandle else {
        fatalError("Browser column 0 table was not realized.")
    }

    // The branch chevron is a 3-point triangle → a 4-segment (move/line/line/close)
    // filled path. Row backgrounds and selection are rectangles (5 segments), so
    // 4-segment fills count the branch indicators exactly. Column 0 has one branch
    // ("Folder") and one leaf ("File") → exactly one chevron.
    let recording = backend.performDraw(for: handle, in: table.bounds)
    let chevrons = recording.fills.filter { $0.segments.count == 4 }
    expect(chevrons.count == 1,
           "Column 0 should draw exactly one branch chevron (Folder, not File). Got \(chevrons.count).")

    // Cell icons are on by default and reserve a leading inset so the title
    // clears them; turning them off zeroes the inset.
    expect(browser.showsCellIcons, "Browser cell icons should be on by default.")
    expect(table.winDrawnLeadingInset(forRow: 0, column: 0) > 0,
           "Cell icons did not reserve a leading inset for the title.")
    browser.showsCellIcons = false
    expect(table.winDrawnLeadingInset(forRow: 0, column: 0) == 0,
           "Turning cell icons off did not release the leading inset.")
}

final class ImageBrowserDelegate: NSObject, NSBrowserDelegate {
    static let iconPath = "C:/icons/file.png"
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? 1 : 0
    }
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any { "File" }
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool { item != nil }
    func browser(_ browser: NSBrowser, imageForItem item: Any?) -> NSImage? {
        NSImage(contentsOfFile: Self.iconPath)
    }
}

@MainActor
func testBrowserDrawsDelegateCellImage() {
    let backend = InMemoryNativeControlBackend()
    let browser = NSBrowser(frame: NSMakeRect(0, 0, 320, 120))
    let delegate = ImageBrowserDelegate()
    browser.delegate = delegate
    browser.defaultColumnWidth = 150
    browser.loadColumnZero()
    _ = browser.realizeNativePeer(in: backend, parent: nil)

    guard let column0 = browser.subviews.compactMap({ $0 as? NSScrollView }).first,
          let table = column0.documentView as? NSTableView,
          let handle = table.nativeHandle else {
        fatalError("Browser column 0 table was not realized.")
    }

    // The single leaf row's cell draws the delegate image (not the built-in glyph).
    let recording = backend.performDraw(for: handle, in: table.bounds)
    expect(recording.images.contains { $0.path == ImageBrowserDelegate.iconPath },
           "Browser did not draw the delegate-provided cell image. Got \(recording.images.map { $0.path }).")
}

@MainActor
func testIndexPathStoresCollectionComponents() {
    let indexPath = IndexPath(item: 3, section: 2)
    let appended = IndexPath(indexes: [1, 4]).appending(9)

    expect(indexPath.section == 2, "IndexPath section component was wrong.")
    expect(indexPath.item == 3, "IndexPath item component was wrong.")
    expect(indexPath.count == 2, "IndexPath count was wrong.")
    expect(indexPath[0] == 2 && indexPath[1] == 3, "IndexPath subscript returned wrong components.")
    expect(appended.count == 3 && appended[2] == 9, "IndexPath appending did not add a component.")
}

@MainActor
func testCollectionViewReloadsItemsAndTracksSelection() {
    let backend = InMemoryNativeControlBackend()
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 260, 96))
    let dataSource = RecordingCollectionDataSource()
    let delegate = RecordingCollectionDelegate()
    var actionCount = 0

    collectionView.dataSource = dataSource
    collectionView.delegate = delegate
    collectionView.itemSize = NSMakeSize(112, 28)
    collectionView.minimumInteritemSpacing = 8
    collectionView.minimumLineSpacing = 6
    collectionView.onAction = { control in
        expect(control === collectionView, "Collection view action sender was not collection view.")
        actionCount += 1
    }

    collectionView.reloadData()

    let first = IndexPath(item: 0, section: 0)
    let secondSection = IndexPath(item: 1, section: 1)
    expect(collectionView.subviews.count == 5, "Collection view did not compose item views.")
    expect(collectionView.item(at: first)?.representedObject as? String == "NSButton", "Collection item lookup returned wrong represented object.")
    let secondItem = requireValue(collectionView.item(at: secondSection), "Collection item should exist.")
    expect(collectionView.indexPath(for: secondItem) == secondSection, "Collection reverse item lookup failed.")

    let handle = collectionView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Collection view did not create a native host view.")
    expect(collectionView.subviews.allSatisfy { $0.nativeHandle != nil }, "Collection item views were not realized.")

    collectionView.selectItems(at: [secondSection])

    expect(collectionView.selectionIndexPaths == [secondSection], "Collection view did not store selection.")
    expect(collectionView.item(at: secondSection)?.isSelected == true, "Collection item did not mark selected state.")
    expect(delegate.selected.contains(secondSection), "Collection delegate did not receive selection.")
    expect(actionCount == 1, "Collection view action was not sent for selection.")

    collectionView.deselectItems(at: [secondSection])

    expect(collectionView.selectionIndexPaths.isEmpty, "Collection view did not deselect item.")
    expect(delegate.deselected.contains(secondSection), "Collection delegate did not receive deselection.")
}

final class ReusingCollectionDataSource: NSObject, NSCollectionViewDataSource {
    static let cellID = NSUserInterfaceItemIdentifier("cell")
    let count: Int
    init(count: Int) { self.count = count }
    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    func collectionView(_ cv: NSCollectionView, numberOfItemsInSection section: Int) -> Int { count }
    func collectionView(_ cv: NSCollectionView, itemForRepresentedObjectAt ip: IndexPath) -> NSCollectionViewItem {
        let item = cv.makeItem(withIdentifier: Self.cellID, for: ip)
        item.representedObject = "item\(ip.item)"
        return item
    }
}

@MainActor
func testCollectionViewRecyclesItemsViaMakeItem() {
    let cv = NSCollectionView(frame: NSMakeRect(0, 0, 260, 200))
    cv.register(NSCollectionViewItem.self, forItemWithIdentifier: ReusingCollectionDataSource.cellID)
    let ds = ReusingCollectionDataSource(count: 3)
    cv.dataSource = ds

    cv.reloadData()
    let firstPass = (0..<3).compactMap { cv.item(at: IndexPath(item: $0, section: 0)) }
    expect(firstPass.count == 3, "First reload did not create 3 items.")
    expect(firstPass.allSatisfy { $0.identifier == ReusingCollectionDataSource.cellID },
           "makeItem did not stamp the reuse identifier on new items.")
    let firstIDs = Set(firstPass.map { ObjectIdentifier($0) })

    cv.reloadData()
    let secondPass = (0..<3).compactMap { cv.item(at: IndexPath(item: $0, section: 0)) }
    let secondIDs = Set(secondPass.map { ObjectIdentifier($0) })

    // The three items are recycled into the pool on the second reload and
    // dequeued again — the same instances, no fresh allocations.
    expect(secondIDs == firstIDs, "Collection items were not recycled across reloads. first=\(firstIDs.count) second=\(secondIDs.count) shared=\(firstIDs.intersection(secondIDs).count)")
    // The recycled views are re-hosted, and the data source repopulated them
    // (after prepareForReuse cleared the represented object).
    expect(cv.subviews.count == 3, "Recycled item views were not re-hosted. Got \(cv.subviews.count).")
    expect(secondPass.allSatisfy { ($0.representedObject as? String)?.hasPrefix("item") == true },
           "Recycled items were not repopulated by the data source.")
}

@MainActor
func testCollectionViewButtonItemClickSelectsItem() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 260, 96))
    let dataSource = RecordingCollectionDataSource()
    let target = IndexPath(item: 2, section: 0)
    var actionCount = 0

    collectionView.dataSource = dataSource
    collectionView.onAction = { _ in
        actionCount += 1
    }
    collectionView.reloadData()

    guard let button = collectionView.item(at: target)?.view as? NSButton else {
        fatalError("Collection data source did not create a button item.")
    }

    button.performClick(nil)

    expect(collectionView.selectionIndexPaths == [target], "Collection button item click did not select its index path.")
    expect(actionCount == 1, "Collection button item click did not send collection action.")
}

@MainActor
func testCollectionViewFlowLayoutArrangesSectionsAndSizesContent() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 230, 200))
    let dataSource = RecordingCollectionDataSource()  // section 0: 3 items, section 1: 2 items
    let layout = NSCollectionViewFlowLayout()
    layout.itemSize = NSMakeSize(100, 30)
    layout.minimumInteritemSpacing = 10
    layout.minimumLineSpacing = 10
    layout.sectionInset = NSEdgeInsetsMake(5, 5, 5, 5)

    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = layout
    collectionView.reloadData()

    // Usable width 230-5-5=220 → 2 items per line ((220+10)/(100+10)=2).
    // Section 0: item0 (5,5), item1 (115,5), item2 wraps to (5,45).
    let a00 = layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))
    let a01 = layout.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))
    let a02 = layout.layoutAttributesForItem(at: IndexPath(item: 2, section: 0))
    expect(a00?.frame == NSMakeRect(5, 5, 100, 30), "Flow item (0,0) frame wrong. Got \(a00?.frame ?? .zero).")
    expect(a01?.frame == NSMakeRect(115, 5, 100, 30), "Flow item (1,0) did not sit beside the first. Got \(a01?.frame ?? .zero).")
    expect(a02?.frame == NSMakeRect(5, 45, 100, 30), "Flow item (2,0) did not wrap to the next line. Got \(a02?.frame ?? .zero).")

    // Section 1 starts below section 0 (section 0 used 2 lines = 70pt, + insets).
    // y after section 0 = 5(top)+70+5(bottom) = 80; section 1 top inset 5 → 85.
    let a10 = layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 1))
    expect(a10?.frame == NSMakeRect(5, 85, 100, 30), "Second section did not stack below the first. Got \(a10?.frame ?? .zero).")

    // The item views were positioned to match.
    expect(collectionView.item(at: IndexPath(item: 2, section: 0))?.view.frame == NSMakeRect(5, 45, 100, 30),
           "Flow layout did not position the wrapped item's view.")

    // Content grows to the full stacked height (section 1 bottom = 85+30+5 = 120).
    expect(layout.collectionViewContentSize.height == 120, "Flow content height wrong. Got \(layout.collectionViewContentSize.height).")
}

final class VariableSizeCollectionDataSource: NSObject, NSCollectionViewDataSource {
    let sizes = [NSMakeSize(80, 20), NSMakeSize(80, 20), NSMakeSize(80, 30), NSMakeSize(60, 20)]
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { sizes.count }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        item.view = NSView(frame: NSMakeRect(0, 0, sizes[indexPath.item].width, sizes[indexPath.item].height))
        return item
    }
}

final class VariableSizeFlowDelegate: NSObject, NSCollectionViewDelegateFlowLayout {
    let sizes: [NSSize]
    init(_ sizes: [NSSize]) { self.sizes = sizes }
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        sizes[indexPath.item]
    }
}

@MainActor
func testCollectionFlowLayoutHonorsPerItemSizeFromDelegate() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 200, 200))
    let dataSource = VariableSizeCollectionDataSource()
    let delegate = VariableSizeFlowDelegate(dataSource.sizes)
    let layout = NSCollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    layout.sectionInset = NSEdgeInsetsMake(0, 0, 0, 0)

    collectionView.dataSource = dataSource
    collectionView.delegate = delegate
    collectionView.collectionViewLayout = layout
    collectionView.reloadData()

    // 200pt wide: items 0,1 (80+80=160) fit on line 0; item 2 (80) overflows to
    // line 1 (which is 30pt tall because item 2 is taller); item 3 (60) fits beside it.
    let f0 = layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame
    let f1 = layout.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))?.frame
    let f2 = layout.layoutAttributesForItem(at: IndexPath(item: 2, section: 0))?.frame
    let f3 = layout.layoutAttributesForItem(at: IndexPath(item: 3, section: 0))?.frame
    expect(f0 == NSMakeRect(0, 0, 80, 20), "Item 0 frame wrong. Got \(f0 ?? .zero).")
    expect(f1 == NSMakeRect(80, 0, 80, 20), "Item 1 did not pack beside item 0. Got \(f1 ?? .zero).")
    expect(f2 == NSMakeRect(0, 20, 80, 30), "Item 2 did not wrap to the next line. Got \(f2 ?? .zero).")
    expect(f3 == NSMakeRect(80, 20, 60, 20), "Item 3 did not pack beside item 2. Got \(f3 ?? .zero).")
    expect(layout.collectionViewContentSize.height == 50, "Variable-size content height wrong (line0 20 + line1 30). Got \(layout.collectionViewContentSize.height).")

    // The item views were positioned to their variable sizes.
    expect(collectionView.item(at: IndexPath(item: 2, section: 0))?.view.frame == NSMakeRect(0, 20, 80, 30),
           "Item 2's view was not positioned at its variable size/frame.")
}

final class HeaderCollectionDataSource: NSObject, NSCollectionViewDataSource {
    var headerViews: [Int: NSView] = [:]
    func numberOfSections(in collectionView: NSCollectionView) -> Int { 2 }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { 2 }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        item.view = NSView(frame: NSMakeRect(0, 0, 100, 20))
        return item
    }
    var footerViews: [Int: NSView] = [:]
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView {
        if kind == NSCollectionView.elementKindSectionHeader {
            let header = NSTextField(string: "Section \(indexPath.section)", frame: .zero)
            headerViews[indexPath.section] = header
            return header
        }
        if kind == NSCollectionView.elementKindSectionFooter {
            let footer = NSTextField(string: "Footer \(indexPath.section)", frame: .zero)
            footerViews[indexPath.section] = footer
            return footer
        }
        return NSView()
    }
}

final class CountingSupplementaryDataSource: NSObject, NSCollectionViewDataSource {
    private(set) var vendCount = 0
    func numberOfSections(in collectionView: NSCollectionView) -> Int { 2 }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { 2 }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        item.view = NSView(frame: NSMakeRect(0, 0, 100, 20))
        return item
    }
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView {
        vendCount += 1
        return NSTextField(string: "\(kind)-\(indexPath.section)", frame: .zero)
    }
}

@MainActor
func testCollectionRecyclesSupplementaryViewsAcrossRelayout() {
    let backend = InMemoryNativeControlBackend()
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 240, 200))
    let dataSource = CountingSupplementaryDataSource()
    collectionView.dataSource = dataSource
    let layout = NSCollectionViewFlowLayout()
    layout.itemSize = NSMakeSize(100, 20)
    layout.headerReferenceSize = NSMakeSize(0, 18)
    layout.footerReferenceSize = NSMakeSize(0, 14)
    collectionView.collectionViewLayout = layout
    _ = collectionView.realizeNativePeer(in: backend, parent: nil)
    collectionView.reloadData()

    let afterReload = dataSource.vendCount
    expect(afterReload > 0, "Supplementary views were not vended on reload. Got \(afterReload).")

    // A re-layout (item-size change → tile, not reloadData) must NOT re-ask the
    // data source: the supplementary views are recycled and merely repositioned.
    collectionView.itemSize = NSMakeSize(80, 24)
    collectionView.minimumLineSpacing = 12
    expect(dataSource.vendCount == afterReload,
           "Re-layout re-vended supplementary views instead of recycling them. \(afterReload) → \(dataSource.vendCount).")

    // A reloadData rebuilds them (a fresh vend).
    collectionView.reloadData()
    expect(dataSource.vendCount > afterReload, "reloadData did not rebuild supplementary views.")
}

final class HorizontalSizeCollectionDataSource: NSObject, NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { 3 }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        item.view = NSView(frame: NSMakeRect(0, 0, 30, 40))
        return item
    }
}

@MainActor
func testCollectionFlowLayoutReservesSectionFooters() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 200, 400))
    let dataSource = HeaderCollectionDataSource()
    let layout = NSCollectionViewFlowLayout()
    layout.itemSize = NSMakeSize(100, 20)
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    layout.sectionInset = NSEdgeInsetsMake(0, 0, 0, 0)
    layout.headerReferenceSize = NSMakeSize(0, 30)
    layout.footerReferenceSize = NSMakeSize(0, 10)

    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = layout
    collectionView.reloadData()

    // Section 0: header 30 + items 20 + footer 10 = 60. Footer sits at y=50.
    let f0 = layout.layoutAttributesForSupplementaryView(ofKind: NSCollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: 0))
    let f1 = layout.layoutAttributesForSupplementaryView(ofKind: NSCollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: 1))
    expect(f0?.frame == NSMakeRect(0, 50, 200, 10), "Section 0 footer frame wrong. Got \(f0?.frame ?? .zero).")
    expect(f1?.frame == NSMakeRect(0, 110, 200, 10), "Section 1 footer did not stack after section 0's footer. Got \(f1?.frame ?? .zero).")
    expect(layout.collectionViewContentSize.height == 120, "Footer-inclusive content height wrong. Got \(layout.collectionViewContentSize.height).")
    expect(dataSource.footerViews.count == 2, "Two footers should have been vended. Got \(dataSource.footerViews.count).")
    expect(collectionView.subviews.contains { $0 === dataSource.footerViews[0] }, "Section 0 footer view was not hosted.")
}

@MainActor
func testCollectionSupplementaryViewsHostInRealizedScrollView() {
    // Mirrors the demo: collection is a scroll-view document view, realized.
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 300, 200))
    scrollView.hasVerticalScroller = true
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 300, 200))
    let dataSource = HeaderCollectionDataSource()
    let layout = NSCollectionViewFlowLayout()
    layout.itemSize = NSMakeSize(100, 20)
    layout.headerReferenceSize = NSMakeSize(0, 24)
    layout.footerReferenceSize = NSMakeSize(0, 16)
    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = layout
    scrollView.documentView = collectionView
    collectionView.reloadData()

    _ = scrollView.realizeNativePeer(in: backend, parent: nil)

    // Both the header and footer views are hosted as realized subviews.
    expect(collectionView.subviews.contains { $0 === dataSource.headerViews[0] }, "Header not hosted in the realized scroll view.")
    expect(collectionView.subviews.contains { $0 === dataSource.footerViews[0] }, "Footer not hosted in the realized scroll view.")
    expect(dataSource.footerViews[0]?.nativeHandle != nil, "Footer view was not realized.")
    // The footer sits below the header + its section's item row.
    let footerFrame = dataSource.footerViews[0]?.frame ?? .zero
    expect(footerFrame.origin.y > 24, "Footer was not positioned below the header. Got \(footerFrame).")
    expect(footerFrame.size.height == 16, "Footer height wrong. Got \(footerFrame.size.height).")
}

@MainActor
func testCollectionFlowLayoutHorizontalVariableSizePacking() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 200, 100))
    let dataSource = HorizontalSizeCollectionDataSource()
    let delegate = VariableSizeFlowDelegate([NSMakeSize(30, 40), NSMakeSize(30, 40), NSMakeSize(30, 40)])
    let layout = NSCollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    layout.sectionInset = NSEdgeInsetsMake(0, 0, 0, 0)

    collectionView.dataSource = dataSource
    collectionView.delegate = delegate
    collectionView.collectionViewLayout = layout
    collectionView.reloadData()

    // Viewport 100 tall: items 0,1 (40+40=80) stack in column 0; item 2 (would
    // reach 120) wraps to column 1 at x=30.
    let a0 = layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame
    let a1 = layout.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))?.frame
    let a2 = layout.layoutAttributesForItem(at: IndexPath(item: 2, section: 0))?.frame
    expect(a0 == NSMakeRect(0, 0, 30, 40), "Horizontal item 0 frame wrong. Got \(a0 ?? .zero).")
    expect(a1 == NSMakeRect(0, 40, 30, 40), "Horizontal item 1 did not stack below item 0. Got \(a1 ?? .zero).")
    expect(a2 == NSMakeRect(30, 0, 30, 40), "Horizontal item 2 did not wrap to the next column. Got \(a2 ?? .zero).")
    expect(layout.collectionViewContentSize.width == 60, "Horizontal content width wrong. Got \(layout.collectionViewContentSize.width).")
}

@MainActor
func testCollectionFlowLayoutReservesAndHostsSectionHeaders() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 200, 400))
    let dataSource = HeaderCollectionDataSource()
    let layout = NSCollectionViewFlowLayout()
    layout.itemSize = NSMakeSize(100, 20)
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    layout.sectionInset = NSEdgeInsetsMake(0, 0, 0, 0)
    layout.headerReferenceSize = NSMakeSize(0, 30)

    collectionView.dataSource = dataSource
    collectionView.collectionViewLayout = layout
    collectionView.reloadData()

    // Each section reserves a full-width 30pt header at its top; items follow.
    let h0 = layout.layoutAttributesForSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0))
    let h1 = layout.layoutAttributesForSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 1))
    expect(h0?.frame == NSMakeRect(0, 0, 200, 30), "Section 0 header frame wrong. Got \(h0?.frame ?? .zero).")
    expect(h1?.frame == NSMakeRect(0, 50, 200, 30), "Section 1 header did not stack below section 0's header+items. Got \(h1?.frame ?? .zero).")

    // Items sit below their section header.
    expect(layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame.origin.y == 30,
           "Section 0 items did not start below the header.")
    expect(layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 1))?.frame.origin.y == 80,
           "Section 1 items did not start below the section 1 header.")

    // The header views were vended and hosted at their frames.
    expect(dataSource.headerViews.count == 2, "Two section headers should have been vended. Got \(dataSource.headerViews.count).")
    expect(dataSource.headerViews[1]?.frame == NSMakeRect(0, 50, 200, 30), "Section 1 header view was not positioned at its layout frame.")
    expect(collectionView.subviews.contains { $0 === dataSource.headerViews[0] }, "Section 0 header view was not hosted as a subview.")

    // Content spans both sections (header 30 + items 20) x2 = 100.
    expect(layout.collectionViewContentSize.height == 100, "Header-inclusive content height wrong. Got \(layout.collectionViewContentSize.height).")
}

@MainActor
func testSliderStoresRangeValueAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let slider = NSSlider(value: 25, minValue: 0, maxValue: 100, target: nil, action: "sliderChanged:")
    slider.frame = NSMakeRect(0, 0, 240, 24)

    expect(slider.minValue == 0, "Slider minValue was not stored.")
    expect(slider.maxValue == 100, "Slider maxValue was not stored.")
    expect(slider.doubleValue == 25, "Slider doubleValue was not stored.")
    expect(slider.intValue == 25, "Slider intValue did not follow doubleValue.")
    expect(slider.action == "sliderChanged:", "Slider action selector was not stored.")

    let handle = slider.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "slider", "Slider did not request a native slider peer.")
    expect(backend.records[handle]?.sliderMinValue == 0, "Slider minValue was not synced to native backend.")
    expect(backend.records[handle]?.sliderMaxValue == 100, "Slider maxValue was not synced to native backend.")
    expect(backend.records[handle]?.sliderValue == 25, "Slider value was not synced to native backend.")

    slider.doubleValue = 140
    expect(slider.doubleValue == 100, "Slider did not clamp value to maxValue.")
    expect(backend.records[handle]?.sliderValue == 100, "Slider clamped value was not synced to native backend.")

    slider.minValue = 20
    slider.maxValue = 80
    slider.intValue = 10
    expect(slider.doubleValue == 20, "Slider did not clamp intValue to minValue.")
    expect(backend.records[handle]?.sliderMinValue == 20, "Slider updated minValue was not synced to native backend.")
    expect(backend.records[handle]?.sliderMaxValue == 80, "Slider updated maxValue was not synced to native backend.")

    // tickMarkPosition moves the ticks to the above/leading edge.
    expect(backend.sliderTicksAboveOrLeading[handle] == nil || backend.sliderTicksAboveOrLeading[handle] == false, "Default slider ticks should be below/trailing.")
    slider.tickMarkPosition = .above
    expect(backend.sliderTicksAboveOrLeading[handle] == true, "tickMarkPosition .above did not move ticks above.")
    slider.tickMarkPosition = .below
    expect(backend.sliderTicksAboveOrLeading[handle] == false, "tickMarkPosition .below did not restore ticks below.")
}

@MainActor
func testSliderNativeActionUpdatesValue() {
    let backend = InMemoryNativeControlBackend()
    let slider = NSSlider(value: 1, minValue: 0, maxValue: 10, target: nil, action: nil)
    var actionCount = 0
    slider.onAction = { control in
        guard let slider = control as? NSSlider else {
            expect(false, "Slider action sender was not slider.")
            return
        }

        actionCount += 1
        expect(slider.doubleValue == 7, "Slider action did not read native value.")
    }

    let handle = slider.realizeNativePeer(in: backend, parent: nil)
    backend.setSliderValue(7, for: handle)
    backend.actions[handle]?()

    expect(actionCount == 1, "Slider native action was not dispatched.")
}

@MainActor
func testSpinnerShadeInvertsForDarkAppearance() {
    // The leading dot (age 0) must be dark on light but bright on dark, and the
    // trailing dot (age 11) the reverse — so the sweep stays visible against
    // either background instead of fading into it.
    let lightLead = NSProgressIndicator.winSpinnerShade(age: 0, animating: true, isDark: false)
    let lightTail = NSProgressIndicator.winSpinnerShade(age: 11, animating: true, isDark: false)
    expect(lightLead < 0.3 && lightTail > 0.7, "On light, the leading dot should be dark and the trail light.")

    let darkLead = NSProgressIndicator.winSpinnerShade(age: 0, animating: true, isDark: true)
    let darkTail = NSProgressIndicator.winSpinnerShade(age: 11, animating: true, isDark: true)
    expect(darkLead > 0.7 && darkTail < 0.4, "On dark, the leading dot should be bright and the trail near-dark.")
    expect(darkLead > lightLead, "The dark leading dot must be brighter than the light one to show on the dark surface.")
}


# Rev 2.0 question — `NSCollectionView` supplementary-view recycling

**Status:** open research item for Rev 2.0. Referenced from the project plan
under **Phase 12 — Rev 2.0 Issues** (item 12.x).

**Owner of the interim code:** `Sources/WinChocolate/Controls/NSCollectionView.swift`
(`rebuildSupplementaryViews()` + `positionSupplementaryViews(with:)`).

---

## 1. What AppKit does, and what we deferred

AppKit recycles *supplementary* views (section headers/footers) the same way it
recycles items, through a register + dequeue pair:

```swift
collectionView.register(MyHeaderView.self,
                        forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
                        withIdentifier: id)

// inside the data source:
let view = collectionView.makeSupplementaryView(ofKind: kind,
                                                withIdentifier: id,
                                                for: indexPath)
```

We already implemented this exact pattern for **items** in 5.4
(`register(_:forItemWithIdentifier:)` + `makeItem(withIdentifier:for:)` backed by
a per-identifier reuse pool). We **did not** implement the supplementary-view
equivalent, because it runs into a Swift initializer constraint (see §2). Instead
we shipped an interim recycling scheme (option "C", see §3) that gets the
performance win without the AppKit API surface.

## 2. Why we deferred it — the `required init()` cascade

`makeSupplementaryView` must, on a cache miss, construct a fresh instance of the
**registered class**, which is stored as a metatype:

```swift
var viewClass: NSView.Type          // registered via register(_:forSupplementaryViewOfKind:withIdentifier:)
let view = viewClass.init()         // <-- the problem
```

Swift only allows calling an initializer **through a metatype** if that
initializer is declared **`required`** on the root type — here `NSView`. And
`required` is contagious: it becomes mandatory on **every** subclass.

Today `NSView` has only:

```swift
public init(frame frameRect: NSRect)   // no parameterless init()
```

So to support `register(_ viewClass: NSView.Type, …)` we would need:

```swift
open class NSView {
    public required init() { self.init(frame: .zero) }   // new
}
```

…and then **every** view subclass (`NSControl`, `NSButton`, `NSTextField`,
`NSTableView`, `NSScrollView`, `NSImageView`, `NSCollectionView`, … ~30+ classes)
must add its own `public required init()`.

> This did **not** bite the item recycling in 5.4, because `required init()` there
> lives on `NSCollectionViewItem`, which is **not** an `NSView` and has no
> subclasses in the codebase — so the `required` touched exactly one type.

## 3. What we shipped instead (interim "option C")

Rather than the register/dequeue API, the collection view keeps the
data-source-created supplementary views **alive across layout passes** and only
recreates them when the *set* of views can actually change:

- `rebuildSupplementaryViews()` — removes the old views, asks the data source
  (`viewForSupplementaryElementOfKind`) once per section/kind, adds the new
  views, and stores them keyed by `section * 2 + offset` (offset 0 = header,
  1 = footer). Called **only** from `reloadData()` and from the
  `collectionViewLayout` setter (the two places the view set can change).
- `positionSupplementaryViews(with:)` — on every `tile()` (item-size / spacing
  changes, scrolling, content resize) it just repositions the already-hosted
  views to their new layout frames; a view the layout no longer reserves space
  for collapses to a `.zero` frame but is kept alive.

**Result:** re-layout no longer re-asks the data source or re-allocates
supplementary views (verified by `testCollectionRecyclesSupplementaryViewsAcrossRelayout`,
which asserts the vend count is unchanged after an item-size change and only
grows again on `reloadData`). We get the recycling *performance* benefit without
the AppKit *API*.

**What option C does NOT give us:**

- No `register(_:forSupplementaryViewOfKind:withIdentifier:)` /
  `makeSupplementaryView(ofKind:withIdentifier:for:)` — so real AppKit source
  that dequeues supplementary views won't compile against WinChocolate. This is
  a **source-compat gap**, which matters because source compatibility is the
  project's north star.
- The data source is still asked to *create* the view on every rebuild (reload /
  layout swap); a true reuse pool would hand a recycled instance back instead.

## 4. What Rev 2.0 must do to adopt the AppKit API cleanly

The end state mirrors item recycling exactly. Concretely:

### 4.1 Add the `required init()` to the view hierarchy
- [ ] Add `public required init()` to `NSView` (delegating to `init(frame: .zero)`).
- [ ] Add `public required init()` to **every** `NSView` subclass. For most this
      is a one-liner that delegates to the class's existing `init(frame:)` (or the
      designated init with sensible defaults). Enumerate them by building and
      fixing each "'required' initializer must be provided by subclass" error.
- [ ] For subclasses with stored properties that have no sane zero value, decide
      the default in `init()` explicitly (don't force-unwrap).
- [ ] Confirm `NSControl`, `NSTableView`, `NSScrollView`, `NSCollectionView`,
      `NSTextField`, `NSButton`, `NSImageView`, `NSStackView`, `NSBox`, and any
      custom internal views all compile.

### 4.2 Add the supplementary register/dequeue API
- [ ] `open func register(_ viewClass: NSView.Type?, forSupplementaryViewOfKind kind: String, withIdentifier identifier: NSUserInterfaceItemIdentifier)`
      storing the class keyed by `"kind\u{1}identifier"` (nil unregisters).
- [ ] `open func makeSupplementaryView(ofKind kind: String, withIdentifier identifier: NSUserInterfaceItemIdentifier, for indexPath: IndexPath) -> (NSView & NSCollectionViewElement)`
      that pops from a reuse pool keyed by kind+identifier, else instantiates the
      registered class (`viewClass.init()`), stamping `view.identifier`.
- [ ] Introduce an `NSCollectionViewElement`-style protocol with
      `prepareForReuse()` (parallel to `NSCollectionViewItem.prepareForReuse()`),
      or reuse `NSView.identifier` + a lightweight reuse hook.
- [ ] Reuse pool `[[String]: [NSView]]`, filled from the outgoing supplementary
      views on `reloadData` (mirror `recycleCurrentItems`).

### 4.3 Remove the interim option-C code
- [ ] Delete `rebuildSupplementaryViews()` and `positionSupplementaryViews(with:)`
      from `NSCollectionView.swift`.
- [ ] Remove the `rebuildSupplementaryViews()` calls in `reloadData()` and in the
      `collectionViewLayout` setter's `didSet`.
- [ ] Drive supplementary views through the same reload path as items: on
      `reloadData`, recycle the current supplementary views into the pool, then
      (re)acquire them via the data source calling `makeSupplementaryView`, add
      them as subviews, and position them in `tile()` exactly as now.
- [ ] Keep the `hostedSupplementaryViews` keying (or replace with an index-path
      map) — whichever the new dequeue path needs for positioning.

### 4.4 Tests
- [ ] Replace/extend `testCollectionRecyclesSupplementaryViewsAcrossRelayout` so
      it dequeues via `makeSupplementaryView` and asserts the **same instances**
      are handed back across `reloadData` (a true pool hit), matching
      `testCollectionViewRecyclesItemsViaMakeItem`.
- [ ] Keep the existing header/footer hosting + positioning tests green.
- [ ] Add a test that a registered custom `NSView` subclass is instantiated on a
      cache miss (exercises the `required init()`).

## 5. Acceptance criteria
- Real AppKit code using
  `register(_:forSupplementaryViewOfKind:withIdentifier:)` +
  `makeSupplementaryView(…)` compiles and runs against WinChocolate.
- No `rebuildSupplementaryViews`/`positionSupplementaryViews` remain.
- The whole `NSView` subclass tree builds with the new `required init()`.
- Supplementary views are pool-recycled (same instances across reloads), proven
  by a contract test.

## 6. Decision log
- **Rev 1.x:** shipped option C (keep-alive + reposition). Chosen because the
  `required init()` sweep across ~30 view classes is a wide (if mechanical)
  change we didn't want to fold into the 5.4 collection work, and option C
  captures the performance win with zero API surface risk.
- **Rev 2.0:** revisit and adopt the AppKit register/dequeue API per §4, since
  source compatibility (not just behavior) is the project goal.

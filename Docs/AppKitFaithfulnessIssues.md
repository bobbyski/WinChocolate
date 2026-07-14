# AppKit-Faithfulness Issues

**Principle:** the shared demo (`Demo/DemoApplication/main.swift`) is written **once against
Apple's real AppKit API**. WinChocolate (Win32) and LinChocolate (GTK) are meant to be
*faithful re-implementations of that API*, so the exact same source compiles and runs on all
three platforms **with no shim**.

Therefore, **every place the demo fails to compile against real Apple AppKit is a bug in
WinChocolate/LinChocolate** — we added a convenience, renamed an enum case, changed a type,
or leaked internal API, and the demo came to depend on it. The fix is always to make
WinChocolate/LinChocolate match Apple (and, where the *demo* itself reaches for something
non-AppKit, to rewrite that line in terms of real AppKit) — **never** to add an AppKit shim.

**How this list was produced.** Compile the demo alone against the macOS SDK, no shim files:

```sh
swiftc -typecheck -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
    -target arm64-apple-macos13.0 Demo/DemoApplication/main.swift
```

Result: **1,064 errors**, which collapse into the distinct divergences below. Counts are
approximate error-line tallies (one divergence usually produces several errors + cascades).

---

## A. Closure-based actions (`onAction`) instead of target/action  — ~300 errors

AppKit controls fire through **target/action** (`control.target = x; control.action = #selector(…)`).
WinChocolate/LinChocolate added a closure convenience, `onAction`, and the demo uses it
everywhere. Real AppKit has no such member, so it fails — and because the closure's parameter
type can't be inferred, it cascades into "cannot infer type of closure parameter" (192) and
"main actor-isolated global function … in a nonisolated context" (86).

Missing members the demo relies on:

| Member | On types |
|---|---|
| `onAction` | `NSButton`, `NSPopUpButton`, `NSSlider`, `NSStepper`, `NSColorWell`, `NSSearchField`, `NSSegmentedControl`, `NSDatePicker`, `NSImageView`, `NSLevelIndicator`, `NSBrowser`, `NSCollectionView`, `NSTableView`, `NSMenuItem` |
| `onDoubleAction` | `NSTableView` |
| `onSelectionChanged` | `NSTableView`, `NSOutlineView` |
| `onTextChanged` | `NSTextView`, `NSSearchField` |
| `onComboBoxTextChanged` | `NSComboBox` |

**Divergence:** these closure hooks are a WinChocolate/LinChocolate invention. **Decision needed:**
either (a) the demo must drive controls through real target/action (and the chocolate frameworks
must implement genuine target/action), or (b) if the closure convenience is kept, it must be
introduced in a way that is *also* legal AppKit — which by definition means a shim, which is
disallowed. The AppKit-faithful answer is **(a): use target/action.**

---

## B. Frame-carrying initializers that AppKit doesn't have  — ~264 errors

The demo constructs controls with a single init that takes both content **and** a frame. AppKit
has no such initializers (`title:`/`labelWithString:` inits size to fit; `frame` is set
separately, or `init(frame:)` takes only a frame).

| Demo call | Real AppKit |
|---|---|
| `NSButton(title:frame:)` | `NSButton(title:target:action:)` then set `.frame` |
| `NSButton(checkboxWithTitle:frame:)` | `NSButton(checkboxWithTitle:target:action:)` |
| `NSButton(radioWithTitle:frame:)` | `NSButton(radioButtonWithTitle:target:action:)` |
| `NSTextField(string:frame:)` | `NSTextField(string:)` / `init(frame:)` |
| `NSTextField(labelWithString:frame:)` | `NSTextField(labelWithString:)` |
| `NSSegmentedControl(labels:frame:)` | `NSSegmentedControl(labels:trackingMode:target:action:)` |
| `NSDatePicker(date:frame:)` | `init(frame:)` then set `.dateValue` |
| `NSTokenField(…tokens:)` | set `.objectValue` |
| `NSPathControl(url:frame:)` | `init(frame:)` then set `.url` |

Symptoms: `extra argument 'frame'` (146), `'title'` (80), `'labels'` (18), `'string'` (10),
`'tokens'` (4), `'date'` (4), `'url'` (2).

**Divergence:** WinChocolate/LinChocolate added frame-carrying convenience inits. The demo must
use AppKit's real initializers and set the frame separately (AppKit views default to a fitting
or zero frame otherwise).

---

## C. `NSView.backgroundColor`  — 42 errors

The demo sets `someView.backgroundColor = …` on plain `NSView`s (and the `DemoContentView`
subclass). **AppKit's `NSView` has no `backgroundColor`** — only `NSBox`, `NSTextField`,
`NSTableView`, `NSScrollView`, and layer-backed views expose one; a generic view is colored
via `wantsLayer = true; layer?.backgroundColor = …`.

**Divergence:** WinChocolate/LinChocolate added `NSView.backgroundColor`. Either the demo's
color-fill views must be an AppKit type that has it (a small custom `NSView` subclass that
draws its fill in `draw(_:)`, or a layer-backed view), or the frameworks should only expose
`backgroundColor` where AppKit does.

---

## D. Framework-internal / `win`-prefixed API leaking into the demo  — ~44 errors

The demo calls members that are WinChocolate/LinChocolate implementation surface, absent from
AppKit entirely:

| Member | Notes |
|---|---|
| `NSAppearance.winIsDark` (20) | AppKit: compare `effectiveAppearance.bestMatch(from:)` against `.darkAqua` |
| `NSColorPanel.winColorDidChange` | AppKit: target/action on the shared color panel |
| `NSFontManager.winFontDidChange` | AppKit: `changeFont(_:)` on the responder chain |
| `NSAlert.winHelpButtonAction` | AppKit: `showsHelp` + `NSAlertDelegate.alertShowHelp` |
| `NSToolbar.winAppleLook` / `.metallic` | not an AppKit concept |
| `NSTableView.winRowReorderHandler`, `NSOutlineView.winOutlineReorderHandler` | AppKit: drag-and-drop `NSTableViewDataSource` reorder methods |
| `NSDocumentController.winDocumentClass` | AppKit: `NSDocumentController.documentClass(forType:)` |
| `NSApplication.nativeBackend`, `NSView/NSWindow.nativeHandle`, `NSWindow.realizeNativePeer` | pure backend plumbing — must never appear in shared demo code |

**Divergence:** these are the clearest violations — internal or platform-only API that should not
be reachable from AppKit-shaped demo code at all. The demo must be rewritten to the AppKit
equivalent; the frameworks should keep this surface `internal`/underscored.

---

## E. Identifier types collapsed to `String`  — ~72 errors

AppKit models identifiers as real `RawRepresentable` structs — `NSToolbarItem.Identifier`,
`NSUserInterfaceItemIdentifier` — with `ExpressibleByStringLiteral`. WinChocolate/LinChocolate
declared them as `typealias … = String`, so the demo passes bare `String`s and does
`.rawValue` on them. Against real AppKit those `String`s won't convert.

Symptoms: `String` → `NSToolbarItem.Identifier` (36), `String` → `NSUserInterfaceItemIdentifier`
(18), `NSUserInterfaceItemIdentifier?` → `String` (6), `Int` → `String`/`Identifier` (12).

**Divergence (already logged in `AppKitCompatibilityDivergences.md`):** promote both identifier
typealiases in WinChocolate/LinChocolate to real `RawRepresentable` + `ExpressibleByStringLiteral`
structs matching AppKit. The demo can then use string literals unchanged.

---

## F. Enum case-name divergences  — ~80 errors

The demo names enum cases that don't exist under those names in AppKit. `cannot infer contextual
base in reference to member 'X'`:

| Demo uses | Real AppKit case | Enum |
|---|---|---|
| `.radioButton`, `.switchButton` | `.radio`, `.switch` | `NSButton.ButtonType` |
| `.on` / `.off` | `.on` / `.off` **on `NSControl.StateValue`** | state value is nested differently in the chocolates |
| `.rounded`, `.roundedDisclosure`, `.disclosure`, `.circular`, `.recessed`, `.texturedSquare`, `.inline` | AppKit `NSButton.BezelStyle` names differ (`.push`, `.flexiblePush`, `.disclosure`, `.circular`, `.badge`, …) | `NSButton.BezelStyle` |
| `.rounded`, `.separated`, `.texturedSquare`, `.capsule` | `NSSegmentedControl.Style` names | segment style |
| `.scaleProportionallyDown`, `.scaleAxesIndependently`, `.scaleNone`, `.scaleProportionallyUpOrDown` | `NSImageScaling` cases | image scaling |
| `.alignCenter`, `.alignTopLeft`, `.right` | `NSImageAlignment` cases | image alignment |
| `.clockAndCalendar` | `NSDatePicker.Style` | date-picker style |

**Divergence:** WinChocolate/LinChocolate coined non-Apple case names (and in the `.on`/`.off`
case, a differently-nested state-value type). Rename to match AppKit exactly.

---

## G. Delegate protocols don't refine `NSObjectProtocol`  — 30 errors

The demo's delegate/data-source classes (`DemoWindowDelegate`, `DemoToolbarDelegate`,
`DemoTableDataSource`, `DemoViewTableDelegate`, `DemoOutlineDataSource`, `DemoSplitDelegate`,
`DemoStatusRow*`, `EditMenuController`, …) declare conformance to AppKit delegate protocols
**without inheriting `NSObject`**. AppKit's delegate protocols refine `NSObjectProtocol`, so a
conformer must be an `NSObject` subclass → *"cannot declare conformance to 'NSObjectProtocol' in
Swift; 'X' should inherit 'NSObject'."*

**Divergence:** WinChocolate/LinChocolate declared their delegate protocols as plain
`: AnyObject`, so the demo's delegate classes were written as bare classes. Make the chocolate
delegate protocols refine `NSObjectProtocol` (as AppKit does) and have the demo's delegates
inherit `NSObject`.

---

## H. `NSToolbar` population API  — 16 errors

The demo builds the toolbar with `demoToolbar.addItem(someNSToolbarItem)`. AppKit's `NSToolbar`
has **no `addItem`** — items are supplied by the `NSToolbarDelegate`
(`toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)` + default/allowed identifier
lists), and inserted with `insertItem(withItemIdentifier:at:)`.

**Divergence:** WinChocolate/LinChocolate added a direct `addItem(_:)`. The demo must populate
the toolbar the AppKit way (delegate + identifiers).

---

## I. `NSForm` custom accessors  — 30 errors

The demo uses `form.textField(at:)`, `form.setStringValue(_:at:)`, `form.titleWidth`. AppKit's
`NSForm` (a `NSMatrix` subclass, deprecated) exposes cells via `cell(atIndex:)` /
`NSFormCell` — none of those three members exist.

**Divergence:** WinChocolate/LinChocolate invented a friendlier `NSForm` accessor set. Match
AppKit's `NSFormCell`-based API (or, given `NSForm` is deprecated in AppKit, reconsider the demo
section).

---

## J. Method label / signature divergences  — ~24 errors

| Demo call | Real AppKit | Type |
|---|---|---|
| `NSPopUpButton.setTag(_:forItemAt:)` (6) | tags live on `NSMenuItem` (`item(at:).tag`) | `NSPopUpButton` |
| `browser.value(atColumn:row:)` (8) | `NSBrowser.item(at:inPropertyWithKey:)` / `selectedCell(inColumn:)` | `NSBrowser` |
| `outlineView.tableColumn(at:)` (4) | `tableColumn(withIdentifier:)` | `NSTableView`/`NSOutlineView` |
| `NSAlert(error:)` argument shape (2) | `NSAlert(error:)` exists but the demo's call mismatches | `NSAlert` |
| `NSButton` cell/`title:` init (`textCell:`) (2) | AppKit `NSCell` init labels | cells |

**Divergence:** small per-method label/shape mismatches — align each to Apple's signature.

---

## K. Immediate-mode drawing free functions  — 22 errors

The demo calls `NSFrameRect(_:)` and `NSRectFill(_:)`. These *are* real AppKit functions, yet the
compiler reports *"cannot find 'NSFrameRect'/'NSRectFill' in scope."*

**Divergence / to verify:** confirm whether the current macOS SDK still surfaces these to Swift
(they may require `import AppKit` only, or may have moved). If AppKit provides them, this is a
false positive to re-check once the cascade above is cleared; if not, the demo should use the
`NSBezierPath` / `.fill()` / `.stroke()` equivalents that all three platforms share.

---

## L. `CGImage` / WinCoreGraphics API on the CoreGraphics page  — ~16 errors

The Phase-13 CoreGraphics page uses `CGImage(width:height:rgbaPixels:)`, `image.pixel(atX:y:)`,
and `image.encodeBMP()` — the **WinCoreGraphics** BMP-centric surface. Apple's real
`CoreGraphics.CGImage` has none of these; `CGImage(width:height:rgbaPixels:)` even mis-resolves
against `CGWindowListCreateImage`-family symbols.

**Divergence:** WinCoreGraphics reimplemented `CGImage` with a different (in-memory-BMP) API
rather than modeling Apple's `CGImage`/`CGContext`/`CGDataProvider`. On macOS the same source
should build against real CoreGraphics — so either the demo's pixel/BMP round-trip must be
expressed through Apple's `CGImage` + a `CGDataProvider`/`CGImageDestination`, or WinCoreGraphics
must present an Apple-shaped `CGImage`.

---

## M. Nib manual-wiring surface (`winInstantiate` / connection records)  — ~12 errors

*Found 2026-07-14, after the develop merge added the Nib (15) page.*

The Nib page loads `DemoNibPanel.xib` and then wires it up through a **`win`-prefixed manual
surface** that Apple's `NSNib` does not have:

| Demo uses | Real AppKit |
|---|---|
| `nib.winInstantiate(withOwner:)` → rich instance | `nib.instantiate(withOwner:topLevelObjects:)` returning `Bool`, filling an `[Any]` |
| `instance.view(withIdentifier:)` | no such lookup — outlets are bound by name via KVC |
| `instance.connections` / `.kind == .outlet` / `.action` | AppKit exposes no parsed `<connections>` records |
| `instance.objectsByID`, `instance.topLevelObjects` on the instance | AppKit hands back only the top-level object array |
| `button.action?.name` | real `Selector` is the Obj-C selector — **no `.name`** (use `NSStringFromSelector`) |

**Root cause (an honest gap, not a rename):** AppKit's nib loader binds `@IBOutlet`/`@IBAction`
**automatically by name**, using the Objective-C runtime's KVC/reflection. WinChocolate and
LinChocolate have no such runtime, so instead of automatic binding they *expose the parsed graph*
— `winInstantiate` → an instance object carrying `objectsByID` + `connections`, which the app
walks by hand (`view(withIdentifier:)`, `connections.filter { $0.kind == .outlet }`). The whole
`win*` nib API, and the demo's Nib page written against it, exist only to stand in for the missing
KVC layer. Likewise the chocolates' `Selector` is a `struct { let name }`, whereas AppKit's is the
opaque Obj-C selector.

**Fix locus:** this is the same class of gap as Cocoa bindings — it needs a KVC/reflection layer
(or Swift `Mirror`-based outlet binding) in the frameworks so that `instantiate(withOwner:
topLevelObjects:)` binds `@IBOutlet`s directly and the demo's Nib page can be rewritten to plain
outlet properties with no `winInstantiate`, no connection walking, and no `Selector.name`. Until
that lands, the Nib page is inherently non-portable to real AppKit. (LinChocolate currently
mirrors WinChocolate's `win*` surface so the shared demo builds+runs on GTK — see the nib port —
but that is deliberately *matching a divergence*, not resolving it.)

---

## N. `NSCollectionView` supplementary views must be registered + dequeued  — **runtime crash**

*Found 2026-07-14 — the first divergence caught at **runtime**, not compile time.*

The demo's flow-layout data source builds a supplementary view fresh and returns it:

```swift
func collectionView(_ cv: NSCollectionView, viewForSupplementaryElementOfKind kind: String,
                    at indexPath: IndexPath) -> NSView {
    let header = NSTextField(string: "  \(section.title)", frame: .zero)   // ← raw view
    return header
}
```

On real AppKit this **crashes the app on launch** (`EXC_BREAKPOINT` via
`+[NSApplication _crashOnException:]`), with:

```
*** Assertion failure in -[_NSCollectionViewCore
      _createPreparedSupplementaryViewForElementOfKind:atIndexPath:withLayoutAttributes:applyAttributes:]
the view returned from -collectionView:viewForSupplementaryElementOfKind:
  UICollectionElementKindSectionFooter atIndexPath:{length = 2, path = 0 - 0}
  was not retrieved by calling -makeSupplementaryViewOfKind:withIdentifier:forIndexPath:
  or is nil (<NSTextField: 0x…>)
```

Reached via `makeKeyAndOrderFront` → `_setUpFirstResponderBeforeBecomingVisible` →
`layoutIfNeeded` → `-[NSCollectionView layout]` → supplementary creation.

**Real AppKit's contract:** register a class/nib per kind, then dequeue in the data source —

```swift
cv.register(MyHeader.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: NSUserInterfaceItemIdentifier("hdr"))
…
let v = cv.makeSupplementaryView(ofKind: kind, withIdentifier: .init("hdr"), for: indexPath)
```

**Divergence:** WinChocolate/LinChocolate accept *any* view the data source hands back (no
registration, no reuse identity), so the demo was written to that laxer contract. WinChocolate's
own source states it outright — `NSCollectionView.swift`:

> *"The `register(_:forSupplementaryViewOfKind:withIdentifier:)` / `makeSupplementaryView(...)`
> API is deferred to Rev 2.0"*

Items already follow Apple (`register(_:forItemWithIdentifier:)` + `makeItem(withIdentifier:for:)`
exist and pool for reuse); only the **supplementary** half was skipped. That deferral is the bug.

**Measured against real AppKit** (isolated repro, layout forced):

| Data source returns | Result |
|---|---|
| a freshly-built view (today's demo) | **crash** |
| `register(class)` + `makeSupplementaryView` | **works** |
| `makeSupplementaryView` with *no* prior `register` | **crash** |

So Apple requires **both** halves — registration *and* dequeue.

**Fix + its architectural consequence.** Implement `register(_ viewClass: AnyClass?,
forSupplementaryViewOfKind:withIdentifier:)` and `makeSupplementaryView(ofKind:withIdentifier:for:)`
in both frameworks (mirroring the existing `makeItem` reuse pool), and rewrite the demo's
header/footer to register + dequeue. Note the knock-on: instantiating a registered `AnyClass`
requires metatype construction, so **`NSView.init(frame:)` must become `required`** in both
frameworks —

```
error: constructing an object of class type 'V' with a metatype value must use a 'required' initializer
```

### Status: **RESOLVED 2026-07-14**

Implemented in both frameworks + the demo. The demo now launches and runs on real AppKit.

**The `required` modifier is an implementation necessity, not an API divergence.** Apple's NSView
is *not* `required` in Swift terms — AppKit instantiates registered classes through the Objective-C
runtime (`[[cls alloc] initWithFrame:]`), which has no such rule. Pure Swift has no equivalent
escape hatch, so the modifier is forced on us by the platform. Crucially it constrains *subclasses
inside the frameworks*, not callers, and it **does not leak into the shared demo**: of the demo's 12
`NSView` subclasses, 11 declare no initializer and one (`DemoFilledView`) declares only a
*convenience* init — none of which blocks initializer inheritance. (Verified: this matters, because
`required init(frame:)` and `required override init(frame:)` are mutually exclusive between AppKit
and Lin/Win, so a demo subclass with a designated init *would* have needed an `#if` — i.e. a shim.)

**Measured cascade** (compiler-enumerated, not estimated — both smaller and far more mechanical
than the "~33 / ~35" first guessed):

| | Classes needing `required init(frame:)` | Shape of the fix |
|---|---|---|
| LinChocolate | **27** | 18 were `override`→`required` (one word); 9 needed a new init |
| WinChocolate | **37** | 33 were `override`→`required` (one word); 4 needed a new init |

The 4 in WinChocolate (`AlertIconView`, `ColorSwatchView`, `NSToolbarCompositeItemView`,
`NSToolbarCustomizationTile`) are internal helpers that cannot exist without collaborators and are
never registered, so their `required init(frame:)` is `fatalError` — the same idiom as the
ubiquitous `required init?(coder:) { fatalError(…) }`.

### Two further divergences found while fixing this

**N.1 — `elementKindSectionHeader`/`Footer` had the wrong values in WinChocolate.** Printed from
real AppKit, the constants are `UICollectionElementKindSectionHeader` / `…Footer` (the `UI` prefix
is not a typo — AppKit's collection view is built on the UICollectionView implementation, hence
`UICollectionView.m` in its assertion). LinChocolate already matched; WinChocolate vended
`NSCollectionElementKindSectionHeader`. Latent rather than live, since callers use the symbol —
but observable, and wrong. Fixed. (`elementKindInterItemGapIndicator` *is* `NSCollection…`-prefixed.)

**N.2 — assigning `collectionViewLayout` discards supplementary registrations.** Measured on real
AppKit:

| Order | Result |
|---|---|
| `register(…)` then set `collectionViewLayout` | **crash** — registration silently lost |
| set `collectionViewLayout` then `register(…)` | **works** |

When the registration is lost, `makeSupplementaryView` falls back to loading a **nib named after the
identifier**, and the failure surfaces as the thoroughly misleading
`-[NSNib _initWithNibNamed:bundle:options:] could not load the nib 'DemoSectionFooter'`. Callers
must register *after* the layout is assigned; the demo now documents this at the call site.

### Correction to a prior claim in this document

An earlier revision predicted the **items** path would throw the identical assertion, since the demo
hand-builds `NSCollectionViewItem()` in `itemForRepresentedObjectAt` rather than calling `makeItem`.
**That is wrong.** The repro hand-built its items and survived, and the fixed demo runs on AppKit
with the item path untouched. Apple enforces register+dequeue for **supplementary views only**;
items may be constructed directly. Using `makeItem` remains better practice (it is what the reuse
pool is for), but it is *not* required for correctness and is not a crash risk.

---

## O. `NSBrowser` delegate protocol shape  — **runtime**

*Found 2026-07-14, logged at launch on real AppKit:*

```
*** Illegal NSBrowser delegate (<DemoBrowserDataSource: 0x…>).  Must implement
    browser:willDisplayCell:atRow:column: and either browser:numberOfRowsInColumn:
    or browser:createRowsForColumn:inMatrix:
```

### Status: **RESOLVED 2026-07-14** — and the original diagnosis above was wrong

The first reading of this error (that AppKit "requires the classic matrix-based trio" and that the
demo "implements methods AppKit has never heard of") is **incorrect**. AppKit fully supports the
modern *item-based* `NSBrowserDelegate`, and every method `DemoBrowserDataSource` implements is a
genuine AppKit method. The error message misleads: it names the matrix-based methods because that is
the interface AppKit *fell back to*, not the one it wanted.

**Actual cause.** The item-based interface requires **all four** of
`browser(_:numberOfChildrenOfItem:)`, `browser(_:child:ofItem:)`, `browser(_:isLeafItem:)` and
`browser(_:objectValueForItem:)`. AppKit probes for them with `respondsToSelector:`; if *any* is
missing it concludes the delegate is not item-based and falls back to the matrix interface, which
the delegate also doesn't implement — hence "Illegal NSBrowser delegate".

The demo implemented only the first three. It compiled and worked on WinChocolate anyway, because
**WinChocolate supplies `objectValueForItem` as a Swift protocol-extension default**:

```swift
public extension NSBrowserDelegate {
    /// Default display value uses item description.
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }
}
```

**A Swift protocol-extension default is invisible to `respondsToSelector:`** — it is static dispatch,
it adds no Objective-C method to the class. So the framework's convenience made the demo *look*
complete while it was missing a method Apple requires, and the gap could only ever appear at runtime,
on Apple.

**Fix applied:** the demo implements `browser(_:objectValueForItem:)` itself. This is the no-shim
rule doing exactly its job — the demo line was wrong, and the framework was hiding it.

**Generalized lesson (worth auditing for):** any Swift protocol-extension default that stands in for
a method AppKit probes via `respondsToSelector:` is a latent runtime divergence of this shape. It is
strictly more dangerous than a compile error, because the frameworks report success. Candidates to
audit: the remaining `NSBrowserDelegate` defaults (`isLeafItem`, `titleOfColumn`, `imageForItem`)
and any other `public extension …Delegate` in either framework.

**Still open (LinChocolate):** its `NSBrowserDelegate` declares only three methods (no
`objectValueForItem`) and refines `AnyObject` rather than `NSObjectProtocol` (see Issue G). The demo
now implements a fourth method LinChocolate's protocol doesn't declare — harmless (it is simply an
extra method on the class), but LinChocolate's browser will not call it, so its display path stays
on the older shape. Aligning it is tracked with Issue G.

---

## Summary

| # | Divergence | ~Errors | Fix locus |
|---|---|---|---|
| A | `onAction` closures vs target/action | ~300 | frameworks + demo |
| B | Frame-carrying initializers | 264 | frameworks + demo |
| F | Enum case-name mismatches | 80 | frameworks (rename to Apple) |
| E | Identifier types as `String` | 72 | frameworks (real structs) |
| C | `NSView.backgroundColor` | 42 | frameworks + demo |
| D | `win*` / `native*` internal API leak | 44 | frameworks (hide) + demo |
| G | Delegate protocols miss `NSObjectProtocol` | 30 | frameworks + demo |
| I | `NSForm` accessors | 30 | frameworks |
| J | Method label/signature mismatches | 24 | frameworks |
| K | `NSFrameRect`/`NSRectFill` scope | 22 | verify / demo |
| H | `NSToolbar.addItem` | 16 | frameworks + demo |
| L | `CGImage`/WinCoreGraphics surface | 16 | frameworks + demo |
| M | Nib manual-wiring (`winInstantiate`) — missing KVC layer | ~12 | frameworks (KVC/reflection) + demo |
| N | Collection supplementary views not registered/dequeued | **runtime crash** | ✅ **fixed** — frameworks + demo |
| O | `NSBrowser` delegate: Swift default hid a required method | **runtime** | ✅ **fixed** — demo (LinChocolate parity open) |

Note that **A–M are compile-time** divergences; **N and O only surface at runtime**, once the demo
actually builds against AppKit. Expect more of this class as the compile errors are retired — a
clean build is necessary but not sufficient for faithfulness.

With N and O fixed, the shared demo **launches and runs against real AppKit** (`./run-mac.sh`).
That validates the tri-target premise on the macOS leg for the first time. Both were found only by
running, and both were invisible to every compiler — N because the frameworks accepted a view Apple
rejects, O because a Swift protocol-extension default silently satisfied a requirement Apple probes
for at runtime. The second pattern (**framework conveniences that mask missing methods**) is the
more dangerous of the two and is worth a dedicated audit; see Issue O.

Every row is a place WinChocolate/LinChocolate diverged from Apple. None are to be resolved with
an AppKit shim — each is fixed by making the chocolate frameworks match AppKit exactly and, where
the demo itself reached for a non-Apple spelling, rewriting that line against real AppKit.

**Remediation is tracked as Phase 18** (`ProjectPlan.md`). The governing rule there is **SET IN STONE
(Bobby, 2026-07-14): the Apple-native way must work, and must be *sufficient*.** WinChocolate genuinely
implements the real AppKit mechanisms (target/action, real inits, delegate protocols) so unmodified
pure-AppKit source builds **and runs**, and **no convenience is ever *required*.** Two moves close the
rows: *CORRECT* the framework toward Apple (rename/retype to Apple's exact spelling: rows E, F, G, H, I, J),
or *move added conveniences out of the framework* (rows A, B, C) — remove `onAction`/frame-inits/
`NSView.backgroundColor` from WinChocolate and let the demo use the real AppKit idiom (target/action, real
inits + `.frame`, an `NSView` subclass that draws its fill). `win*`/`native*` leaks (row D) are *hidden* and
the demo rewritten to the Apple equivalent.

**A convenience helper *is* allowed** — but only as **demo-local** code built entirely on real Apple/AppKit
primitives (e.g. a closure `onAction` that sets the *actual* `target`/`action`), so it compiles and runs on
real AppKit too and is never required. **Banned:** a non-Apple addition on WinChocolate's own surface that
the demo depends on; a one-sided `#if os(macOS)` shim (why `PlatformShims.swift` was deleted); any *required*
convenience. Test: if a helper needs anything WinChocolate-only, it's a shim and it's out. The only
sanctioned non-coverage is *exclusion* (row L CoreGraphics, row M Nib): pages gated on Phase 13 / 12.1 are
`#if`-fenced out and excluded from the "runs on AppKit" claim until their owning phase lands — excluded,
never shimmed.

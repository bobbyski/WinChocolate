# Demo changes

A running log of changes to the **shared demo** (`Demo/DemoApplication/`) — the one
source tree that must compile and run unmodified against all three targets:

| Target | Framework | Built by |
|---|---|---|
| macOS | real Apple AppKit | `./run-mac.sh` |
| Windows | WinChocolate (Win32) | `buildandrun.bat` |
| Linux | LinChocolate (GTK4) | `LinChocolate/run-linux.sh` |

## The rules these changes follow

1. **No shims.** Ever. Set in stone. A demo that only compiles via a compatibility
   layer proves nothing.
2. **No framework changes in this phase.** Fixes land in the demo only. Where a demo
   line reached for a non-Apple spelling, it is rewritten against plain AppKit. (This
   rule starts at the *Flip every demo view* entry below. The two backfilled entries
   beneath it predate it and are marked as such — one of them did change the
   frameworks, because the API it needed did not exist.)
3. **Plain AppKit must be sufficient.** Anything written here must be real AppKit API,
   so it means the same thing on all three targets.

Where a divergence is genuinely the *framework's* fault rather than the demo's, it is
recorded in [`Docs/AppKitFaithfulnessIssues.md`](Docs/AppKitFaithfulnessIssues.md)
instead — that document tracks framework remediation (Phase 18); this one tracks the
demo.

## How to add an entry

Newest first. Each entry states the symptom, the root cause, the fix, and **how it was
verified** — running the demo, not just building it.

---

## 2026-07-14 — Flip every demo view to a top-left origin

**Symptom.** Every page rendered upside down on real AppKit: content piled at the
bottom of the window with empty space above, and overlapping labels. On the Controls
page, `Clicks: 0` sat at the very bottom and `Tokens/Price` near the top — exactly
inverted.

**Root cause.** The demo is authored entirely in **top-left coordinates**. It never had
to declare that, because WinChocolate hardcodes `open var isFlipped: Bool { true }` —
every view there is top-left, always. LinChocolate papers over it differently, with a
non-Apple static (`NSView.defaultIsFlipped = true`, main.swift line 45, inside
`#if canImport(LinChocolate)`). Real AppKit is the only target that reads `isFlipped`
honestly, and its default is `false` (bottom-left origin) — so the authored layout
inverted.

**Fix.** Override `isFlipped` on the demo's own view subclasses. This is plain AppKit
(`NSView.isFlipped` is an overridable property Apple documents for exactly this), so it
is a no-op on Windows/Linux and corrects macOS:

```swift
/// The demo is authored in top-left coordinates (see `DemoFilledView`).
override var isFlipped: Bool {
    true
}
```

| Target | `isFlipped` default | Effect of the override |
|---|---|---|
| WinChocolate | `{ true }` — always | no change |
| LinChocolate | `defaultIsFlipped` (set true at line 45) | no change |
| **AppKit** | `false` (bottom-left) | **fixes the inversion** |

> ### ⚠️ Windows and Linux must match Apple's `isFlipped` behavior
>
> **This entry fixes the demo; it does not fix the frameworks.** The table above is a
> statement of two divergences, not of correct behavior. Apple's contract is:
>
> - `NSView.isFlipped` **defaults to `false`** (bottom-left origin), and
> - it is a **per-view, overridable** property that the framework **must honor** — for
>   positioning subviews *and* for the view's own drawing.
>
> Neither chocolate framework implements that contract today:
>
> | | Default | Honors a per-view override? |
> |---|---|---|
> | **WinChocolate** | `true` — **wrong**, Apple's is `false` | **No.** `isFlipped` is a **dead property**: nothing in the framework reads it. Layout is unconditionally top-left because Win32 is. |
> | **LinChocolate** | `NSView.defaultIsFlipped`, a **non-Apple process-global static** | **Yes** — the backend, `LayoutSolver`, `NSForm` and `NSMatrix` all read it. |
> | **AppKit** | `false` | Yes |
>
> **Why this matters, and why it is easy to miss.** The override added by this entry
> appears to work on all three targets — but on WinChocolate it works *for the wrong
> reason*. It is a no-op there not because the property is respected, but because
> WinChocolate ignores `isFlipped` entirely and is always top-left. The demo would
> render **identically if it overrode `isFlipped` to `false`**. The property is inert,
> so the demo's correctness on Windows is a coincidence of Win32's native origin rather
> than compatibility.
>
> The consequence is the reverse of the bug this entry fixed: unmodified **plain AppKit
> code that relies on the default bottom-left origin — i.e. code that never mentions
> `isFlipped` at all, which is most AppKit code — renders inverted on WinChocolate**,
> and cannot opt out, because overriding to `false` changes nothing.
>
> **Required for compatibility:**
>
> 1. Both frameworks default `isFlipped` to **`false`**, matching Apple.
> 2. Both **honor per-view overrides** for subview positioning and for drawing.
>    WinChocolate must actually read the property and translate coordinates rather than
>    assuming Win32's origin; LinChocolate must drop the global static in favour of
>    Apple's `false` default (`NSView.defaultIsFlipped` is not AppKit API and the demo
>    should not need to set it — see the follow-up at the end of this entry).
> 3. Once both honor it, this demo's overrides become the *only* thing establishing a
>    top-left origin on every target — one authored layout, honestly declared, with no
>    framework-specific lines.
>
> Until then the demo's `#if canImport(LinChocolate)` / `defaultIsFlipped` line stays,
> and Windows' top-left origin remains an accident rather than a contract.

Applied to all 12 demo `NSView` subclasses:

- **Containers** (position subviews by frame): `DemoContentView`, `DemoPageView`,
  `DemoFilledView`
- **Custom-drawing views**: `DemoCanvasView`, `DemoShapesView`, `DemoGradientsView`,
  `DemoSlowGradientView`, `DemoCoreGraphicsView`, `DemoHoverView`, `DemoDragHandle`,
  `DemoDropWell`, `DemoPrintSample`

Also converted the three plain `NSView` containers to `DemoPageView`, since a bare
`NSView` has no override and would have stayed inverted: `noteContent`,
`stressDocView`, `panelContent`.

**The non-obvious half — drawing views are separate.** A flipped *superview* repositions
a subview's frame but does **not** change that subview's own drawing origin. So after
fixing the containers, the Drawing page still *looked* plausible while its artwork was
vertically mirrored — the shapes are symmetric enough to hide it. Reading the source
rather than the render proved it, and fixing it moved four elements:

| Element | Code | Before | After |
|---|---|---|---|
| `"WinChocolate"` text | `at: (14, 10)` | bottom-left | **top-left** ✓ |
| phoenix image | `draw(in: (330, 16, …))` | bottom-right | **top-right** ✓ |
| red ellipse | `ovalIn: (60, 228, …)` | top-left | **bottom-left** ✓ |
| gradient labels | small y | below swatches | **above** ✓ |

The five-point star (apex `(100, 75)`, legs at `y = 210.7`) now points up rather than
down. Eyeballing the render alone would have shipped this page silently wrong.

**Files touched**

- `Demo/DemoApplication/main.swift` — 11 overrides, 3 container type swaps
- `Demo/DemoApplication/DemoConveniences.swift` — 1 override (`DemoFilledView`)

**Verified**

- macOS: built and **ran**; Controls, Values and Drawing pages render top-down
  correctly (`Clicks: 0` at top, `Tokens/Price` at bottom).
- Linux: `RealDemo` error count **unchanged at 339**, no `isFlipped`/`DemoPageView`
  errors — the shared source still means the same thing there. (That 339 is
  pre-existing breakage on this branch, unrelated to this change: HEAD without any of
  it is 347.)
- Windows: not built (no Win32 toolchain on this machine). The override is a no-op
  there by construction, since WinChocolate's `isFlipped` is already `true`.

**Notes / follow-ups**

- `NSView.defaultIsFlipped = true` (main.swift line 45) is a **LinChocolate-only
  static, not AppKit API**. It is now redundant for the demo's own views, but still
  governs framework-vended containers on Linux, so it was left in place. Removing it is
  a candidate once LinChocolate's containers are addressed.
- **Still broken on the Controls page, and not a coordinate problem:** the `NSForm`
  rows do not lay out — `Name:` and `Status:` overlap on a single line with a stray
  white bar beside them. Tracked as Issue I (`NSForm` accessors).

---

## 2026-07-14 — Implement all four item-based `NSBrowser` delegate methods

> Backfilled. Predates the demo-only phase, but the fix was **demo-only** — the
> framework was hiding a demo bug. Framework analysis: Issue O.

**Symptom.** Logged at launch on real AppKit, after which the browser was rejected
outright and stayed empty:

```
*** Illegal NSBrowser delegate (<WinChocolateDemo.DemoBrowserDataSource: 0x…>).
    Must implement browser:willDisplayCell:atRow:column: and either
    browser:numberOfRowsInColumn: or browser:createRowsForColumn:inMatrix:
```

**Root cause — and the message is misleading.** It names the *matrix-based* methods,
but AppKit does not want them: it names the interface it **fell back to**. AppKit fully
supports the modern *item-based* delegate the demo uses, and every method
`DemoBrowserDataSource` implemented was a genuine AppKit method.

The item-based interface requires **all four** of `browser(_:numberOfChildrenOfItem:)`,
`browser(_:child:ofItem:)`, `browser(_:isLeafItem:)` and
`browser(_:objectValueForItem:)`. AppKit probes for them with `respondsToSelector:`; if
any one is missing it concludes the delegate isn't item-based and falls back to the
matrix interface — which the delegate also doesn't implement. Hence "Illegal delegate".

The demo implemented only the first three. It compiled and worked on Windows anyway,
because **WinChocolate supplies `objectValueForItem` as a Swift protocol-extension
default**. A Swift extension default is static dispatch: it adds no Objective-C method,
so it is **invisible to `respondsToSelector:`**. The framework's convenience made the
demo *look* complete while it was missing a method Apple requires — and the gap could
only ever surface at runtime, on Apple.

**Fix.** The demo implements the fourth method itself:

```swift
func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
    item.map { String(describing: $0) }
}
```

This is the no-shim rule doing its job: the demo line was wrong, and the framework was
concealing it. The method is plain AppKit and overrides WinChocolate's default
harmlessly.

**Files touched**

- `Demo/DemoApplication/main.swift` — `DemoBrowserDataSource`

**Verified**

- macOS: built and ran; the "Illegal NSBrowser delegate" error is gone.
- Linux: LinChocolate's `NSBrowserDelegate` declares only three methods, so the fourth
  is simply an extra method on the class — harmless, but LinChocolate won't call it.
  Aligning that protocol is tracked with Issue G.

**Notes / follow-ups**

- **Generalized risk worth auditing.** Any Swift protocol-extension default in either
  framework that stands in for a method AppKit probes via `respondsToSelector:` is a
  latent runtime divergence of exactly this shape — and it is *more* dangerous than a
  compile error, because the frameworks report success. Candidates: the remaining
  `NSBrowserDelegate` defaults (`isLeafItem`, `titleOfColumn`, `imageForItem`) and any
  other `public extension …Delegate`.

---

## 2026-07-14 — Register and dequeue collection-view supplementary views

> Backfilled. Predates the demo-only phase, and unlike the entries above it **also
> required framework changes** — the register/dequeue API did not exist in either
> framework. Framework analysis and the `required init(frame:)` consequence: Issue N.

**Symptom.** Hard **crash on launch** on real AppKit (`EXC_BREAKPOINT` via
`+[NSApplication _crashOnException:]`):

```
*** Assertion failure in -[_NSCollectionViewCore
      _createPreparedSupplementaryViewForElementOfKind:atIndexPath:withLayoutAttributes:applyAttributes:]
the view returned from -collectionView:viewForSupplementaryElementOfKind:
  UICollectionElementKindSectionFooter atIndexPath:{length = 2, path = 0 - 0}
  was not retrieved by calling -makeSupplementaryViewOfKind:withIdentifier:forIndexPath:
  or is nil (<NSTextField: 0x…>)
```

**Root cause.** `DemoFlowCollectionDataSource` built each section header/footer fresh
and returned it. AppKit requires every supplementary view to be **registered** under a
kind+identifier and then **dequeued** via `makeSupplementaryView`. Both frameworks
accepted any view handed back — WinChocolate's source said so outright ("deferred to
Rev 2.0") — so the demo was written to that laxer contract.

Measured against real AppKit with an isolated repro; Apple requires **both** halves:

| Data source returns | Result |
|---|---|
| a freshly-built view (the old demo) | **crash** |
| `register(class)` + `makeSupplementaryView` | **works** |
| `makeSupplementaryView` with no prior `register` | **crash** |

**Fix.** Register the class per kind, then dequeue and configure in the data source:

```swift
static let headerID = NSUserInterfaceItemIdentifier("DemoSectionHeader")
static let footerID = NSUserInterfaceItemIdentifier("DemoSectionFooter")
…
let header = collectionView.makeSupplementaryView(
    ofKind: kind, withIdentifier: Self.headerID, for: indexPath) as! NSTextField
header.stringValue = "  \(section.title)"
```

Because views are now **recycled** rather than built fresh, every visual property must
be set on each vend (`drawsBackground`, `isEditable`, `isBordered`, font, colors) — a
reused view carries the previous section's state.

**Registration order matters, and getting it wrong is baffling.** Measured on AppKit:

| Order | Result |
|---|---|
| `register(…)` then set `collectionViewLayout` | **crash** — registration silently lost |
| set `collectionViewLayout` then `register(…)` | **works** |

Assigning the layout **discards existing registrations**. When that happens,
`makeSupplementaryView` falls back to loading a **nib named after the identifier**, and
it surfaces as the thoroughly misleading `-[NSNib _initWithNibNamed:bundle:options:]
could not load the nib 'DemoSectionFooter'`. The demo now registers *after* the layout
is assigned and documents why at the call site.

**Items are NOT affected — a correction.** An earlier prediction held that the item
path would throw the identical assertion, since the demo hand-builds
`NSCollectionViewItem()` in `itemForRepresentedObjectAt` rather than calling `makeItem`.
**That is wrong.** The repro hand-built its items and survived, and the fixed demo runs
with the item path untouched. Apple enforces register+dequeue for **supplementary views
only**. Using `makeItem` remains better practice, but it is not required for
correctness and is not a crash risk — so the demo was left alone here.

**Files touched**

- `Demo/DemoApplication/main.swift` — `DemoFlowCollectionDataSource` (reuse
  identifiers, dequeue + full re-configuration, registration at the call site)

**Verified**

- macOS: built and **ran** — the launch crash is gone. This was the change that first
  got the shared demo running against real AppKit at all.
- Linux/Windows: depends on the matching framework API landing (Issue N); the
  WinChocolate half is written but **unverified** — no Win32 toolchain on this machine.

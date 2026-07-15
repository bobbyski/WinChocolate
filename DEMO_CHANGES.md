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

## 2026-07-14 — Values page: boxed captions, dead progress bar, clipped clock, dead scroller

Four bugs, all demo-side, all caused by an **AppKit default the demo never overrode**.
Three of the four are the same lesson: AppKit's defaults are not the chocolate
frameworks' defaults, and the demo had been written against the latter without noticing.

### 1. Captions drawn as boxed input fields

Identical to the Controls page: `NSTextField(string:)` builds an **editable, bordered**
field. Applied the demo's caption idiom to all 13 — `Slider:`, `Vert:`, `Progress:`,
`Stepper:`, `Combo:`, `Search:`, `Level:`, `Color:`, `Segments:`, `Scroller:`, `Date:`,
`Calendar:`, `Rating:`.

### 2. Progress bar ignored the slider

**`NSProgressIndicator.isIndeterminate` defaults to `true` on AppKit**, and an
indeterminate bar **ignores `doubleValue` entirely** — it stores the value and animates a
barber pole instead. Measured:

```
NSProgressIndicator defaults: isIndeterminate=true style=0 min=0.0 max=100.0
after setting doubleValue=82 while indeterminate: doubleValue=82.0  (stored, but not drawn)
```

The slider's action *was* firing all along (its value label tracked correctly) — the bar
simply wasn't a determinate bar. Fixed with `progressIndicator.isIndeterminate = false`.
Note the sibling `activityIndicator` sets `isIndeterminate = true` explicitly and is
correct as-is; only the determinate bar was relying on a default that differs from Apple's.

### 3. Clock clipped off the right edge

A `.clockAndCalendar` picker draws a calendar **and** a clock side by side. Measured:

| | Size |
|---|---|
| what the demo gave it | 224 × 168 |
| `intrinsicContentSize` on AppKit | **275.5 × 148** |

~52pt too narrow, so the clock was cut off. Widened to **276**.

**The 168 height is deliberate and stays.** It exists to accommodate WinChocolate's
calendar, and AppKit is happy in a taller frame — 148 is its *minimum*, not its maximum.
Only the width was wrong.

### 4. Scroller drew no knob and did not respond

**`NSScroller` starts `isEnabled = false`** — unlike every other control — which pins
`usableParts` at `.noScrollerParts`, so no knob is drawn and nothing responds, no matter
how `doubleValue`, `knobProportion` or `scrollerStyle` are set. Measured:

| State | `isEnabled` | `usableParts` |
|---|---|---|
| default (what the demo had) | **false** | `0` — no parts, dead track |
| after `isEnabled = true` | true | **`2` = `.allScrollerParts`** ✓ |

The demo already set `doubleValue` and `knobProportion`; the control was simply disabled.
Ruled out the tempting explanation first — `NSScroller.preferredScrollerStyle` is
`1` (**overlay**, which auto-hides) — by rendering all four style variants and confirming
**none** drew a knob. The style was never the problem. Fixed with `scroller.isEnabled = true`.

**Files touched**

- `Demo/DemoApplication/main.swift` — 13 captions; `isIndeterminate`; calendar width;
  `scroller.isEnabled`

**Verified**

- macOS: built and ran. Captions are captions; the bar tracks the slider; the clock is
  fully visible with the 168 height retained; the scroller shows a knob at 0.25.
- Linux: `RealDemo` error count **unchanged at 351** — every property used
  (`isIndeterminate`, `isEnabled`, the caption properties) exists in both frameworks.

**Follow-up — the `Clicks:` label steals keyboard input.** `counterLabel`
(`main.swift:1527`) is `NSTextField(string: "Clicks: 0")`, i.e. an editable field. It
takes first responder and swallows typing: during testing it captured stray keystrokes
and its text became `"ough for the apple clock"`. Same caption bug, but on the shared
header rather than the Values page, so it is untouched here. It affects **every page** and
is actively eating keyboard input — the remaining captions across all pages want the same
sweep.

---

## 2026-07-14 — Cover `NSForm` *and* its replacement; both are supported API

**Why there are now two form sections.** **Deprecated is not removed.** `NSForm` still
ships, still compiles and still works on macOS today, so **WinChocolate and LinChocolate
must support it at full parity for exactly as long as Apple does** — and must support the
recommended replacement alongside it. The demo therefore exercises both, and will keep
exercising both until Apple actually withdraws `NSForm`. The duplication is coverage of
two supported APIs, not a display of our own gap: **both sections must render correctly
on all three targets.**

| Position | What | Label |
|---|---|---|
| original spot (`y=120`) | **the replacement** — plain `NSTextField` rows | `Form:` |
| below the button matrix (`y=372`) | **the deprecated original** — `NSForm` | `Form:` + `NSForm — deprecated (macOS 10.10)` |

Apple's own deprecation text names the replacement: *"Use NSTextField directly instead,
and consider NSStackView for layout assistance."* The demo takes the `NSTextField`
half — `NSStackView` would add nothing here (two static rows) and LinChocolate's
`NSStackView` is a stub, so frame-positioned fields keep the page honest on all three.

**Borders.** The replacement rows need nothing — an `NSTextField` already carries the
same bezel as `Type here:`, `Password:` and `Price:`.

The deprecated `NSForm` was the opposite: its entries drew a heavy **white square
outline** in dark mode, unlike anything else on the page. The flags were not the cause —
`NSFormCell`'s defaults are already identical to `NSTextField`'s (`isBezeled = true`,
`isBordered = false`). The cause is the **cell class**: `NSFormCell` descends from
`NSActionCell` and draws an old-style bezel, while `NSTextField` uses `NSTextFieldCell`'s
modern one. `NSFormCell` has **no `bezelStyle`**, so the rounded bezel is unreachable.
Measured what is reachable:

| Config | Result |
|---|---|
| defaults (bezeled) | thick **white** square bezel — the reported problem |
| `setBezeled(false)` | no border at all |
| **`setBezeled(false)` + `setBordered(true)`** | thin subtle border — closest match ✓ |

So the demo uses the third. It is as close to the page's other fields as `NSForm` can
get, and the residual difference is itself a fair illustration of why Apple deprecated
the class.

**The `#if` is temporary scaffolding, and it must not survive.** Three calls are needed
to make `NSForm` render on Apple, and none exist on Win/Lin, so today they can only be
written conditionally:

```swift
#if !canImport(WinChocolate) && !canImport(LinChocolate)
form.cellSize = NSMakeSize(256, 26)   // rows collapse without it
form.setBezeled(false)                // else a heavy white outline
form.setBordered(true)
#endif
```

It is **not** a shim — it defines no missing API and fakes nothing; it sets real AppKit
properties that real AppKit requires. But it **is** AppKit-only code in a demo whose
whole purpose is that one source means one thing everywhere, so it is a defect to be
retired, not a pattern to copy. It exists solely because of the **MUST FIX** items below,
it is parked at the call site where it cannot be missed, and **every line of it is
deleted the day both frameworks match Apple.** Its presence is the measure of the debt.

### 🛠 MUST FIX — WinChocolate and LinChocolate

**Not optional, and not "legacy support".** `NSForm` is deprecated but **fully supported
API** — Apple ships it, our demo exercises it, and so both frameworks owe it exact parity
until Apple removes it. Each item below is a real divergence from Apple's surface, and
together they are the only reason the `#if` above exists.

**1. `NSForm.cellSize`, with Apple's `NSMatrix` semantics.** Apple's `NSForm` is an
`NSMatrix` subclass; both frameworks invented `rowHeight` instead and inherit from
`NSControl`/`NSView`. The intersection is empty, so *no* line the demo can write sizes
the rows on all three:

| | Row-height API |
|---|---|
| **AppKit** | `cellSize` (from `NSMatrix`) |
| **WinChocolate** | `rowHeight` — invented, not AppKit |
| **LinChocolate** | `rowHeight` — invented, not AppKit |

Preferably make `NSForm` a real `NSMatrix` subclass (bringing `cellSize`,
`intercellSpacing`, `autosizesCells`) and retire `rowHeight`. At minimum, expose
`cellSize` with Apple's semantics — **including the part that bites**: a matrix built
with `init(frame:)` starts at `cellSize.height == 0`, so rows collapse until the caller
sets it. Matching Apple means matching that default, not "helpfully" defaulting to 30.
Once it lands, the demo writes `form.cellSize = NSMakeSize(256, 26)` unconditionally.

**2. `NSFormCell` bezel/border control.** Apple's `NSFormCell` descends from
`NSActionCell` and inherits `isBezeled` / `isBordered` from `NSCell`; `NSForm` exposes
`setBezeled(_:)` / `setBordered(_:)`. Both chocolate `NSFormCell`s carry only
`title` / `titleWidth` / `stringValue`, so the demo cannot restyle the entries there at
all. Add Apple's accessors (`NSForm.setBezeled(_:)`, `setBordered(_:)`,
`setEntryWidth(_:)`, `setInterlineSpacing(_:)`, `setTitleFont(_:)`, `setTextFont(_:)`,
`setTitleAlignment(_:)`, `setTextAlignment(_:)` — all of which real `NSForm` responds to).

**3. Deprecation annotations, matching Apple's state.** Apple marks `NSForm` deprecated
since macOS 10.10, and the AppKit build emits:

```
warning: 'NSForm' was deprecated in macOS 10.10: Use NSTextField directly instead,
         and consider NSStackView for layout assistance
```

WinChocolate and LinChocolate emit **nothing** — they present `NSForm` as current API.
That is a faithfulness divergence in its own right: a framework's deprecation state is
part of its public surface, and the compiler is how developers learn it. Both frameworks
must carry `@available(..., deprecated:, message:)` wherever Apple does, with Apple's
version and message, so the same source produces the same warnings on all three targets.
`NSForm`/`NSFormCell` are the known case; the whole surface should be **audited against
Apple's annotations**, since anything Apple deprecated and we present as current is the
same bug. (Consequence to accept: once annotated, this demo will emit the deprecation
warning on all three — which is correct, and is the point.)

Note what an annotation is **not**: a licence to drop the API. Deprecated means *still
supported*, so annotating `NSForm` and fixing items 1–2 are the same job — the framework
must warn about it **and** implement it exactly, for as long as Apple does. The day Apple
removes `NSForm`, both frameworks remove it and the demo drops the deprecated section;
not before.

**Files touched**

- `Demo/DemoApplication/main.swift` — added `contactNameLabel` / `contactNameField` /
  `contactStatusLabel` / `contactStatusField` at the original spot; moved `form` +
  `deprecatedFormLabel` + `deprecatedFormNote` below the matrix; the `#if` now also
  carries the bezel/border calls

**Verified**

- macOS: built and ran. The replacement renders as two clean rows whose bezels match the
  page's other fields. The deprecated `NSForm` sits below the matrix under its label,
  with both rows laid out and a subtle border in place of the white outline.
- Linux: `RealDemo` error count **unchanged at 351** — the `#if` excludes it, and the
  replacement rows use only `NSTextField`.
- Windows: not built (no Win32 toolchain here). The `#if` excludes it; the replacement
  rows use only `NSTextField`.

---

## 2026-07-14 — Pop-up sized for Win32, captions built as input fields, unreadable popover, collapsed `NSForm`

Four separate bugs on the Controls page, all fixed demo-side.

### 1. `NSPopUpButton` sized with a Win32 drop-down height

**Symptom.** The Alert Style pop-up rendered far too tall and overflowed the bottom of
its `NSBox` by 46pt.

**Root cause.** The frame was `NSMakeRect(472, 186, 184, 96)`. **96** is a Win32
convention: a `COMBOBOX`'s creation height must include its drop-down list. On AppKit
(and GTK) the frame is just the button, which is ~26pt — WinChocolate's own
`intrinsicContentSize` says `height: 26`.

**Fix.** Height `96` → `26`. **Safe on Windows:** WinChocolate already absorbs the
Win32 quirk itself — `Win32PopUpControls.createPopUpButton` does
`height: max(frame.size.height, 160)` and tracks the drop-down height separately, so
the demo never needed to encode it.

### 2. Captions built as editable, bordered text fields

**Symptom.** `Alert style:`, `Form:` and `Matrix:` drew as rounded input fields rather
than captions. In the popover it was worse: the title showed a **focus ring and
selected text**, because it *was* an editable field that had taken focus.

**Root cause.** `NSTextField(string:)` is real AppKit, and it builds an **editable,
bordered, background-drawing** field — that is its documented purpose. A caption must
switch all of that off; the demo already knew this (`showcaseSectionLabel` does exactly
that) but these five sites didn't.

**Fix.** Applied the demo's existing caption idiom to `alertStyleLabel`, `formLabel`,
`matrixLabel`, `popoverTitle` and `popoverInfo`:

```swift
caption.isBordered = false
caption.drawsBackground = false
caption.isEditable = false
caption.isSelectable = false
```

### 3. Popover unreadable in dark mode

**Symptom.** Dark field bezels and a nearly invisible `Close` button on a light cream
surface — illegible.

**Root cause.** The content view hardcoded a **light** background
(`calibratedRed: 1.0, green: 0.94, blue: 0.84`) while its child controls and dynamic
label colors still resolved against the **dark** system appearance. A fixed light
surface under near-white dynamic text cannot work.

**Fix.** Resolve the surface from the appearance, using the demo's own established
idiom (the same one the collection-view section bands use), and let captions take
dynamic `.labelColor`:

```swift
let popoverDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
popoverContent.backgroundColor = popoverDark
    ? NSColor(calibratedRed: 0.26, green: 0.22, blue: 0.16, alpha: 1.0)   // warm dark
    : NSColor(calibratedRed: 1.00, green: 0.94, blue: 0.84, alpha: 1.0)   // cream
```

`NSView.appearance` would have been the tidier AppKit answer (pin the subtree to
`.aqua` and keep the cream in both modes), but **LinChocolate has no `NSView.appearance`**
— so it would not compile on all three. The appearance-resolving idiom above works
everywhere.

**Files touched**

- `Demo/DemoApplication/main.swift` — pop-up frame, five caption sites, popover surface

**Verified**

- macOS: built and ran. The pop-up now sits inside the Alert Style box; the three
  captions render as captions. The popover was verified in an isolated harness
  reproducing the exact construction (a synthetic click could not be posted — CGEvent
  and System Events both need accessibility permission this machine hasn't granted).
  It reproduced the reported bug precisely in *dark — before*, and is legible in both
  appearances after.
- Linux: `RealDemo` went **339 → 351** errors, and a message-level diff confirms the
  *only* new category is `NSAppearance.bestMatch` / `.aqua` / `.darkAqua` (11 → 13
  instances) — from the single `bestMatch` call added for the popover surface. That is
  a **pre-existing LinChocolate gap**, not a new kind of breakage: the demo already
  used `bestMatch` at 10 other sites, and it is real AppKit that LinChocolate has yet
  to implement. Every other property used (`isBordered`, `drawsBackground`,
  `isEditable`, `isSelectable`, `textColor`, `labelColor`) was checked to exist in both
  frameworks before building.
- Windows: not built (no Win32 toolchain here). The pop-up height change is safe by
  inspection of `Win32PopUpControls`, and all other API used exists in WinChocolate.

**Follow-up:** LinChocolate needs `NSAppearance.bestMatch(from:)` plus `.aqua` /
`.darkAqua`. It is the demo's standard way to resolve the appearance (11 sites) and is
plain AppKit, so LinChocolate cannot render any appearance-aware demo content until it
lands.

### 4. `NSForm` rows collapsed on top of each other

**Symptom.** `Name:` and `Status:` drew on the same line, overlapping, with a stray
thin white bar to the right.

**Root cause.** Apple's `NSForm` is an **`NSMatrix` subclass**, and a matrix built with
`init(frame:)` starts with **`cellSize.height == 0`**. Every row is therefore zero-tall:
the white bar was a collapsed entry field, and the 3pt offset between the two titles was
simply the default `intercellSpacing`. The caller must set the cell size — the demo
already knew this for its `NSMatrix` (`matrix.cellSize = …`) and just never did it for
`NSForm`.

Measured on real AppKit — **nothing else works**, only an explicit assignment:

| Attempt | resulting `cellSize` | row frames |
|---|---|---|
| **baseline (what the demo did)** | `(256, **0.0**)` | `y=0 h=0`, `y=3 h=0` — collapsed |
| `form.font` before *or* after `addEntry` | `(256, 0.0)` | collapsed |
| `autosizesCells = true` | `(256, 0.0)` | collapsed |
| `sizeToCells()` | `(256, 0.0)` | *worse* — shrinks the form to `h=3` |
| **`form.cellSize = NSMakeSize(256, 26)`** | `(256, 26)` | `y=0 h=26`, `y=29 h=26` ✓ |

> **Superseded by the entry above (same day).** The `#if` described below still exists,
> but it now guards the *deprecated* `NSForm` section, which moved below the button
> matrix — the original position shows Apple's recommended `NSTextField` replacement
> instead. The gap it marks is recorded as a **MUST ADD** for both frameworks there. The
> measurements below still stand.

**Fix — and why it carries a `#if`.** This is the one place the demo cannot state
itself identically on all three targets:

| | Row-height API |
|---|---|
| **AppKit** | `cellSize` (inherited from `NSMatrix`) |
| **WinChocolate** | `rowHeight` — **invented, not AppKit** |
| **LinChocolate** | `rowHeight` — **invented, not AppKit** |

The intersection is empty: `cellSize` does not compile on Win/Lin, and `rowHeight` does
not exist on Apple. Both frameworks size their rows internally, which is exactly why the
form looks right there and collapsed only on Apple. So the assignment is scoped to the
target that requires it, with the debt stated at the call site rather than hidden in a
helper:

```swift
#if !canImport(WinChocolate) && !canImport(LinChocolate)
form.cellSize = NSMakeSize(256, 26)
#endif
```

**This `#if` is a marker of a framework divergence, not a shim** — it defines no missing
API and fakes nothing; it sets a real AppKit property that real AppKit requires. It
should be deleted the moment WinChocolate and LinChocolate expose Apple's `cellSize`
(ideally by making `NSForm` an `NSMatrix` subclass, as on Apple, and retiring the
invented `rowHeight`). Tracked with Issue I.

**Verified.** macOS: built and ran — `Name: [WinChocolate]` and `Status: [Native]` now
render as two properly stacked rows, no overlap, no white bar. Linux: `RealDemo` error
count **unchanged at 351**, confirming the `#if` correctly excludes it.

**Aside:** the probe surfaced that **`NSForm` is deprecated as of macOS 10.10**
("Use NSTextField directly instead, and consider NSStackView for layout assistance").
It still works, and the demo exercises it deliberately, but that is worth knowing before
investing further in `NSForm` parity.

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
> > **ACTION — WinChocolate must implement `isFlipped`.** It currently does not
> > implement it *at all*: `open var isFlipped: Bool { true }` is a **dead property**
> > that nothing in the framework reads (verified — the declaration and one comment are
> > its only occurrences in `Sources/WinChocolate/`). It must become a real, honored
> > property: default `false`, overridable per view, and actually driving subview
> > positioning and drawing — not a constant that happens to describe Win32's origin.
> > LinChocolate already honors the property; only its *default* is wrong.
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

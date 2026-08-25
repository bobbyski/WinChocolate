# WASMChocolate — the 11-page demo in a browser

*Session of 2026-08-17. Branch `feature/TUI-WASM-Spike`. Plan:
[WASMChocolatePlan.md](WASMChocolatePlan.md) Part P phase P3.*

## Where it got to

**The full `WinChocolateDemo` catalog compiles for wasm, renders in a browser, and every phase of
the plan is complete.** All eleven pages navigate, take mouse and keyboard input, draw, scroll and
resize — and nothing on screen is a placeholder any more.

```
Compile errors, demo for wasm32, first attempt ........ 0
Placeholders on screen (all 11 pages) ................. 0   (the catalog is fully real)
Framework-drawn views painting on <canvas> ........... 43
Real typed DOM controls ............................. 103   (31 range, 30 select, 29 checkbox,
                                                             3 radio, 3 progress, 2 datetime,
                                                             1 password, 1 textarea, 1 fieldset,
                                                             2 img) + buttons and text fields
Partially-implemented controls (NSScrollView) ........   9
```

### Binary size (Part L phase L1, measured)

| Build | `.wasm` | gzipped — what a server actually sends |
|---|---:|---:|
| debug | 75.2 MB | 25.0 MB |
| **release** (`./build-wasm.sh --release`) | **45.6 MB** | **17.9 MB** |
| release + `wasm-opt -Os --strip-debug` | 45.6 MB | 17.9 MB |

`wasm-opt` buys **nothing**, and the section breakdown says why:

```
34.4 MB  data      ← static data, not code
11.0 MB  code
 0.2 MB  custom sections
```

Three quarters of the binary is the `data` section. `wasm-opt` optimises code, so there is
nothing there for it to take, and chasing optimiser flags is wasted effort. The lever is whatever
is emitting 34 MB of static data — Foundation and its tables are the obvious suspect, and
`swift-6.3.1-RELEASE_wasm-embedded` (already installed) is the documented alternative to
evaluate. Release build takes ~4m45s against a few seconds for debug, so keep iterating in debug.


Placeholders went **134 → 147 → 44 → 0**. The rise was the drawn-view detector *finding* 43 views
that had been rendering as blank boxes — visibility, not breakage. The falls were thirteen
control kinds becoming real, then the canvas seam clearing all 43 drawn views in a single change.
That last step is the detector's design paying off: it was built so the real renderer could be
swapped into the same drain loop, and nothing else had to move.

**No placeholders remain. Every control in the eleven pages is real.**

Zero errors was not the expectation — the plan budgeted half a day of burn-down against a
predicted "under 50", after CounterDemo's 873. Two reasons it came in free: `ChocolateKit`
already compiled for WASI, and the frozen demo contains no platform conditionals beyond its
import switches.

### Placeholder census

Empty. Re-take it any time with:

```js
Object.entries([...document.querySelectorAll('[data-cx-placeholder]')]
  .reduce((m, e) => (m[e.dataset.cxClass] = (m[e.dataset.cxClass] || 0) + 1, m), {}))
  .sort((a, b) => b[1] - a[1])
```

Pages verified by eye as well as by count: **Drawing** (paths, Bezier curves, text, embedded
image), **CoreGraphics** (CGPath curves, linear and radial gradients, transform rosette, a
CGImage round-tripped through the BMP codec, `NSImage(data:)`), and **Bezels** (six button bezel
styles, four segmented styles with selection, level indicators, token chips) all render as the
framework draws them.

## How to run it

```bash
./build-wasm.sh WinChocolateDemo
```

```bash
./build-wasm.sh --release --build WinChocolateDemo
```

Then open `http://localhost:8080/`. **Port 8080 was occupied by another app during this
session** (`FreebirdW` plus a stale CounterDemo server); use `PORT=8090 ./build-wasm.sh …` if
that is still true.

Page navigation does not need the toolbar. `browser.js` passes WASI args straight to
`CommandLine.arguments`, and the demo already reads `--page N`:

```bash
open 'http://localhost:8090/?page=7'
```

`?page=0…10`, `?stress`, and `?appearance=dark|light` all work, with no demo change.

## What changed

### Shared core — behaviour-preserving

- **`InMemoryNativeControlBackend`: ~90 writer methods moved from seven extension files into the
  class body**, under `// MARK: - Overridable core seam` sub-sections. *This was the blocker for
  the entire effort:* Swift cannot override a method declared in an extension, so the backend
  could only ever override the 16 methods that happened to live in the class body — which is
  exactly the 16 the spike had overridden. It was never a scoping choice; it was the ceiling.
  Getters stayed put: they read `records`, which a backend writes from its own event handlers,
  so the inherited answer is already correct. Verified as pure code motion — the public/internal
  method inventory is byte-identical to `HEAD` at 221 entries.
- **`NativeControlBackend` gained `wantsDebugClassNames` and `setDebugClassName(_:for:)`**, both
  defaulted, plus one guarded call in `NSViewSupport.winNSViewRealizeNativePeer`. No AppKit
  signature is touched — this is the internal backend seam, not the public AppKit surface, and
  it adds nothing to `NSView`. Win32, GTK and the recorder default to `false` and do not even
  pay for the string.

### Browser backend

- `WASMPlaceholders.swift` — the placeholder builder, the `kind → class` fallback table, caption
  rewriting, `data-cx-*` census attributes.
- `WASMPaintScheduler.swift` — the paint pass and the drawn-view detector (below).
- `WASMControlChrome.swift` — `NSColor`/`NSFont`/`NSTextAlignment` → CSS.
- `WASMValueControls.swift` — checkbox, radio button, slider, combo box.
- `WASMSimpleControls.swift` — progress, secure field, text view, group box, stepper, image view,
  scroller, date picker, and the truncated-extension repair.
- **Thirteen real control kinds** in `WASMNativeControlBackend`: `<select>`, `<input>`
  checkbox/radio/range/password/datetime-local, `<input list>` + `<datalist>`, `<progress>`,
  `<textarea>`, `<fieldset>`, `<img>`, `<table>`, a tab strip, and a stepper built from its two
  arrows — **every `create*` method is now real**. Plus a real `createScrollView`, the shared
  chrome setters
  (`setBackgroundColor`, `setFont`, `setTextColor`, `setTextAlignment`, `setToolTip`),
  `destroyControl` cleanup, and `primaryScreenFrame`/`screenDescriptions` from the viewport.
- **`setClipsToBounds(_:for:)` is a new backend seam** — defaulted no-op, called once from
  `NSClipView.createNativePeer`. Win32 child HWNDs and GTK child widgets are already confined by
  the platform, so nothing was ever asking a backend to clip; an absolutely-positioned `div` is
  not, so a clip view showed its whole document. The GTK backend already had a
  `setClipsToBounds` written and unused — promoting the method to a protocol requirement means
  its existing implementation simply starts being called.

### Finding a control that refuses to say what it is

`NSSegmentedControl`, `NSColorWell`, `NSTokenField`, the drawn `NSTableView`, `NSToolbarView`
and every custom `draw(_:)` view are plain `NSView`s that paint themselves. They call
`createView` + `registerDrawAction`, so from the backend's side they are indistinguishable from
an empty container — they were the last place this backend still failed silently.

They cannot be found by name, because being any class at all is the point. They can be found by
**asking**: run the view's registered draw action into the `RecordingDrawingContext` that
already exists, on a `requestAnimationFrame` drain, and count what it emits. Nothing means a
plain container. Anything means a view that would have drawn. That found 43 of them, each
captioned with its real class and its pending operation count — `DemoShapesView ✎11`.

When the canvas context lands it replaces `RecordingDrawingContext` inside the same drain loop
and nothing else moves.

**One refinement was forced immediately, and it is worth keeping.** The first version striped
every drawn view, which put hazard tape over the entire window — because the page backdrops and
every `DemoFilledView` "draw themselves" too. But a view whose whole drawing is a single fill
covering its bounds is not unsupported; it is a background colour, and CSS has those. That case
now renders for real (`coversBounds` in `WASMPaintScheduler.swift`, straight-edged paths only —
a curve means a shape, and a shape is not a background). More honest than a placeholder, and
less work than explaining the tape.

### The canvas seam

`WASMCanvasDrawingContext` implements all nine `NativeDrawingContext` methods over Canvas 2D and
drops into the paint drain the detector already built — the `RecordingDrawingContext` swap the
earlier design promised, with nothing else moved. Three points were where AppKit and the canvas
genuinely disagree, each resolved once and centrally rather than per caller:

- **Text origin.** `drawText` places a run by its top-left corner; `fillText` uses the alphabetic
  baseline. `textBaseline = "top"` is set once in the initialiser.
- **Gradient angle.** AppKit measures degrees with +y running *up*; the canvas has +y running
  down. One negation, at the angle, and the rectangle is projected onto the gradient axis so the
  end stops land exactly on the edges at any angle.
- **Device pixels.** The backing store is sized in device pixels and every drawing call is in
  points, so `devicePixelRatio` is applied once as a context scale and nowhere else.

Two things needed real thought rather than mapping:

- **Images decode asynchronously; drawing does not.** A cache miss draws nothing and asks for a
  repaint, so the image appears on the next frame. This is the reason the paint pass had to be a
  *scheduler* and not a one-shot — a decision made before there was any image to draw.
- **`putImageData` ignores scaling and the clip region.** RGBA bitmaps therefore go into an
  offscreen canvas first and that canvas is drawn, which honours the destination rectangle and
  the clip like any other image.

A view whose whole drawing is a single bounds-covering fill still takes the CSS `background-color`
path instead of getting a canvas — that keeps hundreds of canvases off the page and is exact, not
an approximation. The captioned placeholder survives as the fallback for a view whose 2D context
cannot be obtained, so that case is still visible rather than an empty box.

### SwiftDOM, upstream

Per the standing decision, gaps were fixed in SwiftDOM rather than worked around. Landed there:
`bezierCurveTo`, `quadraticCurveTo`, `clip(fillRule:)`, `measureText` + `TextMetrics`,
`createLinearGradient` / `createRadialGradient` + `CanvasGradient.addColorStop`, `drawImage`,
`createImageData` / `putImageData` + `ImageData.setPixels`, `setLineDash`, `lineCap`, `lineJoin`,
`textBaseline`, `globalCompositeOperation`, and `Window.devicePixelRatio`. README checklist
updated. **No spike markers remain anywhere in the backend** — `grep -r "// SPIKE:" Sources/`
returns nothing.

### Window chrome, and two bugs only a resize could expose

Drag-to-move, a corner resize grip and a dock live in `WASMWindowChrome.swift`. Resizing was
pulled ahead of tables and input plumbing deliberately: the catalog's Auto Layout page instructs
the reader to *"resize the window → the green middle box reflows live"*, and until a grip existed
that was an instruction the browser build could not follow — the constraint solver and every
autoresizing mask in the demo were untested here rather than merely unfinished.

Enforcing `contentMinSize` / `contentMaxSize` turned out to be the **backend's** job, not the
core's: `NSWindow.frame` is a plain stored property, so the core records whatever size it is told
and pushes nothing back. Win32 does this in `WM_GETMINMAXINFO`; here it is arithmetic in
`clampedContentSize`.

`setWindowMinimized` was already a seam and already an honest no-op, so a miniaturized window
vanished with nowhere to go. A browser has no system dock to inherit, exactly as it has no window
server — so the backend supplies one, in the same place and for the same reason as the desktop.

Two bugs surfaced the moment a window could change size, and both had been invisible before:

1. **A canvas-painted view kept a stale canvas after `setFrame`.** The framework relays out and
   pushes new frames down, but never calls `invalidateControl` — on Win32 and GTK a resized child
   repaints on its own. Every constrained box reflowed correctly while its artwork stayed put,
   which looks exactly like a layout engine that did not run. `setFrame` now marks a drawn view
   dirty **only when the size actually changed**: marking unconditionally deadlocks the page,
   because a view's `draw(_:)` can lay out its subviews, each `setFrame` re-marks, and the next
   frame repaints and re-marks forever. The tab pegs at 100% and renders nothing — which reads as
   "the canvas seam broke" rather than "the canvas seam never stops".
2. **One missed animation frame latched painting off for the lifetime of the page.** Every view
   realizes *before* `run()` is reached, so the first `requestAnimationFrame` was requested while
   wasm `main` was still on the stack, and it never fired. `isPaintScheduled` stayed `true`, every
   later mark was suppressed as "already scheduled", and 43 canvases became 0 — from a single
   dropped frame, with no error anywhere. `runApplication()` now calls `flushPaint()` after
   mounting, which clears the latch and paints the tree the demo built during startup.

The second one is worth remembering as a shape, not just a bug: **a boolean "already scheduled"
guard is a latch, and any path that can drop the scheduled callback disables the subsystem
silently and permanently.**

### Demo

Thirteen import switches gained a WASI arm. **Nothing else.** `git diff --stat` over
`Demo/DemoApplication/` is 13 files, +39/−13, all of it the import block.

## Two findings worth keeping

**1. A placeholder is not decoration — it is structural.** `register(_:element:parent:)` attaches
a child to the element filed under its parent's handle. A `create*` that produces no element
does not merely fail to draw itself: every descendant is orphaned and whole sections of the page
vanish with no error. That is why `createScrollView` had to be implemented rather than skipped,
and why placeholders are containers that do not clip their children.

**2. `visibility: visible` broke the entire demo, and `visibility: hidden` was innocent.** The
first render drew all eleven pages on top of each other. The page views *were* correctly hidden
— but `setHidden` wrote `visibility: visible` on every *shown* control, and the framework calls
it on every control during realization, so each child overrode its hidden ancestor. The fix is
to clear the property instead of setting `visible`, letting it inherit. That also happens to be
what AppKit means: a subview of a hidden view is not drawn, whatever the subview thinks.

## Every phase is complete

The plan's ten phases are all done, in order — see the dashboard at the top of
[WASM_CHOCOLATE_PLAN.md](WASM_CHOCOLATE_PLAN.md) (72 / 72 items). What landed after the canvas
seam:

- **The four stragglers**, cleared first because the rules say phases complete in order:
  `installGlobalExecutor` (never called before, so `Task`/`@MainActor` had no executor),
  `scheduleNativeTimer` → `setInterval` (**the Values page's tick was simply dead**; it now
  advances 19s → 34s), `setViewFlipped` with real y-inversion for views that measure children
  from the bottom, `createTabView`, and scroll geometry.
- **`NSTableView` as a real `<table>`** — sticky header, 28 rows, click-to-select, click-to-sort
  drawing `Name ▲`. This removed the last band: **the census is now 0.**
- **Input** — pointer down/up/move/drag/leave, right-click (suppressing the browser menu),
  wheel, keys, focus and per-keystroke text change. Verified against the demo's own labels: a
  click at window point (300, 200) reports `Mouse up at 300, 200`, focus tracks the first
  responder, typing shows `Form: abc — Native`.
- **Toolbar chrome.** A toolbar item's view arrives as a plain view whose *text* is a
  tab-separated descriptor (`__WinChocolateToolbarItem\ttitle\timagePath\t…`) that Win32 and GTK
  both parse. A backend that does not parse it renders the descriptor as literal text — which is
  exactly what the top of the window showed. Now parsed into an icon and label.

### Two seams that had to be promoted, again

`setViewFlipped` and `setClipsToBounds` were both satisfied by *protocol extension defaults*, so
neither was an overridable class member — the W-H9 trap one level up. Both are now declared in the
recorder's class body. That is the third and fourth time this pattern has bitten; any new
requirement a backend must override belongs in the class body from the start.

## The bug that made a finished UI look unfinished

Everything rendered, and almost nothing responded. Buttons worked; segmented controls, colour
wells, level indicators, token fields and every custom `draw(_:)` view took their clicks and did
nothing visible.

The clicks were arriving — the demo's own label reported `Mouse up at 300, 200` throughout. The
controls were updating their state and marking themselves dirty. **The repaint never ran.**

`requestAnimationFrame` does not fire for frames requested from inside a wasm call in this
runtime. The initial paint survived only because `runApplication()` flushes the queue
synchronously; every repaint after that was scheduled onto a frame that never came. `dispatchAsync`
had been quietly proving the alternative all along — it uses `setTimeout` and works — so the drain
now uses `setTimeout(0)`. Coalescing is unchanged: `isPaintScheduled` still collapses a burst of
invalidations into one drain.

This is the third failure of the same shape in this backend, and the shape is worth naming:
**a paint that is scheduled but never delivered is indistinguishable from input that never
arrived.** Both times the visible symptom pointed at the wrong subsystem — first "the canvas seam
broke", then "the controls are dead" — and both times the fault was the scheduler.

Verified after the fix: clicking each of the four `NSSegmentedControl` styles moves the selection
(Month → Week across all four), the disclosure bezels flip ▲ → ▶, `Bold` toggles, and the
`NSLevelIndicator` rating and capacity bars redraw.

## Four defects found by using it, and what they taught

**1. Closing a window left a dead frame.** `nativeWindowDidClose()` — the title-bar path —
deliberately does *not* call `closeWindow`: on Win32 and GTK the window server is already
destroying the window when the title bar is clicked, so closing it again would be wrong. Here
there is no window server but this backend. The core tore out the content view and nil'd its
handle, and what stayed on screen was an empty box with a working close button and nothing in it.
The close box now runs the whole job — ask `shouldClose`, tell the core, then destroy the element
— and `discardWindowElement` is idempotent because a programmatic `close()` arrives twice.

**2. Right-clicking the toolbar did nothing.** `runContextMenu` was never implemented. It now
renders a real menu (Icon and Text ✓ / Icon Only / Text Only / Customize Toolbar…) and each row
performs its action — picking "Icon Only" strips the labels immediately. It returns `nil`, always:
the protocol wants the chosen item back *synchronously* and a page cannot block for a click. GTK
returns nil for the same reason, and nothing depends on the return value because rows call
`item.performAction()` directly.

**3. The Customize Toolbar palette printed file paths.** The toolbar has a *second*
text-as-descriptor protocol — `NSToolbarCustomizationTile` sets a view's text to
`"title\nimageName"` — and no backend special-cases it, so GTK renders the image name as a second
line too. Tiles now render as icon above label. Distinguishing a tile from a genuine two-line
caption is safe rather than clever: a real caption is an `NSTextField` and arrives as kind
`textField`, so only a bare `view` with exactly two lines is a tile.

**4. Toolbar height — not reproduced.** Measured in this build, the toolbar host is 40 px and
every item fits inside it (tallest bottom edge 37 px; the search field is 24 px at y=8). Nothing
overflows, so there was nothing to fix without inventing one. If it recurs, capture the toolbar
host's height and its children's bottom edges — that measurement is the whole diagnosis.

The first three share the shape that has run through this whole backend: **the core assumes a
window server exists**, and on every other platform it does. Each fix is the backend supplying
the part of the OS that a page does not have.

## Round two: what a real user found

**Fixed**

- **Popover never appeared.** `NSPopover.show` branches on `animates`, which defaults to `true`,
  so it calls `fadeWindow(_:visible:)` — never `orderFrontRegardless`/`showWindow`. That method
  was inherited from the recorder, so the popover was built, positioned, told to appear, and
  never displayed. `fadeWindow` now shows and hides with an opacity transition, and
  `beginOutsideClickDismiss` is implemented too — a transient popover is borderless, so an
  outside click is the *only* way it can be closed.
- **Context-menu items did nothing.** My own bug, and an instructive one: the menu dismissed on
  `pointerdown`, which fires *before* `click`, so the row was torn out of the document before its
  own click could land. It now dismisses only on a press *outside* the sheet. Worth noting that
  my synthetic test dispatched `click` directly and therefore passed — the test was wrong, not
  the report.
- **Controls ignoring their frame.** `createTextField`/`createButton` never set `box-sizing`, and
  an `<input>` defaults to `content-box` — a 24-point field rendered ~36 and hung out of the
  toolbar. Now set once in `register()`, the choke point every control passes through.
- **Toolbar height** is now a 44-point minimum for icon-and-label (36 small). It remains a floor:
  `max(baseHeight, customHeight + 8)` still grows the strip for a taller custom view.

**Diagnosed, not fixed — each needs a decision rather than a patch**

- **Alert and Ask to Save do nothing.** The demo uses `beginSheetModal(for:completionHandler:)`,
  which is *asynchronous by contract* — exactly the API a browser can honour. But ChocolateKit
  implements it **synchronously**: it computes the response via `runComposedPanel` → `runModal`
  and then calls the handler. `runModal` cannot block in a page, so the panel is shown and closed
  within one turn. The real fix is to make `beginSheetModal` genuinely async in the core — show
  the sheet, return, and invoke the handler when a button is clicked. That would also bring
  Win32 and GTK closer to Apple's contract, which is why it deserves a deliberate change rather
  than a browser-only workaround.
- **Price shows `¤1,234.50` instead of `$`.** Grouping and decimals are right, so
  `NumberFormatter` works; it is the *currency symbol* that is missing, because
  swift-corelibs-foundation on WASI has no locale data and falls back to the generic currency
  sign. The demo constructs its own `NumberFormatter`, so a shim inside ChocolateKit would not
  reach it, and a public shadow risks the very ambiguity this project already documents for
  `WinFoundation`. Options: ship locale data with the wasm build, or shadow the type somewhere
  the demo sees — a decision, not a patch.
- **Customize-panel drag and drop.** Pointer events now reach the tiles, but completing a drop
  goes through the drag-and-drop seam (`registerDropTarget`/`performDrag`), which the plan lists
  as out of scope because `DataTransfer` file access is incomplete upstream in SwiftDOM.

## Why a framework drag needs three separate things in a browser

The toolbar customization drag failed in two different ways at once — items with icons dragged
but never dropped, items without icons would not move at all — and it took three fixes, each
addressing a genuine mismatch between AppKit's input model and the DOM's.

1. **The browser's own gesture wins.** Press-and-drag on a view starts a *text selection*, which
   preempts the framework's drag entirely: the tiles sat still while every label on the panel
   turned blue. Non-editable controls now carry `user-select: none` and their press calls
   `preventDefault()`. Editable kinds are excluded — a field you cannot select inside is worse
   than the bug.
2. **The pointer must stay with the view it pressed.** AppKit delivers every `mouseDragged` and
   the final `mouseUp` to the view the drag *started* on. The DOM delivers them to whatever is
   under the cursor, so a drag died the moment the tile moved out from under the pointer, and the
   release landed on the toolbar instead of the tile — which is exactly "drags but never drops".
   `setPointerCapture` on press restores AppKit's rule (added to SwiftDOM).
3. **A press belongs to one view, not to all of its ancestors.** `hitTest` picks a single view;
   a DOM event bubbles. A press on a tile was delivered to the tile, its container *and* the
   panel's content view, each believing it had been clicked. `onPointer` now stops propagation,
   and because listeners run innermost-first that leaves precisely the hit view.

Fix 3 has a consequence worth remembering: presses inside a view no longer reach `document.body`,
so the popover and context-menu dismissal listeners moved to the **capture phase**, which runs
before bubbling is stopped.

Verified end to end with real mouse input: dragging `Print` — an item with no icon, the class
that previously would not move — from the palette into the strip adds it to the panel's toolbar
*and* the live window toolbar, and greys its palette tile because it is now in use.

## Do one clean Linux build after pulling this

`InMemoryNativeControlBackend` gained a stored property (`debugClassNames`), which changes the
class's memory layout. SwiftPM's incremental build did not recompile everything against the new
layout, and the stale objects crashed the contract suite in
`swift::RefCounts::doDecrementSideTable` — a Bus error during ordinary dictionary access, three
tests earlier than the real failure, and perfectly reproducible. It looks exactly like a
memory-corruption regression and is not one.

```bash
docker run --rm -v /Users/bobby/AIResearch/WinChocolate:/work -w /work linchocolate-dev bash -c 'swift build --scratch-path /tmp/clean --product WinChocolateContractTests && xvfb-run -a swift run --scratch-path /tmp/clean WinChocolateContractTests'
```

A clean build reaches exactly the `HEAD` baseline failure below and nothing else — which is the
evidence that this session introduced no regression. If you see a refcount crash, rebuild clean
before believing it.

## WASI's `Bundle` truncates resource extensions

Found by looking at what actually reached the backend rather than trusting the mount. The demo
asks for `WinChocolateArtworkDemo` of type `bmp`; swift-corelibs-foundation's
`Bundle.path(forResource:ofType:inDirectory:)` on WASI returns

```
/Resources/WinChocolateArtworkDemo.bm
```

— the last character of the extension is gone, **and the path is returned for a file that does
not exist**, so the lookup fails silently rather than returning `nil`. ChocolateKit does not shim
`Bundle`, so this is upstream, not ours.

Two useful consequences:

1. **It confirms the resource mount works.** That path is rooted at `/Resources/`, which is one of
   the three aliases `Demo/WinChocolateDemo/index.html` mounts — so `Bundle` really is resolving
   against the WASI preopen filesystem, and `Bundle.main.bundlePath` is `/`. That was the open
   question left over from Phase 0; it is now answered.
2. **The repair belongs at the boundary, not in the demo.** `repairingTruncatedExtension` in
   `WASMSimpleControls.swift` completes an extension only when it is a *proper prefix* of one the
   demo ships, so a genuine `.bm` file would still be requested as `.bm`. The artwork now loads
   (300×190).

Still absent, and correctly so: `WinChocolateIconDemo.ico` is generated at runtime into the WASI
filesystem, which the static file server never sees. A runtime-written file is not a shipped
resource, and pretending otherwise would mean serving something the app did not produce.

## Pre-existing bug found on the way — not caused by this work

**The Linux contract test suite is red at `HEAD`.** Verified in a clean `git worktree`, so it
predates this branch's changes.

```
TestDeclarations01.swift:5: Fatal error: willAddItemNotification did not post
through NotificationCenter. Got 0.
  from testToolbarSelectionAndDelegateCallbacks() at TestDeclarations10.swift:545
```

Root cause, isolated with two standalone probes in the `linchocolate-dev` container:

| Observer's `object:` filter | Observer fires? |
|---|---|
| a Foundation `NSObject` subclass | yes |
| a **plain Swift class** instance | **no** — while an `object: nil` observer on the same name fires normally |

swift-corelibs-foundation's object filtering only matches Foundation `NSObject` subclasses; a
plain Swift class gets boxed, and two boxes of the same instance do not compare equal.
ChocolateKit's `NSObject` is a plain Swift class with no ObjC runtime. **So on Linux, every
`NotificationCenter` observer that filters by a Chocolate object silently never fires.** That is
much broader than the one test — ordinary app code doing
`addObserver(forName:object: someWindow, …)` is equally dead.

Posting site: [NSToolbar.swift:261](../Sources/ChocolateKit/Windows/NSToolbar.swift). One
candidate fix is to use ChocolateKit's own `NotificationCenter` (already written for WASI in
`WASIFoundationShims.swift`, and free of this problem) on Linux too, via the same module-local
shadowing, which needs no call-site changes. Windows uses `WinFoundation` and needs checking
separately. Filed as its own task; **not** fixed here, because it is unrelated to the browser
backend and deserves its own regression run.

Reproduce:

```bash
docker run --rm -v /Users/bobby/AIResearch/WinChocolate:/work -w /work linchocolate-dev bash -c 'swift build --product WinChocolateContractTests && xvfb-run -a swift run WinChocolateContractTests'
```

Note `run-linux.sh` hardcodes `docker run -it`, which fails from a non-interactive shell — hence
the direct `docker run` above.

## Next, in order

1. **`createTableView`** — the last placeholder in the catalog.
2. **Scroll geometry** (`setScrollViewContentSize` / `setScrollViewContentOffset`) — the nine
   partial `NSScrollView`s clip correctly but do not scroll their document.
3. **Z-order and key window** (`orderFront` / `orderOut`, click-to-activate) — the dock and the
   drag both assume one window at a time; a second window will want a z-index ladder.
3. **Scroll geometry** (`setScrollViewContentSize` / `setScrollViewContentOffset`), which turns
   the nine partial `NSScrollView`s into real ones.
4. **Input plumbing** — mouse, keys, focus, `registerTextChangeAction`. The value controls report
   through their own events already; this is what the drawn and custom views need.

## Loose ends

- The toolbar area draws its items overlapped — the toolbar placeholder hosts real custom-view
  items but does not lay the framework-drawn ones out. Cosmetic, and it goes away with the
  canvas seam.
- The `.ico` the demo writes at runtime never appears: it is created inside the WASI filesystem,
  which the static file server cannot see. Correct as it stands — a runtime-written file is not
  a shipped resource.
- `NSPopUpButton` selection writes back into `records` from the `change` listener, which is what
  lets the inherited getters stay correct without overriding any of them. Follow that pattern
  for every value control in step 1 — it is the labour saving that makes them small.

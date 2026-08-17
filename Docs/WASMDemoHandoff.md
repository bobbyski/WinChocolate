# WASMChocolate — the 11-page demo in a browser

*Session of 2026-08-17. Branch `feature/TUI-WASM-Spike`. Plan:
[WASMChocolatePlan.md](WASMChocolatePlan.md) Part P phase P3.*

## Where it got to

**The full `WinChocolateDemo` catalog compiles for wasm and renders in a browser.** All eleven
pages are reachable, every control is either real or a captioned "under construction"
placeholder, and no page is silently missing.

```
Compile errors, demo for wasm32, first attempt ........ 0
Placeholders on screen (all 11 pages) ................ 134
Partially-implemented controls (NSScrollView) ........   9
Debug .wasm .......................................... 78.5 MB
```

Zero errors was not the expectation — the plan budgeted half a day of burn-down against a
predicted "under 50", after CounterDemo's 873. Two reasons it came in free: `ChocolateKit`
already compiled for WASI, and the frozen demo contains no platform conditionals beyond its
import switches.

### Placeholder census, by class

| Class | Count | | Class | Count |
|---|---:|---|---|---:|
| NSButton | 32 | | NSSecureTextField | 1 |
| NSPopUpButton | 30 | | NSBox | 1 |
| NSSlider | 30 | | NSTextView | 1 |
| NSComboBox | 29 | | NSStepper | 1 |
| NSProgressIndicator | 2 | | NSLevelIndicator | 1 |
| NSDatePicker | 2 | | NSScroller | 1 |
| | | | NSTableView | 1 |
| | | | NSImageView | 1 |
| | | | DemoClickableImageView | 1 |

This is the baseline. Every later phase is measured as a drop in it. Re-take it any time with:

```js
Object.entries([...document.querySelectorAll('[data-cx-placeholder]')]
  .reduce((m, e) => (m[e.dataset.cxClass] = (m[e.dataset.cxClass] || 0) + 1, m), {}))
  .sort((a, b) => b[1] - a[1])
```

`NSLevelIndicator` and `DemoClickableImageView` in that list are worth noticing: neither is
knowable from the backend's coarse `kind` strings — both arrive through `setDebugClassName`,
which is the hook working as designed.

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
- 17 `create*` overrides in `WASMNativeControlBackend`, plus a real `createScrollView`,
  `destroyControl` cleanup, `primaryScreenFrame`/`screenDescriptions` from the viewport, and a
  scrollable desktop.

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

1. **The drawn-view detector.** Framework-drawn controls (`NSSegmentedControl`, `NSColorWell`,
   `NSTokenField`, the drawn `NSTableView`, `NSToolbarView`, and the demo's own `draw(_:)` views
   like `DemoFilledView`) call `createView` + `registerDrawAction`, so they are currently empty
   boxes rather than placeholders — the one place coverage is still silent. Build the paint
   scheduler from the plan: a dirty-handle set drained on `requestAnimationFrame`, running each
   draw action into the existing `RecordingDrawingContext` and captioning any view whose command
   count is non-zero. The same drain loop later hosts the real canvas context, so nothing is
   thrown away.
2. **Chrome** — `setBackgroundColor`, `setFont`, `setTextColor`, `setTextAlignment`, `setToolTip`.
   ~40 lines that improve all eleven pages at once.
3. **A real `createPopUpButton`** over `<select>` — 30 placeholders, and it is the page selector.
4. Then form controls, scroll geometry, the canvas seam, tables.

Resources are mounted but unverified: `Bundle.main.bundlePath` on WASI has not been printed yet,
so it is not yet known which of the three mount aliases in `Demo/WinChocolateDemo/index.html`
the demo actually resolves through. Check that before trusting the image paths.

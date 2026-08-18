# WASMChocolate → the full 11-page demo in a browser

## Dashboard

**Overall complete:** `█████████████████████████` **100%** (72 / 72 items)

Percent measures progress toward each phase's **milestone**, as Bobby defines it
(`AICoding rules.md`, "What a phase is").

| # | Phase | Progress | % | Status | Notes |
|--:|---|---|--:|---|---|
| 0 | [Build, render, resources, navigate](#phase-0--compile-render-navigate) | `█████████████████████████` | 100% | ✅ Done | `installGlobalExecutor` now called before any `Task` |
| 1 | [Seam move, placeholders, paint pass](#phase-1--the-seam-move-and-the-placeholder-sweep) | `█████████████████████████` | 100% | ✅ Done | S1 landed upstream; no escape hatches remain |
| 2 | [Chrome + page switcher](#phase-2--chrome-and-the-page-switcher) | `█████████████████████████` | 100% | ✅ Done | timers live — the Values tick advances; `setViewFlipped` honoured |
| 3 | Form controls | `█████████████████████████` | 100% | ✅ Done | all 13 kinds real, `NSTabView` included |
| 4 | Scroll views, clip views, images | `█████████████████████████` | 100% | ✅ Done | document element sized; offsets applied |
| 5 | `NativeDrawingContext` over Canvas 2D | `█████████████████████████` | 100% | ✅ Done | all 9 methods; 43 views painting |
| 6 | [Window resize + dock](#phase-6--window-resizing-and-somewhere-to-minimize-to) | `█████████████████████████` | 100% | ✅ Done | Auto Layout reflows live; dock restores |
| 7 | Real `<table>` for `NSTableView` | `█████████████████████████` | 100% | ✅ Done | real `<table>`: sticky header, row selection, click-to-sort |
| 8 | Mouse, key, focus, text-change | `█████████████████████████` | 100% | ✅ Done | mouse/right-click/wheel/keys/focus/text-change all reach the responder chain |
| 9 | `runAlert` + toolbar chrome | `█████████████████████████` | 100% | ✅ Done | `runAlert` over `window.confirm`; toolbar items render as chrome |

**Status key:** ✅ Done · 🔄 In Progress · ⏳ Pending · 🚫 Blocked/Gated
**Change-class icons:** 🧩 A companion · ➕ B additive · ⚠️ C reorganization · 🛑 D breaking

**Change class of this work: ⚠️ C.** No AppKit signature changed and no public API was removed,
but ~90 writer methods moved between files in the shared recorder and four backend-seam
requirements were added (`setDebugClassName`, `wantsDebugClassNames`, `setClipsToBounds`,
`setViewFlipped` promoted from a protocol default) — all defaulted, so Win32 and GTK are
untouched at the call site.

### The counted metric

The bars above are judgement. This is not — every unbuilt control renders with
`data-cx-placeholder`, so "how much of the catalog is real" is a query against the served page:

```js
Object.entries([...document.querySelectorAll('[data-cx-placeholder]')]
  .reduce((m, e) => (m[e.dataset.cxClass] = (m[e.dataset.cxClass] || 0) + 1, m), {}))
  .sort((a, b) => b[1] - a[1])
```

| Measured on the catalog | first render | now |
|---|---:|---:|
| Compile errors, demo for wasm32 | **0** | **0** |
| Placeholders on screen (all 11 pages) | 134 | **0** — the catalog is fully real |
| — framework-drawn | 0 | 0 — all 43 paint on canvas |
| Real typed DOM controls | 0 | 103 |
| Scroll views with real geometry | 0 | 9 |
| Debug `.wasm` | 78.5 MB | 75.2 MB |
| **Release `.wasm`, gzipped** | not measured | **17.9 MB** |

Release is 45.6 MB raw. `wasm-opt` buys nothing: **34.4 MB of the 45.6 is the `data` section**
and only 11.0 MB is code, so the lever is whatever emits 34 MB of static data
(`swift-6.3.1-RELEASE_wasm-embedded` is installed and unevaluated).

**Regression gate, green:** macOS `swift build`, the wasm build and a clean Linux build all pass;
the contract suite reaches the same pre-existing `NotificationCenter` failure that exists at
`HEAD` and nothing else.

**Verified live, not assumed:** the Values page timer advances (19s → 34s); the table's 28 rows
select on click and its headers sort, drawing `Name ▲`. Every `<ClassName> under construction`
band is gone — there is nothing left in the eleven pages that only pretends to be a control.
Input is verified against the demo's own labels: a click at window point (300, 200) is reported as
`Mouse up at 300, 200`, focus tracks the real first responder (`Focus: toolbar search` → `text
field` → `form`), and typing shows `Form: abc — Native`.

### The one thing that still cannot work — and why it is not a bug

`NSAlert.runModal()` takes the browser-dialog path only when the alert is plain
(`winCanUseNativeMessageBox`: no custom buttons, icon, help or suppression). The demo's alert has
custom buttons, so it takes `runComposedPanel` — a framework-drawn panel that needs a **nested
modal run loop**. A page cannot block, so the panel is created and immediately hidden and
`runModal` returns a default: the desktop shows a 420 px window with `display: none` after the
Alert button is clicked.

This is plan row **W-H2**, predicted before any code was written, and it is the boundary of what a
browser can honour rather than something left undone. `window.alert`/`confirm` genuinely block and
back the plain path; every other modal — file, colour and font panels — has async-only browser
APIs and stays an honest no-op until JSPI (wasm stack switching) ships.


## Context

The spike (`00efc59`) proved the browser backend works: `WASMNativeControlBackend` renders
CounterDemo to the DOM over SwiftDOM, the click path fires, File→Quit terminates through the
responder chain. That is Part P phase P1 of [Docs/WASMChocolatePlan.md](Docs/WASMChocolatePlan.md).

This plan executes **P3** — `Demo/DemoApplication`, the 5,552-line, 11-page control catalog —
under three constraints Bobby set:

1. **No demo changes** beyond adding the WASI arm to its 13 import switches.
2. **Easy wins first** — optimize for time-to-"the whole demo renders".
3. **Every unimplemented control renders as `<ClassName> under construction`**, so the demo is
   visually complete and measurably incomplete from day one.

And one standing constraint: **the branch must stay mergeable at any moment.** Every change is
additive or behaviour-preserving; Windows, Linux, macOS and the contract suite are a gate on
every commit, not a final check.

### Decisions taken (asked and answered)

| Question | Answer |
|---|---|
| SwiftDOM gaps (measureText, gradients, drawImage, clip, ImageData, matchMedia) | **Fix upstream in SwiftDOM as each is hit.** No new `// SPIKE:` escape hatches; the one existing marker in `measureText` is retired in Phase 1. |
| Window presentation | **Floating window on a synthesized desktop**, as the spike does — same shape Win32/GTK produce. No viewport mode. |
| Resources (images, .xib) | **Wired in Phase 0** — populate the WASI preopen filesystem from `fetch()` so `Bundle.main.path` and `NSImage(contentsOfFile:)` work verbatim. |

---

## The blocking finding — read first

> **✅ RESOLVED 2026-08-17.** Confirmed exactly as predicted (`error: non-'@objc' instance method
> is declared in extension of 'Base' and cannot be overridden`), and cleared: ~90 writer methods
> moved into the recorder's class body, verified as pure code motion at 221 identical method
> names. Kept here because it is the reason the plan is shaped the way it is, and because the
> same trap recurs for protocol-extension defaults — see the note at the end of this section.

**The WASM backend currently cannot override any of the 22 `create*` methods.** This is a Swift
language constraint, not an oversight, and it shapes the whole plan.

`InMemoryNativeControlBackend` ([InMemoryNativeControlBackendState.swift:10](Sources/ChocolateKit/Native/InMemoryNativeControlBackendState.swift:10))
declares exactly **16 methods in its class body**; the other ~173 witness the protocol from
extensions across seven files. A protocol requirement witnessed by an extension method on a
class is statically dispatched and **cannot be overridden by a subclass**.

Those 16 are `setText`, `setFrame`, `setHidden`, `setEnabled`, `runApplication`,
`terminateApplication`, `dispatchAsync`, `installMainMenu`, `createWindow`, `showWindow`,
`closeWindow`, `createView`, `createButton`, `createTextField`, `registerAction`, `measureText`
— *exactly* the 16 the WASM backend overrides today. That was never a scoping choice; it was the
ceiling. The comment above them says so.

**Verify in two minutes before anything else.** *(Done — it failed to compile, as expected.)*
Add to `WASMNativeControlBackend`:

```swift
public override func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
    super.createCheckbox(title: title, frame: frame, parent: parent)
}
```

Expect `error: cannot override a member which is declared in an extension`. If it compiles,
skip step 1.1 and the plan gets shorter.

### The fix, and what it does *not* cost

Two seams, only one needs work:

- **Getters never need overriding.** `sliderValue`, `buttonState`, `popUpButtonSelectedIndex`,
  `comboBoxText`, `tableSelectedRow`, `textSelection`, `datePickerDate` … all read
  `records[handle]`, whose setter is `internal` and the WASM backend is in the same module. The
  backend writes DOM state back into `records` from its listeners; the inherited getter then
  returns the right answer. `WASMNativeControlBackend.setText` already reads `records[handle]?.kind`
  ([:385](Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift:385)) — the pattern is
  established. **This removes ~40 methods from the work list.**
- **Writers** (`create*`, `set*`, `register*`, `invalidate*`) must reach the DOM, so they must be
  overridable, so they must be in the class body.

**Fix: move ~60 writer declarations bodily into the class body.** Not a rename, not a wrapper —
relocate the declaration with its body verbatim from the extension file into
`InMemoryNativeControlBackendState.swift` under the existing `// MARK: - Overridable core seam`,
with topic sub-MARKs. Public API unchanged, bodies unchanged, call sites unchanged; the only
semantic difference is static → vtable dispatch *inside the module*. `Win32NativeControlBackend`
and `GTKNativeControlBackend` conform directly and are untouched. Git shows it as a move, which
makes review cheap.

Do it in **one commit**, gated on the contract suite plus a Linux and Windows build, so no later
phase ever has to touch shared files again. If the file size becomes objectionable, the fallback
is the forwarder variant (`public func createCheckbox(...) { recordCreateCheckbox(...) }` with
the body left in its topic file) — same effect, more names.

**The same trap one level up, found while executing this.** A requirement satisfied by a
*protocol extension default* is also not an overridable class member. A subclass that redeclares
it without `override` compiles — and is then silently ignored, because the conformance witness
still resolves to the default. `wantsDebugClassNames` and `setDebugClassName` hit this and had to
be declared in the recorder's class body too. Any future requirement a backend must override
belongs there from the start.

**Move list:** the 17 remaining `create*`; `setBackgroundColor`, `setFont`, `setTextColor`,
`setTextAlignment`, `setToolTip`, `setViewFlipped`; `setPopUpButtonItems`,
`setPopUpButtonSelectedIndex`, `setButtonState`, `setSliderValue`, `setProgressIndicatorValue`,
`setStepperValue`, `setTabViewSelectedIndex`, `setImagePath`; `setScrollViewContentSize`,
`setScrollViewContentOffset`; `setTableRows`, `setTableCellText`; `registerDrawAction`,
`invalidateControl`, `invalidateControlTree`, `redrawControlImmediately`; `destroyControl`,
`focusControl`; `scheduleNativeTimer`, `cancelNativeTimer`; `primaryScreenFrame`; `runAlert`;
`registerTextChangeAction` and the twelve `registerMouse*` / `registerKey*` /
`registerScrollWheel*` / `registerFocusChange*` methods.

---

## The placeholder mechanism

### Where it lives

New files, all `#if canImport(JavaScriptKit)`:

- `Sources/ChocolateKit/Native/WASM/WASMPlaceholders.swift` — the placeholder builder and caption table
- `Sources/ChocolateKit/Native/WASM/WASMNativeControlBackendControls.swift` — the `create*` overrides

Note: **overrides must live in the class body**, so the override *declarations* stay in
`WASMNativeControlBackend.swift` as one-liners delegating to `internal` helpers in the files
above. Same constraint that produced this section — do not discover it twice.

### Exact class names — one additive framework hook

The backend only sees coarse `kind` strings; `NSSearchField` is indistinguishable from
`NSTextField`, and framework-drawn controls never call a `create*` method at all. Fix with one
line of plumbing rather than a lookup table:

1. Add to the protocol in [NativeControlBackend.swift](Sources/ChocolateKit/Native/NativeControlBackend.swift),
   with a **defaulted no-op** in the existing `extension NativeControlBackend` block (~line 305):
   `func setDebugClassName(_ name: String, for handle: NativeHandle)`, plus
   `var wantsDebugClassNames: Bool { false }`.
2. Call it from the one funnel every realized view passes through —
   [NSViewSupport.swift:8](Sources/ChocolateKit/Views/NSViewSupport.swift:8), right after
   `nativeHandle = handle`:
   ```swift
   if backend.wantsDebugClassNames {
       backend.setDebugClassName(String(describing: type(of: self)), for: handle)
   }
   ```

Zero cost and zero behaviour change on Win32, GTK and InMemory (the guard is `false`); exact
names on WASM, including `NSSegmentedControl`, `NSColorWell`, `NSTokenField`, `DemoGradientsView`,
`DemoCoreGraphicsView`.

**Ordering hazard:** `createNativePeer` runs *before* `setDebugClassName`, so the placeholder is
built from a fallback `kind → name` table and its caption is **rewritten** when the real name
arrives. Keep `placeholderCaptions: [NativeHandle: Element]`, mirroring the existing
`windowTitleLabels` table.

### What a placeholder is

A positioned `div` filed in `elements[handle]` exactly like a real control, so the existing
`setFrame` / `setHidden` / `setEnabled` overrides keep working unchanged, and **children still
append into it** — composites (`NSMatrix`, `NSForm`, `NSSplitView`) stay visible inside their own
placeholder.

- `box-sizing: border-box; border: 1px dashed #b06a2c`
- hazard stripes: `repeating-linear-gradient(45deg, rgba(255,176,108,.16) 0 6px, transparent 6px 12px)`
  — reads as "unfinished" at any size without hiding a child
- **no `overflow: hidden`** on the box
- caption child, self-clipping so a 16 px checkbox still looks checkbox-sized:
  `position:absolute; left:2px; top:0; font:10px/1.2 ui-monospace,monospace; color:#8a4b12;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:100%; pointer-events:none`
- `title` attribute carries the full `"NSSlider — under construction (WASM backend)"`
- `data-cx-placeholder="1" data-cx-kind="slider" data-cx-class="NSSlider"` — **this is the
  progress meter** (see Verification)
- `setText` on a placeholder handle routes to the caption (one extra early-return next to the
  existing `windowTitleLabels` check at
  [:380](Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift:380))

### What must NOT be placeholdered

| Method | Why |
|---|---|
| `createView` | The universal container — pages, content view, split panes, toolbar host, every drawn control, every custom demo view. Striping it makes the whole UI unreadable. |
| `createWindow` | Already renders real chrome; a placeholder double-frames and breaks the `windowContent` routing. |
| `createScrollView` | Hosts the document view; implement for real in Phase 4 (~15 lines: `overflow:auto` + inner document div). |
| `createButton`, `createTextField` | Already real. |
| every `set*` / `register*` | Not creations. |
| `createBox` | Placeholder **decoration only** — border + caption, children still hosted. |

### Framework-drawn controls — the detector

`NSSegmentedControl`, `NSColorWell`, `NSTokenField`, the drawn `NSTableView`, `NSToolbarView` and
the demo's own `draw(_:)` views never call a `create*` method: they call `createView` +
`registerDrawAction`. But `registerDrawAction` is registered for *every* view
([NSViewSupport.swift:55](Sources/ChocolateKit/Views/NSViewSupport.swift:55)), so its presence
proves nothing.

Use the `RecordingDrawingContext` that already exists at
[InMemoryNativeControlBackend.swift:2](Sources/ChocolateKit/Native/InMemoryNativeControlBackend.swift:2),
inside a **paint scheduler**:

- a `Set<NativeHandle>` of dirty handles, drained on `requestAnimationFrame`
- `invalidateControl` / `invalidateControlTree` / `redrawControlImmediately` mark dirty;
  `runApplication` marks the tree dirty once after mounting so the first frame happens unprompted
- draining a handle runs its draw action into a `RecordingDrawingContext` and counts commands:
  **zero → plain container, leave alone; non-zero → this view genuinely draws**, so stamp border
  + caption once

Precise, needs no per-class list, and — the payoff — **it is the exact call shape the real
renderer needs**. Phase 5 swaps `RecordingDrawingContext` for `WASMCanvasDrawingContext` inside
the same drain loop. No churn at the swap. The contract suite already exercises `draw(_:)` against
a recording context, so this path is proven.

### Progressive replacement

A shared `finishControl(handle:element:frame:parent:)` does the common plumbing (absolute
positioning, `elements[handle] = element`, parent append via the existing `register`
[:484](Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift:484), caption hook). Both
placeholders and real controls call it. Implementing a control is then: change one method body
from `makePlaceholder(...)` to real DOM. One method, one commit, one visible screenshot diff.

---

## Phases

| # | What lands | Pages that light up | Size |
|---|---|---|---|
| **0** | Build + render + resources + navigation | All 11 show labels and buttons — 124 `NSTextField` + 51 `NSButton` is the bulk of visible content | ~1 day |
| **1** | Seam move, placeholders, `setDebugClassName`, paint scheduler | **All 11 fully populated**, every control labelled with its real class — the "testable from day one" milestone | ~1–2 days |
| **2** | View chrome + the page switcher | All 11 read correctly; **in-app page switching**; the 1 s timer label ticks | ~200 lines |
| **3** | Form controls, one HTML native each | Controls, Values, New in 3.x, Nib | ~250 lines |
| **4** | Scroll views, clip views, image views | Tables/Media, Scroll Stress, Drawing artwork | ~120 lines |
| **5** | `NativeDrawingContext` over Canvas 2D | **Drawing, CoreGraphics (13), Bezels (8.3)**, plus every drawn control everywhere | ~300 lines + SwiftDOM S2 |
| **6** | **Window resize grips + drag-to-move, and a dock to minimize to** | **Auto Layout (9.x)** and every autoresizing path — none of which can be *seen* until the window can change size | ~200 lines |
| **7** | Real `<table>` for `NSTableView` | Tables/Media, Lists (5.x) | ~200 lines |
| **8** | Mouse, key, focus, text-change plumbing | Interactive rather than merely rendered | ~250 lines |
| **9** | `runAlert`, toolbar chrome | Controls, New in 3.x | ~100 lines |

### Phase 0 — compile, render, navigate

- **Package.swift**: add `.target(name: "WASMChocolate", condition: .when(platforms: [.wasi]))`
  to the `WinChocolateDemo` target, matching `CounterDemo`. Leave the `CHOCOLATE_WASM` gate on
  the SwiftDOM/JavaScriptKit dependencies exactly as it is — `.when(platforms:)` gates *use*, not
  *resolution*; naming SwiftDOM unconditionally breaks Linux and Windows outright.
- **13 demo import switches** get the WASI arm. Two existing shapes, both extended in place:
  `#if os(Linux)` form (main.swift, DemoConveniences, DemoNibConveniences, DemoTextConveniences)
  gains `#elseif os(WASI) / import WASMChocolate`; `#if canImport(LinChocolate)` form (the other
  nine) gains `#elseif canImport(WASMChocolate)`. Nothing else in the demo is touched — not for a
  workaround, not for a "tiny" fix. If the demo needs a change, the bug is in ChocolateKit.
- **Web root**: create `Demo/WinChocolateDemo/` (separate from the source dir `Demo/DemoApplication`,
  so SwiftPM raises no unhandled-files warning) with `index.html`. `build-wasm.sh` already builds
  `Demo/$TARGET/WebBuild` and serves `Demo/$TARGET`, so `./build-wasm.sh WinChocolateDemo` works
  with no script change.
- **Resources into the WASI filesystem.** PackageToJS wires
  `new PreopenDirectory("/", new Map())` — an empty in-memory root you populate. `index.html`
  mirrors `defaultBrowserSetup`, `fetch()`es each resource and builds `File(new Uint8Array(bytes))`
  entries; `Bundle.main.path` and `NSImage(contentsOfFile:)` then work verbatim. Mount the small
  set first (four toolbar PNGs, `DemoNibPanel.xib`, `WinChocolatePngDemo.png`,
  `WinChocolateArtworkDemo.bmp` — ~240 KB total); defer the 4.7 MB BMPs to Phase 4.
  Mount at **three aliases** so every fallback in
  [demoResourcePath](Demo/DemoApplication/DemoTableHelpers.swift:91) resolves: `/Resources/…`,
  `/Demo/DemoApplication/Resources/…`, and — because a backslash is an ordinary filename character
  on WASI — a root-level file *literally named* `Demo\DemoApplication\Resources\<name>.<type>`,
  which makes the demo's Windows-shaped literal fallback resolve as written.
  First run one experiment: `print(Bundle.main.bundlePath)` lands in the console via
  `ConsoleStdout.lineBuffered`; mount to match.
- **`?page=N` navigation, free.** `browser.js` passes `args` straight to `CommandLine.arguments`,
  and [main.swift:2506](Demo/DemoApplication/main.swift:2506) already reads `--page N` / `--stress`.
  So `index.html` does:
  ```js
  const page = new URLSearchParams(location.search).get("page");
  await init({ args: page ? ["--page", page] : [] });
  ```
  `http://localhost:8080/?page=7` opens Auto Layout directly — all 11 pages reachable with zero
  demo changes and zero backend work, before the toolbar renders at all. This is the Phase 0/1
  verification loop.
- **`primaryScreenFrame()` from `innerWidth`/`innerHeight`**, and change the desktop element from
  `overflow: hidden` to `overflow: auto`
  ([:476](Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift:476)). The demo's window
  is 1120×760 at origin (100,100) and the inherited test screen is 1024×768 — without this, part
  of the demo is simply unreachable.
- **`JavaScriptEventLoop.installGlobalExecutor()`** in `WASMNativeControlBackend.init()`. It is
  declared as a dependency and called nowhere; GTK does the analogous thing at
  [GTKNativeControlBackendPart01.swift:96](Sources/ChocolateKit/Native/GTK/GTKNativeControlBackendPart01.swift:96).
  Cheap insurance.
- **`--release` flag in `build-wasm.sh`** (`-c release` on both the `swift build` and the
  `swift package … js` invocation). CounterDemo's debug wasm is 76 MB; the catalog will be larger,
  and page-load time is the dominant per-iteration cost across eight phases. Highest-leverage
  twenty minutes in the plan.
- **Compile-error burn-down.** Expect **far less than the 873-error CounterDemo baseline —
  plausibly under 50.** ChocolateKit already compiles for WASI and already uses `Bundle.main`,
  `FileManager.default` ([NSNib.swift:30](Sources/ChocolateKit/Nib/NSNib.swift:30)) and
  `ProcessInfo`; and the demo has no platform conditionals beyond the 13 imports. Attack order:
  *(a)* Foundation shape gaps → extend
  [WASIFoundationShims.swift](Sources/ChocolateKit/Runtime/WASIFoundationShims.swift), whose
  unqualified-lookup shadowing needs no call-site changes;
  *(b)* runtime-only failures (`Data.write(to:)` in DemoTableHelpers, `NSDocument` save) already
  sit inside `try?` and degrade on their own — no action.
  Budget half a day. A large count will have one systemic cause, not 800 unrelated ones.

**Exit:** `./build-wasm.sh WinChocolateDemo` produces a served page; all 11 pages reachable by
`?page=N`; labels and buttons render; no console errors.

### Phase 1 — the seam move and the placeholder sweep

The seam move (one commit, gated), then `setDebugClassName`, the placeholder builder, the
`create*` override sweep, and the paint scheduler with the `RecordingDrawingContext` detector.

Also retire the one existing `// SPIKE:` marker: **SwiftDOM row S1** — add `measureText` /
`TextMetrics` to SwiftDOM and rewrite
[measureText](Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift:441) against it,
dropping the `rawValue.getContext` reach-around. Per the decision above, SwiftDOM gaps are fixed
upstream as they are hit; each is a two-repo commit pair and the SwiftDOM README checklist is
updated in the same change.

**Exit:** every one of the 11 pages is visually complete — real control or captioned placeholder,
nothing missing, nothing silent. Record the per-page placeholder census (below); it is the
baseline every later phase is measured against.

### Phase 2 — chrome and the page switcher

`setBackgroundColor`, `setFont`, `setTextColor`, `setTextAlignment`, `setToolTip`,
`setViewFlipped`; a real `createPopUpButton` over `<select>`; kind-aware `registerAction`;
`scheduleNativeTimer` → `setInterval` / `cancelNativeTimer`.

Chrome is ~40 lines of the total and transforms all 11 pages at once, and `createPopUpButton` is
the highest-value single control in the app: the page selector
([main.swift:223](Demo/DemoApplication/main.swift:223)) is an `NSPopUpButton` hosted as a custom
view inside `NSToolbarView`, which adds it as a **real subview** — so it gets a genuine
`createPopUpButton` call whether or not toolbar chrome is drawn. In-app page switching does not
wait on Phase 5.

### Phase 6 — window resizing, and somewhere to minimize to

**Moved ahead of tables and input plumbing on purpose.** Auto Layout and autoresizing are not
untested here because they are unfinished — they are untested because nothing on this backend can
change a window's size, and a constraint that never gets a chance to reflow proves nothing. The
catalog says so itself, on the Auto Layout page: *"Resize the window → the green middle box
reflows live."* That sentence is currently an instruction the browser build cannot follow. One
resize grip turns the whole page, and every autoresizing mask in the demo, into something that
can be checked at a glance.

- **Resize grip and drag-to-move.** Pointer capture on the title bar and on a corner grip,
  feeding the `registerWindowMoveAction` and `registerWindowResizeAction` seams the recorder
  already defines. The frame the framework hands back is still law — the backend reports the new
  size and lets the core drive the relayout, rather than resizing the DOM and telling the core
  afterwards.
- **A dock.** `setWindowMinimized(_:for:)` is a real seam and an honest no-op here, so a
  miniaturized window simply disappears with nowhere to go. A browser has no system dock to
  inherit, exactly as it has no window server — so the backend supplies one, for the same reason
  and in the same place: a bar along the bottom of the desktop element, one tile per minimized
  window, carrying the title `setText` already steers, and restoring through `showWindow` on
  click.

**Exit — met.** Dragging the grip resizes the window (clamped to the demo's 900×600
`contentMinSize`) and the Auto Layout page reflows live: the green middle box stretches to fill
the gap as the window widens. The yellow title-bar button minimizes to a dock tile carrying the
window title, and clicking the tile restores the window and removes the tile.

**Two bugs this phase exposed, both of which had been invisible until something could resize:**

1. **A canvas-painted view kept a stale canvas after `setFrame`.** The framework relays out and
   pushes new frames down, but never calls `invalidateControl` — on Win32 and GTK a resized child
   repaints itself. So every constrained box reflowed correctly while its artwork stayed exactly
   where it was, which looks precisely like a layout engine that did not run. `setFrame` now
   marks a drawn view dirty — but only when the *size* actually changed, because marking
   unconditionally deadlocks the page: a view's `draw(_:)` lays out its subviews, each `setFrame`
   re-marks, and the next frame repaints and re-marks forever.
2. **One missed animation frame latched painting off permanently.** Every view realizes before
   `run()` is reached, so the first `requestAnimationFrame` was requested while wasm `main` was
   still on the stack and never fired. `isPaintScheduled` stayed `true`, every later mark was
   suppressed as "already scheduled", and nothing ever painted again — 43 canvases became 0 from
   a single dropped frame. `runApplication()` now flushes the queue synchronously after mounting,
   which both clears the latch and paints the tree the demo built during startup.

### Phases 3–9

3. Form controls, one HTML native each: `createCheckbox`/`createRadioButton` (`<input>`),
   `createSecureTextField` (`type=password`), `createTextView` (`<textarea>`), `createComboBox`
   (`<input list>`), `createSlider` (`type=range`), `createProgressIndicator` (`<progress>`),
   `createStepper`, `createDatePicker`, `createBox` (`<fieldset>`), `createTabView`.
4. `createScrollView` (`overflow:auto` + document div), `NSClipView`, `createImageView` (`<img>`
   from a blob URL over the WASI FS bytes); mount the large artwork here.
5. `WASMCanvasDrawingContext` — the nine `NativeDrawingContext` methods over Canvas 2D, swapped
   into the Phase-1 paint scheduler; DPR handled once, centrally, at the canvas layer.
   **Requires SwiftDOM row S2** (gradients, `drawImage`, clip, `ImageData`, line caps/joins) —
   land it in SwiftDOM first, then consume it. This phase flips every drawn control at once.
6. Window resize grips, drag-to-move, and the dock — see above.
7. `createTableView` → real `<table>`; collection and outline views ride the drawn-table path.
8. Mouse down/up/move/drag, key down/up, focus ↔ first responder via `tabindex`,
   `registerTextChangeAction`, `registerKeyEquivalentHandler`.
9. `runAlert` over the `window.confirm` family; toolbar chrome.

---

## Explicitly out of scope — these stay placeholders

- **`NSPrintOperation`** — `window.print()` prints the page, not a view.
- **`NSSavePanel` / `NSOpenPanel` / `NSColorPanel` / `NSFontPanel`** — the synchronous-return
  contract cannot be honoured in a browser (W-H2); `<input type=file>` and the colour picker are
  async-only. Needs JSPI, not effort. Degrade visibly, log a warning.
- **`NSDocument` / `NSDocumentController` file round-trips** — windows open, saving no-ops.
- **Drag and drop** — `DataTransfer` file access is incomplete upstream in SwiftDOM.
- **`NSTextFinder` find bar, `NSPasteboard` beyond text, multi-screen `screenDescriptions`,
  cursors beyond CSS `cursor:`, an ARIA pass** — real DOM controls give baseline a11y free.
- **`NSBrowser`** — a substantial multi-column control appearing once, next to things that will
  already work.
- **`NSVisualEffectView` materials** — a plain tinted div; do not chase `backdrop-filter`.
- **Window drag-to-move and resize grips** — not on the path to "the whole demo renders".
- **`Demo/DemoApplication/*.swift` beyond the 13 import switches.** The frozen demo is the point.

---

## Verification

### Every commit — the mergeability gate

```bash
swift build && ./build-wasm.sh WinChocolateDemo --build
```

```bash
./run-linux.sh --tests
```

Windows (`buildandrun.bat`) on the VM for any commit touching `Sources/ChocolateKit/Native/` or
`Package.swift`. The `Package.resolved` backup/restore trap in `build-wasm.sh` handles the
two-dependency-graph problem — do not defeat it.

### Per phase — look at it

```bash
./build-wasm.sh WinChocolateDemo
```

Then, via the in-app browser MCP: `preview_start` at `http://localhost:8080/?page=0`, screenshot
each of `?page=0` … `?page=10`, and `read_console_messages { onlyErrors: true }` — Swift `print()`
and backend warnings land there through `ConsoleStdout`.

### Per phase — the number

```js
Object.entries([...document.querySelectorAll('[data-cx-placeholder]')]
  .reduce((m, e) => (m[e.dataset.cxClass] = (m[e.dataset.cxClass] || 0) + 1, m), {}))
  .sort((a, b) => b[1] - a[1])
```

Per page this prints exactly which classes remain unimplemented and how many of each. Take the
census across all 11 pages at the end of Phase 1; every later phase is measured as a drop in that
number. A better gate than "does the screenshot look right", and it is the honest public number
this project's plans keep asking for.

### Docs kept current in the same change

`Docs/WASMChocolatePlan.md` dashboard bars; `WASM_PARITY.md` (row W0.2, still missing) created in
Phase 1 and given a row per placeholder class; the SwiftDOM gap table in
`Docs/RADICALLY_DIFFERENT_UI_SPIKE.md` updated as S1 and S2 land.

---

## Critical files

| Path | Role |
|---|---|
| [InMemoryNativeControlBackendState.swift](Sources/ChocolateKit/Native/InMemoryNativeControlBackendState.swift) | The class body the seam move grows — Phase 1 lives or dies here |
| [WASMNativeControlBackend.swift](Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift) | The 493-line backend; override declarations and the paint scheduler attach here |
| [NSViewSupport.swift:8](Sources/ChocolateKit/Views/NSViewSupport.swift:8) | One-line `setDebugClassName` insertion point that makes every caption exact |
| [NativeControlBackend.swift](Sources/ChocolateKit/Native/NativeControlBackend.swift) | Protocol + defaulted no-op for the new hook |
| [Package.swift](Package.swift) | One `.when(platforms: [.wasi])` line on `WinChocolateDemo` |
| [build-wasm.sh](build-wasm.sh) | Gains `--release`; already parameterized by target |
| `Demo/CounterDemo/WebBuild/platforms/browser.js` | The `PreopenDirectory` and `args` wiring the new `index.html` reproduces and extends |

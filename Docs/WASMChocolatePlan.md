# WASMChocolate — Browser Backend Plan

*This is a plan document only; no code here. The first slice of it is executed by
[RADICALLY_DIFFERENT_UI_SPIKE.md](RADICALLY_DIFFERENT_UI_SPIKE.md).*

**Working name:** WASMChocolate — the browser member of the Chocolate family.
**Sibling plan:** [TermChocolatePlan.md](TermChocolatePlan.md) (the terminal member). The two
plans deliberately rhyme: each adds one `NativeControlBackend` and one façade, and nothing else.

---

## Context

Bobby wants Chocolate apps to run in a browser, compiled to WebAssembly, served from a URL.
The premise is the same one that justifies the terminal backend: WinChocolate is not a
monolith — it is `ChocolateKit` (the shared AppKit surface) plus swappable backends behind
one protocol. If the same 100-line demo renders on Win32, GTK, a character grid **and** the
DOM, the abstraction is proven four ways. The unlock is real: a full AppKit-shaped app that
deploys as static files to any web host, with no install step at all.

Three facts discovered while planning shape this work:

1. **SwiftDOM already exists and is the right size.** `/Users/bobby/AIResearch/WASM/Code/SwiftDOM`
   — ~6,800 lines, 30 files, a deliberately thin, imperative, DOM-shaped wrapper over
   JavaScriptKit (pinned 0.52.0) and nothing else. Not a virtual DOM, not a widget toolkit —
   which is exactly what a `NativeControlBackend` wants: `Element` factories,
   `addEventListener` with token-based lifetime, inline styles, canvas, timers,
   `ResizeObserver`. Its own README carries a per-surface completion checklist.
2. **The backend seam is measured and small.** `NativeControlBackend`
   ([Sources/ChocolateKit/Native/NativeControlBackend.swift](../Sources/ChocolateKit/Native/NativeControlBackend.swift))
   is **189 requirements** today, 17 with protocol-extension defaults. A compiling stub needs
   ~172 members; a click-counter needs ~25. `InMemoryNativeControlBackend` (9 files,
   2,447 lines) implements the whole protocol and is the template.
3. **The build toolchain is already installed and scripted.** No carton. The official Swift
   SDK (`swift-6.3.1-RELEASE_wasm`, present on this machine) plus JavaScriptKit's
   PackageToJS plugin plus any static file server. Working scripts exist at
   `/Users/bobby/AIResearch/WASM/Code/SwiftDOMDemo/build.sh` and friends, and a zero-npm
   Chrome DevTools Protocol test harness exists at
   `/Users/bobby/AIResearch/WASM/Code/SwiftDOM/browser-test.sh`.

Therefore: **`WASMNativeControlBackend` inside ChocolateKit, driven by SwiftDOM, fronted by
a `WASMChocolate` façade.** One new directory plus a one-line façade target. The hope stated
up front — that SwiftDOM alone is enough of the WASM world — largely holds; where it does
not (text measurement, `matchMedia`, async clipboard), the gap is fixed **in SwiftDOM**
(Part S), not worked around in ChocolateKit.

### Decisions already taken

| Question | Answer |
|---|---|
| Where the backend attaches | **A backend directory + façade, same as GTK/TUI.** `Sources/ChocolateKit/Native/WASM/` + `Sources/WASMChocolate/`. Never an `#if` sweep through control files. |
| Substrate | **SwiftDOM only.** JavaScriptKit arrives transitively; the one extra product is `JavaScriptEventLoop` (needed so `Task`/`@MainActor` run on the browser loop). |
| Build pipeline | **Official Swift WASM SDK + PackageToJS plugin.** No carton, no hand-written JS glue. An executable target is always in the build loop (library-only wasm builds hit a JavaScriptKit C-shim issue — `/Users/bobby/AIResearch/WASM/Code/Freebird/PLAN.md:74`). |
| Backend selection | **Compile-time.** The wasm binary can only ever be the WASM backend: a new `#elseif os(WASI)` arm in `NSApplication.init()`, placed **before** the `#else` (the `#else` silently selects the headless test backend — that bug already shipped once on Linux). The `CHOCOLATE_BACKEND` runtime env var introduced by the spike arbitrates TUI-vs-GUI on desktop OSes; **absence always keeps today's GUI defaults**. |
| Fidelity | **Real DOM controls where HTML has them** (`<button>`, `<input>`, `<select>`), synthesized chrome where it does not (windows, menu bar), canvas for `drawRect`-style drawing. A browser *look* driven by the same classic style the other backends draw is the goal; substituted behaviour is not allowed. |
| Windows | **Synthesized.** Each `NSWindow` is an absolutely-positioned div with framework-drawn title bar chrome inside one full-page "desktop" element. This is the same job Win32/GTK do with HWNDs/GtkWindows — the browser just has no window server to lean on. |
| Proof apps | **Easiest → hardest: CounterDemo → RunLoopDemo → WinChocolateDemo (the 11-page catalog) → a real app.** Later ones may be rev 2 or rev 3, but what doesn't work must still run, just missing features. |

---

## Ground rules

These inherit TermChocolatePlan's seven ground rules verbatim (AppKit can never break; the
user never writes a conditional; implement the Apple API, not something similar; degrade
visibly, never silently; everything still runs; upstream fixes go upstream; the dashboard
ships current). Three additions specific to this backend:

1. **WinChocolate and LinChocolate keep working in every change.** All WASM code is additive:
   new targets, new directories guarded `#if canImport(JavaScriptKit)`, and dependencies
   attached only under `.when(platforms: [.wasi])` — the same trick that keeps CGTK declared
   but never resolved on Windows ([Package.swift](../Package.swift) lines 45–51, 108–109).
   `buildandrun.bat` and `run-wsl.bat` are part of every slice's exit criteria.
2. **An executable is always in the wasm build loop.** Never verify with a library-only
   `swift build --swift-sdk …_wasm`; it false-fails on the JavaScriptKit C-shim. The demo
   executable + PackageToJS is the only trusted green.
3. **Listener lifetime is token-based.** SwiftDOM's `.on(...)` chains nicely but retains the
   closure forever in a global store. The backend uses `addEventListener` (which returns a
   removable `EventListener` token) and keeps its own `[NativeHandle: [EventListener]]`
   table so `destroyControl` actually releases.

---

## Where we actually are (measured 2026-08-16)

- **`NativeControlBackend` is 189 requirements**, 17 defaulted; grouped roughly: 59 control
  property setters/getters, 28 windows/screens/modals/dialogs, 23 event registration, 19
  text/font, 15 drawing/appearance, 15 control creation, 14 lifecycle/run-loop/timers/clipboard,
  13 tables, 3 menus. `NativeHandle` is a `Sendable` wrapper over `UInt` — a
  `[NativeHandle: Element]` table needs no bridging.
- **Backend selection is one `#if` in a convenience init**
  ([NSApplication.swift:107-121](../Sources/ChocolateKit/Application/NSApplication.swift)), with
  `public init(nativeBackend:)` at `:124` for explicit injection and `nativeBackend` a settable
  `public var` (`:48`) that the contract tests already swap.
- **The run-loop seam has two styles and WASM must use the second — then bend it.**
  Pump style (Win32: `Win32RunLoopPump`, two methods) is off the table: on real Foundation,
  `RunLoop.installPlatformPump` is a `preconditionFailure`
  ([Runtime/FoundationBridge.swift:163-171](../Sources/ChocolateKit/Runtime/FoundationBridge.swift)).
  Own-loop style (GTK: install a main-actor executor, then `g_main_loop_run`) is the model —
  except a browser backend **cannot block at all**: `runApplication()` must mount, install
  `JavaScriptEventLoop.installGlobalExecutor()`, and return, leaving the browser in charge.
  The wasm instance stays alive because JS holds it and the backend's `JSClosure`s hold Swift.
- **Menus are a 3-method seam** (`installMainMenu`, `registerKeyEquivalentHandler`,
  `runContextMenu`) and activation is core-side: the backend renders items and calls
  `item.performAction()`; `"terminate:"` resolves through the responder chain untouched. The
  GTK backend's pending-menu replay
  ([GTKNativeControlBackendPart20.swift:238-267](../Sources/ChocolateKit/Native/GTK/GTKNativeControlBackendPart20.swift))
  — main menu set before any window exists — recurs verbatim in a browser if the bar is
  attached per-window rather than to the desktop element.
- **SwiftDOM covers the seam well**: creation/reparent/remove, inline styles +
  `getBoundingClientRect`, the full typed `Event` surface (mouse/key/focus/clipboard-events),
  `Canvas` 2D (first pass), `setTimeout`/`setInterval`/`requestAnimationFrame` with
  cancellable tokens (maps to `scheduleNativeTimer`/`cancelNativeTimer`), `ResizeObserver`.
- **SwiftDOM's known gaps, named now:** no `measureText` on canvas, no `matchMedia` (blocks
  `systemPrefersDarkAppearance`), no `window.screen`, no async `navigator.clipboard`
  (events only), no `window.print`, canvas lacks gradients/images/clipping, custom-element
  registration unimplemented. All Part S rows.
- **Precedent exists for the layering discipline.** Freebird
  (`/Users/bobby/AIResearch/WASM/Code/Freebird/ARCHITECTURE.md`) splits Core (no DOM) from
  DOM (SwiftDOM + JavaScriptEventLoop) precisely so non-browser builds never compile a
  browser runtime; its `FreebirdDOM` sources (DOMRenderer, BrowserEventBridge, ElementRef)
  are working reference for mounting and event routing over SwiftDOM.
- **Binary size is real:** SwiftDOMDemo's debug build is a 12 MB `.wasm`. ChocolateKit is
  52,558 lines. Release + optimization is a phase (L1), not a footnote.

---

## Dashboard

Executed so far by [RADICALLY_DIFFERENT_UI_SPIKE.md](RADICALLY_DIFFERENT_UI_SPIKE.md)
(2026-08-16): the stub gate is passed with a measured **873 → 0**, and the counter runs in a
browser. The bars below are current, and deliberately conservative — a phase is only "done"
when its whole scope is, not when the spike touched it.

```
Overall Progress                ███░░░░░░░░░░░░░░░░░░░░░░░   13%  ( 3 / 23 phases)

Part W · WASM Backend           ██████░░░░░░░░░░░░░░░░░░░░   25%  (2.5/ 10)  🔄
Part S · SwiftDOM Expansion     ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 /  6)  ⏳
Part P · Proof Apps             ██████░░░░░░░░░░░░░░░░░░░░   25%  ( 1 /  4)  🔄
Part L · Web Last Mile          ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 /  3)  ⏳

── Part W · WASM Backend (the fifth NativeControlBackend) ──────────────
Phase W0  · Honest Baseline           ████████████░░░░░░░░░░░░░░   50%  🔄  (numbers taken; parity file pending)
Phase W1  · Backend Decision (gate)   ██████████████████████████  100%  ✅  873 → 0, adapter confirmed
Phase W2  · Browser App Harness       ██████████████████████████  100%  ✅  build-wasm.sh + index.html + served page
Phase W3  · Core Seam & DOM Mapper    ████████████░░░░░░░░░░░░░░   50%  🔄  handles/frames/text done; S1 open
Phase W4  · Input Core                ██████░░░░░░░░░░░░░░░░░░░░   25%  🔄  click path done; keys/focus pending
Phase W5  · Windows & Menus           ████████░░░░░░░░░░░░░░░░░░   30%  🔄  chrome + menu bar + Quit; no drag/z-order
Phase W6  · Controls                  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase W7  · Drawing & Canvas          ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase W8  · Tables & Scrolling        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase W9  · Subsystems                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
── Part S · SwiftDOM Expansion (upstream, runs alongside W) ────────────
Phase S1  · Canvas measureText        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase S2  · Canvas Roadmap Items      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase S3  · matchMedia & Color Scheme ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase S4  · window.screen             ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase S5  · Async Clipboard           ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase S6  · Fonts, Print & Misc       ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
── Part P · Proof Apps (easiest → hardest; rev 2 and 3 allowed) ────────
Phase P1  · CounterDemo               ██████████████████████████  100%  ✅  runs in a browser
Phase P2  · RunLoopDemo               ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase P3  · WinChocolateDemo Catalog  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase P4  · A Real App                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
── Part L · Web Last Mile ──────────────────────────────────────────────
Phase L1  · Release Size & Startup    ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase L2  · Browser Matrix            ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase L3  · Distribution              ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; 🚫 Blocked &nbsp;|&nbsp; ⏸ Postponed

> **Ordering.** W0 → W1 is a gate: nothing else starts until the stub compiles for wasm and
> the error count is published. W2 before W3, so there is a served page to be wrong. W1–W4
> plus the menu slice of W5 **are** the RADICALLY_DIFFERENT_UI_SPIKE (executed together with
> TermChocolate's T1/T2). Part S rows are pulled forward the moment a W phase needs them —
> S1 lands with W3 (layout calls `measureText` immediately). Part P interleaves: P1 gates W6;
> P2 rides W3 (timers) and will log honest findings about run-loop APIs that cannot exist in
> a browser; P3 and P4 are exposure tests that will push bars backward. That is the plan
> working, not failing.

---

## The architecture, in one diagram

```
   App source (zero #if beyond the sanctioned import switch)
                    │
        ┌───────────┼──────────────────────────┐
   import WinChocolate   import LinChocolate   import WASMChocolate   ← the new 1-line façade
   (Windows GUI)         (Linux GUI)                 │                  @_exported import ChocolateKit
                                                     │
                                          ChocolateKit  (52,558 lines — already written)
                                          NSView/NSWindow/NSButton/NSMenu/NSEvent…
                                                     │
                                     NativeControlBackend  (one protocol, 189 reqs)
                                                     │
      ┌──────────┬──────────┬──────────────┬─────────┴────────────┐
   Win32        GTK      InMemory   TUINativeControlBackend  WASMNativeControlBackend  ← NEW
  (exists)    (exists)   (exists)     (TermChocolatePlan)            │
                                                                 SwiftDOM  (~6,800 lines)
                                                          Element · Event · Canvas · Timers
                                                                     │
                                                              JavaScriptKit 0.52
                                                                     │
                                                          Browser DOM  (the "window server")
```

The new code is one directory — `Sources/ChocolateKit/Native/WASM/` — plus a façade.
Everything above and below it exists.

---

## Difficult issues

### Hard and unavoidable

| # | Issue | Why it is hard |
|---|---|---|
| **W-H1** | **The browser owns the event loop.** `NSApplication.run()` expects to not return; `runApplication()` in a browser must mount and *return*, handing control back to JS. | Everything downstream of "run() returns" must still work: the app object, windows, and all closures must be retained by the backend (JS-held `JSClosure`s keep the wasm instance alive). `JavaScriptEventLoop.installGlobalExecutor()` must be installed before any `Task`. Foundation `RunLoop`/`Timer` never fire on WASI — backend timers (`scheduleNativeTimer` → `setInterval`) do. P2 exists to document exactly which run-loop APIs are honest no-ops here. |
| **W-H2** | **Modal APIs block; a browser cannot.** `runModal`, `runAlert`, `runFileDialog`, `runColorChooser`, `runFontChooser` all return values synchronously. | Partial escape hatches exist: `window.alert`/`confirm`/`prompt` genuinely block and can back `runAlert` honestly; `<input type=file>`/`color` pickers are async-only. Strategy: back what can be backed synchronously, degrade the rest visibly (disabled affordance + logged warning), and revisit with JSPI (wasm stack switching) when toolchain support is real. Same H4 lineage as Win32's nested loops — `Docs/RunLoopDesign.md` is the reference. |
| **W-H3** | **Windows and menus have no DOM primitive.** No window server, no `<menubar>`. | Synthesize: a full-page desktop element; each `NSWindow` an absolutely-positioned div with framework-drawn title bar (close/miniaturize buttons calling the registered close/shouldClose handlers), z-order via CSS, drag-to-move via pointer capture feeding `registerWindowMoveAction`. Menu bar: a bar div + dropdown divs from `NSMenu.items`, clicks calling `item.performAction()`, `keyEquivalent` matched in a document-level keydown listener feeding `registerKeyEquivalentHandler`. GTK's pending-menu replay applies. |
| **W-H4** | **Text measurement.** `measureText(_:font:)` ×2 is needed the moment any layout runs, and DOM text measurement is notoriously indirect. | Canvas 2D `measureText` is the standard answer and SwiftDOM does not wrap it yet (S1). Until S1 lands, the spike may call it through the `rawValue`/`DOM.jsWindow` escape hatch — allowed in spike code only, never in the landed backend. Wrapping variant needs an offscreen measuring div or manual line-breaking over canvas metrics. |
| **W-H5** | **`NativeDrawingContext` over Canvas 2D.** Nine methods: fill/stroke path, text, image (path or RGBA), linear gradient, clip, save/restore. | Canvas 2D can express all nine — but SwiftDOM's canvas wrapper is a first pass with no gradients, no `drawImage`, no clip, no pixel buffers (S2). One `<canvas>` per view with a registered draw action, repainted on `invalidateControl`. DPR (`devicePixelRatio`) scaling must be handled once, centrally. |
| **W-H6** | **Packaging without breaking Win/Lin.** SwiftDOM + JavaScriptKit must never resolve into a Windows or Linux build. | Solved shape exists: declare deps on `ChocolateKit` only under `.when(platforms: [.wasi])` (CGTK precedent), guard backend files `#if canImport(JavaScriptKit)`, façade target depended on only for wasi. Watch: SwiftPM still *fetches* the packages on every platform, and builds JavaScriptKit's BridgeJS macro plugin for consumers — cost documented in Freebird's ARCHITECTURE.md. Also: `WinFoundation` is Windows-only, so WASI gets real (wasi-libc) Foundation — the `installPlatformPump` precondition applies. |
| **W-H7** | **Closure and listener lifetime.** Every registered action crosses the Swift↔JS boundary as a `JSClosure`; dropping one while the DOM still references it is a crash, retaining forever is a leak. | Ground rule 3 above: token table per handle, released in `destroyControl`. `JSClosure` release semantics on wasm (no deinit-based release on some configurations) must be verified once, early, in W1. |
| **W-H8** | **Coordinates.** AppKit screen coords are bottom-left-origin; DOM is top-left. ChocolateKit already runs flipped content views on Win32/GTK. | The DOM *is* a flipped surface, so view-local mapping is direct; window `frame` ↔ desktop-element positioning needs one, and only one, y-inversion at the window layer — same discipline the frame-is-law lesson taught on GTK: the backend honors the frame it is given, exactly. Units are the easy half here: CSS pixels *are* the coordinate system, so the "coordinates stay in pixels" rule TermChocolate has to work for comes free — with `devicePixelRatio` handled once, centrally, at the canvas layer only. |

### Real but postponable

| # | Issue | Postpone by |
|---|---|---|
| **WP1** | Tables (`NSTableView`, 13 reqs) | HTML `<table>` or positioned rows; single-column first, ride the classic renderer's backend boundary |
| **WP2** | Rich text ranges, field editors, selection APIs | `<textarea>`/contenteditable first pass; honest read-only band where selection APIs gap |
| **WP3** | Drag & drop | DOM drag events exist in SwiftDOM; DataTransfer item/file access is flagged incomplete upstream — defer to a Part S row when reached |
| **WP4** | Printing | `window.print` (S6) prints the page; per-view print operations later |
| **WP5** | Cursors, tooltips beyond `title=` | CSS `cursor:`; native `title` tooltip is the honest first pass |
| **WP6** | Toolbars | Framework-drawn like the classic Win32 path; defer to catalog exposure |
| **WP7** | Multiple screens (`screenDescriptions`) | One synthetic screen = viewport; real multi-screen info is not available to web pages |
| **WP8** | Accessibility | Real DOM controls give baseline a11y for free — one reason to prefer them over canvas-drawing everything; ARIA pass deferred |

### Permanently absent

`clipboardChangeCount` (no browser analogue). Synchronous file dialogs. Reading arbitrary
system fonts (`fontFamilyNames` returns the web-safe list + `document.fonts`).
Process-level `terminateApplication` — a page cannot exit; it degrades visibly to a
terminated banner over an inert desktop (self-`window.close` only works for script-opened
windows). Window positioning outside the viewport. True modal nested run loops until/unless
JSPI ships. Each gets a documented no-op and a parity-file row, never a stub that pretends.

---

## Part W — WASM Backend

### Phase W0 — Honest Baseline ⏳

| # | Area | Notes |
|---|---|---|
| W0.1 | This document lands as `Docs/WASMChocolatePlan.md`; README links it | Done in the same change that creates the file |
| W0.2 | `WASM_PARITY.md` created, empty but structured | Copy `CONTROL_PARITY.md` columns; counterpart column is "DOM/SwiftDOM counterpart" |
| W0.3 | Measure and record SwiftDOM's real state | Its README checklist is the claim; verify the rows this plan leans on (events, canvas, timers) |
| W0.4 | `buildcheck-wasm.sh` | Compile-only check of the stub + demo for `--swift-sdk swift-6.3.1-RELEASE_wasm`; header states: *green proves no Win32/GTK type leaked into the wasm path; it does not prove the browser works* |
| W0.5 | Record toolchain pins | `/Users/bobby/.swiftly/bin/swift` 6.3.1, SDK `swift-6.3.1-RELEASE_wasm`, JavaScriptKit 0.52.0, and the `.sourcekit-lsp/config.json` pattern for editor support |

**Exit:** plan, parity file and build check exist; no Swift written.

### Phase W1 — Backend Decision (gate) ⏳

The one phase that can cancel the project. Mirrors TermChocolate T1.

| # | Area | Notes |
|---|---|---|
| W1.1 | **The spike, with a number.** Stub `WASMNativeControlBackend` with every method a loud no-op, wire the façade and the `os(WASI)` selection arm, compile the demo for wasm | Publish the error count, TermChocolate T1.2 style. The `#else`-selects-InMemory trap is why the arm goes *before* the else |
| W1.2 | Inventory the 189 requirements against SwiftDOM | Three buckets: *direct adapt* / *compound from primitives* / *honest no-op*. First fill of `WASM_PARITY.md` |
| W1.3 | Run-loop design note | Non-blocking `runApplication()`; `JavaScriptEventLoop` install point; who retains the app object; verify `JSClosure` release semantics on this toolchain — on paper, then a 20-line proof |
| W1.4 | Packaging proof | `Package.swift` diff with SwiftDOM path dep + `.when(platforms: [.wasi])` conditions; then **prove Win/Lin unaffected**: `buildandrun.bat`, `run-wsl.bat --build`, and a macOS `swift build` all green with the diff applied |
| W1.5 | Coordinate & DPR contract | Write the one-y-inversion rule (W-H8) and the devicePixelRatio rule into the parity doc before any painting exists |

**Exit:** a stub backend that compiles for wasm with a measured error count, and a written
adapter-vs-rewrite verdict. If the count says rewrite, the plan stops here and says so.

### Phase W2 — Browser App Harness ⏳

Something served, to be wrong.

| # | Area | Notes |
|---|---|---|
| W2.1 | `Demo/CounterDemo` — the shared proof app | Modeled on `Demo/RunLoopDemo/main.swift`: sanctioned import switch + window + labels + buttons + File→Quit menu. Also runs on Win32/GTK unchanged — it is the spike's shared artifact |
| W2.2 | `build-wasm.sh` + `Demo/CounterDemo/index.html` | Cloned from `SwiftDOMDemo/build.sh`: build with the wasm SDK, PackageToJS into `WebBuild/`, serve with `python3 -m http.server` |
| W2.3 | Lifecycle through `NSApplication.run()` | Delegate callbacks fire, backend mounts the desktop element into `document.body`, run() returns, page stays interactive |
| W2.4 | Viewport = screen | `primaryScreenFrame()` from `innerWidth/innerHeight`; `ResizeObserver`/resize event feeds `registerWindowResizeAction` for full-viewport windows later |

**Exit:** a served page shows *something* rendered by the backend from CounterDemo's source.

### Phase W3 — Core Seam & DOM Mapper ⏳

| # | Area | Notes |
|---|---|---|
| W3.1 | Handle table | `[NativeHandle: Element]` + kind + listener tokens; minting mirrors InMemory's `makeHandle` |
| W3.2 | `createView`/`setFrame`/`setHidden`/reparenting | Absolute positioning inside the parent element; the frame given is the frame set — frame is law |
| W3.3 | `setText`/`setFont`/`setTextColor`/`setBackgroundColor`/`setToolTip`/`setEnabled` | Inline styles + `title` + `disabled` |
| W3.4 | `dispatchAsync` + native timers | queueMicrotask/`setTimeout(0)`; `scheduleNativeTimer`→`setInterval`, `cancelNativeTimer`→token cancel |
| W3.5 | `measureText` ×2 | Via S1 (canvas measureText). Layout is wrong until this lands; that is expected and visible |

**Exit:** the InMemory contract-test patterns run against the WASM backend under wasm
(headless via the CDP harness) for creation/property/geometry behavior.

### Phase W4 — Input Core ⏳

| # | Area | Notes |
|---|---|---|
| W4.1 | `registerAction` | `click` listener → `makeFirstResponder` + `sendAction` path, exactly one backend call deep |
| W4.2 | Mouse down/up/move/drag/enter/exit | Pointer events mapped to `NSEvent`; document-level capture for drags |
| W4.3 | Key down/up + `registerKeyEquivalentHandler` | Document keydown; Cmd/Ctrl normalization; suppress browser defaults only for claimed equivalents |
| W4.4 | Focus | `focus()`/`focusin` ↔ first responder; Tab order via `tabindex` mirroring the responder chain |
| W4.5 | `registerTextChangeAction` | `input` events on fields |

**Exit:** CounterDemo's count increments on click and on keyboard activation in a real browser.

### Phase W5 — Windows & Menus ⏳

| # | Area | Notes |
|---|---|---|
| W5.1 | Window chrome | Title bar, close box → shouldClose/close handler chain; styleMask honored (titled/closable/resizable) |
| W5.2 | Z-order, key window, `orderFront/orderOut` | CSS z-index ladder; click-to-activate |
| W5.3 | Drag-to-move, resize grips | Pointer capture; feeds move/resize registrations |
| W5.4 | `installMainMenu` | Bar + dropdowns from `NSMenu`; separators, disabled, hidden, submenus one level; `performAction()` on click; pending replay if set pre-window |
| W5.5 | Key equivalents & `runContextMenu` | Document keydown matcher; context menu synthesized at point (may return nil first pass, as GTK does) |
| W5.6 | Modal strategy from W-H2 | `runAlert` over `window.confirm` family first; parity rows for the rest |

**Exit:** File→Quit quits (visible terminated state); a second window stacks, activates,
moves, and closes correctly.

### Phase W6 — Controls ⏳

Checkbox/radio (`<input>`), popup (`<select>`), combo (`<input list>`), slider
(`<input type=range>`), progress (`<progress>`), stepper, image view, box, tab view,
scroll view basics — each a parity-file row; framework-drawn bezels reuse the classic
style via W7 where HTML's control look is wrong for the classic appearance.
**Exit:** the catalog's first pages render with real interaction.

### Phase W7 — Drawing & Canvas ⏳

`registerDrawAction`/`invalidateControl` over per-view `<canvas>`; the nine
`NativeDrawingContext` methods over Canvas 2D (needs S2); DPR handling; image pipeline
(RGBA → `ImageData`/blob URL). **Exit:** a framework-drawn bezel control is
pixel-plausible next to its Win32 screenshot.

### Phase W8 — Tables & Scrolling ⏳

`NSScrollView`/`NSTableView` over overflow scroll + row divs or `<table>`; sort headers;
selection. **Exit:** the catalog's table page works.

### Phase W9 — Subsystems ⏳

Pasteboard (S5), appearance/dark (S3 + `setAppearanceDark`), cursors, fonts (S6),
remaining dialogs, honest no-op sweep with parity rows for everything left.
**Exit:** the full protocol is implemented or documented-absent; zero silent stubs.

---

## Part S — SwiftDOM Expansion (upstream)

**SwiftDOM is Bobby's own framework**, so "upstream" here means a change he can make directly —
this is a real work queue, not a wish list filed against a third party. That makes ground rule 6
(*upstream fixes go upstream*) enforceable rather than aspirational: **a gap in SwiftDOM is fixed
in SwiftDOM.** When a W-phase hits a missing DOM surface, the correct move is to raise it as an
S-row and have it added, not to reach around SwiftDOM into raw JavaScriptKit inside ChocolateKit.

Fixes land in `/Users/bobby/AIResearch/WASM/Code/SwiftDOM` with its README checklist
updated — never worked around in ChocolateKit. The one sanctioned exception is spike-grade code,
which may use the `rawValue` / `DOM.jsWindow` escape hatch **only** with a `// SPIKE:` marker
naming the S-row that will replace it; a W-phase cannot land while any `// SPIKE:` marker
remains in its area.

Rows below are the gaps known today. Expect the list to grow — every W phase is also a
discovery pass over SwiftDOM's surface, and finding a missing wrapper is a normal outcome, not
a blocker.

| # | Row | Pulled forward by |
|---|---|---|
| S1 | Canvas `measureText` + `TextMetrics` | W3 |
| S2 | Canvas gradients, `drawImage`, clip, `ImageData`, line caps/joins | W7 |
| S3 | `matchMedia` + `prefers-color-scheme` change events | W9 |
| S4 | `window.screen`, `devicePixelRatio` accessor | W2/W7 |
| S5 | Async clipboard (`navigator.clipboard.readText/writeText`) | W9 |
| S6 | `document.fonts`, `window.print`, misc | W9 |

---

## Part P — Proof Apps

| # | App | Notes |
|---|---|---|
| P1 | **CounterDemo** | The spike exit: unmodified source, zero conditionals beyond the import switch, count increments on click, File→Quit works. Gates W6 |
| P2 | **RunLoopDemo** | Deliberately hostile to W-H1: `Timer.scheduledTimer` and nested `RunLoop.main.run(mode:before:)` cannot work on WASI. Expected result is a *findings ledger*, not green — which APIs no-op, which need backend timers, what the honest degrade looks like |
| P3 | **WinChocolateDemo** (11-page catalog) | The exposure test; every gap becomes a W-row or an S-row. Expect bars to move backward |
| P4 | **A real app** | Chosen when P3 is credible; served from a URL end to end |

Each proof app ends in a findings ledger appended to the spike doc or its successor.

---

## Part L — Web Last Mile

| # | Row | Notes |
|---|---|---|
| L1 | Release size & startup | `-Osize`, wasm-opt, measure against the 12 MB debug baseline; embedded-SDK variant (`swift-6.3.1-RELEASE_wasm-embedded` is installed) evaluated honestly |
| L2 | Browser matrix | Chrome (CDP-tested), Safari, Firefox; mobile Safari is the stretch |
| L3 | Distribution | Static host recipe (any file server + correct `wasm` MIME); the "send someone a URL" demo |

---

## Open questions

1. **SwiftDOM dependency form.** Path dep (`/Users/bobby/AIResearch/WASM/Code/SwiftDOM`) is
   machine-specific — fine for the spike, a gate item before anything merges to `develop`.
   Publish a tag, vendor, or keep path + document? (TUIKit has the identical question.)
2. **One window = one div, or full-viewport single-window mode first?** The spike does one
   fixed-position window div; a `fullScreen`-style single-window mode may be the better
   default for real web apps. Decide at P3.
3. **`@MainActor` posture.** SwiftDOM is not actor-annotated (`nonisolated(unsafe)` stores);
   ChocolateKit's core is main-thread-shaped. Wasm is single-threaded today, which hides the
   question — write the intended rule down in W1 so threads-on-wasm later doesn't break it.
4. **Contract tests on wasm.** The contract-test target is a plain executable — it may run
   under wasm via the CDP harness or Node. Worth a W3-time experiment; not exit criteria.
5. **Does the classic Win32 look carry to the browser, or does WASM debut the modern
   appearance layer?** Default: classic first (it is what the drawing seam draws today);
   the appearance roadmap in README already tracks the modern layer separately.

---

## Manual test checklist

- [ ] `buildandrun.bat` still builds and runs the Win32 demo (unchanged)
- [ ] `run-wsl.bat` still builds and runs the GTK demo (unchanged)
- [ ] macOS `swift build` and the contract tests stay green (unchanged)
- [ ] `./build-wasm.sh` produces `WebBuild/` with no library-only build in the loop
- [ ] Served CounterDemo: window renders with title bar
- [ ] Click increments; keyboard activation increments
- [ ] Menu bar renders; File opens; Quit shows the terminated state
- [ ] Reload restarts cleanly; no console errors from released closures
- [ ] Resize the browser window: desktop element tracks the viewport
- [ ] Second backend untouched: `CHOCOLATE_BACKEND` unset behaves exactly as before on all three OSes

---

## Verification

Every W-phase exit names its own proof. The standing gates, in order: the wasm build check
(`buildcheck-wasm.sh`), the CDP browser harness (pattern:
`/Users/bobby/AIResearch/WASM/Code/SwiftDOM/browser-test.sh`, zero npm), the manual
checklist above, and — always, in the same change — the existing Win32/GTK/macOS builds and
contract tests, because ground rule one of this whole family is that **the working
Chocolates never break**.

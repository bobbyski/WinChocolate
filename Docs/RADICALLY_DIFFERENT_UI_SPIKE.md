# Radically Different UI — Spike

*One source tree, four surfaces. This spike proves the `NativeControlBackend` abstraction is
real by running the same unmodified click counter on Win32, GTK, a character grid, and the
browser DOM.*

**Status: COMPLETE** (2026-08-17). Both halves run the click counter, from one source file.

| Renderer | Result |
|---|---|
| **WASM / browser** | ✅ verified interactively — click, Reset, File→Quit |
| **TUI / character grid** | ✅ verified headlessly *and* on screen, in Turbo |
| **macOS / real AppKit** | ✅ builds and runs — the control group |
| **Linux / GTK** | ✅ builds |
| **Windows / Win32** | ⚠️ **not run** — no Windows machine here. Untouched by construction (see F2), but that is an argument, not a test |

The demo source is **byte-identical** in both repos (`diff` clean): WinChocolate's
`Demo/CounterDemo` and TUIChocolate's `Code/Demo/TUICounterDemo` are the same file, and the
only thing that varies is which framework the compiler was pointed at. That was the whole
claim, and it holds on four of the five renderers with the fifth unverified rather than
suspect.

The terminal half arrived by a different route than this document assumed — see the
superseded blocker below, and the Findings ledger for both halves.

> **The TUI blocker below is superseded — read this first.** That analysis was correct and
> its conclusion was wrong. It asked "how do ChocolateKit and TUIKit build on one platform?"
> and answered "they cannot." The way through was to stop requiring that: a **separate
> package**, [`/Users/bobby/AIResearch/TUIAppKit`](file:///Users/bobby/AIResearch/TUIAppKit),
> reimplements the AppKit surface directly over TUIKit and never involves ChocolateKit at
> all. It builds and runs on macOS today, and the click counter works — window, labels,
> buttons, menu bar, File→Quit, mouse and keyboard.
>
> Nothing in the triangle was false; it was the wrong question. The Docker/toolchain rows
> (B1–B3) are moot for this route, and only return if the terminal backend is ever wanted
> *inside* ChocolateKit on Linux.
>
> **What the separate package bought, beyond unblocking:** the namespace problem — the thing
> flagged as hardest — largely evaporates. TUIAppKit imports neither AppKit nor Foundation,
> so on macOS there is no path by which a call can reach Apple's implementation by accident.
> That holds because TUIKit re-exports only RichSwift. Foundation will be needed eventually;
> the answer is a `TUIFoundation` sibling shim — built like `WinFoundation` and likely from
> the same source, but its own module — deferred until something actually needs it.
>
> **Still open:** routing ChocolateKit's calls into TUIAppKit, and the full stub surface that
> routing requires. While a demo targets TUIAppKit directly it needs only what it calls.
**Executes:** [TermChocolatePlan.md](TermChocolatePlan.md) phases T1–T2 (+ the menu slice of T7)
and [WASMChocolatePlan.md](WASMChocolatePlan.md) phases W1–W2 (+ the menu slice of W5),
together, on one shared demo app.

---

## The claim being tested

WinChocolate is core + swappable backends: `ChocolateKit` (52,558 lines) is the shared AppKit
surface, and `NativeControlBackend`
([Sources/ChocolateKit/Native/NativeControlBackend.swift](../Sources/ChocolateKit/Native/NativeControlBackend.swift))
is the single 189-requirement protocol behind which Win32, GTK and InMemory already sit.
If that claim is true, two *radically* different UI surfaces — a terminal cell grid and the
browser DOM — are each one new directory plus a one-line façade, and app source does not
change at all.

The cheapest honest test of that claim is the oldest app in the world: a click counter.

---

## Exit criteria

A new `Demo/CounterDemo` — roughly 60 lines, **zero conditionals beyond the sanctioned
framework-import switch** — runs on all four backends:

| Surface | How it runs | Must be true | Result |
|---|---|---|---|
| **Win32** | `buildandrun.bat counter` | Unchanged behavior; window, labels, buttons, File→Quit all native | not run here (no Windows machine); untouched by construction — see F2 |
| **GTK** | `./run-linux.sh CounterDemo` | Unchanged behavior | ✅ builds on Linux; contract-test target restored (F8) |
| **macOS** | `swift build --target CounterDemo` | Builds against real AppKit — the control group | ✅ (needed F7 to build at all) |
| **TUI** | `cd /Users/bobby/AIResearch/TUIAppKit/Code/Demo && ./run.sh --tui` | Count increments on **mouse click and on keyboard** (Tab-then-Enter/Space); menu bar shows File, File→Quit exits and restores the terminal | ✅ **verified headlessly and on screen** — via TUIChocolate, not `CHOCOLATE_BACKEND` |
| **WASM** | `./build-wasm.sh && python3 -m http.server` → browser | Count increments on click; menu bar shows File; File→Quit shows a visible terminated state (a page cannot exit) | ✅ **verified in a browser** |

And, non-negotiably:

- **WinChocolate and LinChocolate still build and run on this branch, unchanged**, in the
  same commit as every spike change. `buildandrun.bat`, `run-wsl.bat --build`,
  `run-wsl.bat --tests` and the macOS `swift build` + contract tests are part of every slice's
  definition of done, not a final check.
- **`CHOCOLATE_BACKEND` unset behaves exactly as today** on all three desktop OSes: Win32 on
  Windows, GTK on Linux, InMemory elsewhere.
- Everything unimplemented **degrades visibly** — a labelled placeholder or a logged warning,
  never a blank rectangle, never a crash, never a lie.

---

## Step 0 — `Demo/CounterDemo`, the shared artifact

Modeled line-for-line on the existing smallest app,
[Demo/RunLoopDemo/main.swift](../Demo/RunLoopDemo/main.swift) (193 lines total, and already a
proven four-way-portable shape). The pieces it must use, because they are exactly the ones
that exercise the seam:

```swift
#if os(Linux)
import LinChocolate
#elseif os(Windows)
import WinChocolate
#elseif canImport(AppKit)
import AppKit          // + the TUI/WASM arms added by Step 1
#endif

let app = NSApplication.shared

// File menu with Quit — routed core-side through the responder chain.
let menuBar = NSMenu()
let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
let fileMenu = NSMenu(title: "File")
let quitItem = NSMenuItem(title: "Quit CounterDemo", action: "terminate:", keyEquivalent: "q")
quitItem.target = app
fileMenu.addItem(quitItem)
fileItem.submenu = fileMenu
menuBar.addItem(fileItem)
app.mainMenu = menuBar
```

plus an `NSWindow`, a flipped `ContentView` (so explicit frames read the same everywhere),
one `NSTextField(labelWithString:)` showing `Count: 0`, an **Increment** and a **Reset**
`NSButton`, `window.makeKeyAndOrderFront(nil)`, `app.run()`.

Button actions use the demo-local `onAction` sugar copied from
[Demo/RunLoopDemo/RunLoopDemoConveniences.swift](../Demo/RunLoopDemo/RunLoopDemoConveniences.swift)
— a retained `NSObject` trampoline over the control's **real** target/action. The framework
has no closure actions by design (Phase 18.2); keeping the trampoline demo-local is what
keeps CounterDemo buildable against real Apple AppKit, which is the control group for this
whole experiment.

**Why the File menu and not an app menu:** `"terminate:"` with `target = app` resolves through
`NSMenuItem.performAction()` → `NSApplication.sendAction` entirely in core code
([Sources/ChocolateKit/Menus/NSMenuItem.swift](../Sources/ChocolateKit/Menus/NSMenuItem.swift)).
A backend's only menu job is to *render* items and call `performAction()`. That makes menus
the cheapest possible cross-surface proof — and the one most likely to expose ordering bugs
(see the pending-menu trap in Step 2).

---

## Step 1 — Backend selection: `CHOCOLATE_BACKEND`

Today, selection is one `#if` in a convenience init
([NSApplication.swift:107-121](../Sources/ChocolateKit/Application/NSApplication.swift)):

```swift
#if os(Windows)
self.init(nativeBackend: Win32NativeControlBackend())
#elseif canImport(CGTK)
self.init(nativeBackend: GTKNativeControlBackend())
#else
self.init(nativeBackend: InMemoryNativeControlBackend())   // ← the trap
#endif
```

The comment above it records why the `#else` is dangerous: without the GTK arm, a Linux app
fell through to the *headless test* backend and launched with no GUI at all. Any new surface
must be selected **before** that `#else`.

**TUI and WASM are different kinds of choice, and the design must reflect that:**

- **WASM is compile-time.** A `wasm32` binary can only be the browser backend. It gets a new
  `#elseif os(WASI)` arm, placed before the `#else`. No runtime switch, no env var.
- **TUI is genuinely ambiguous.** The same macOS/Linux/Windows binary could reasonably drive
  either the GUI or the terminal — so it needs a runtime selector.

The rule: **a single `chocolateBackendOverride()` helper, read once, at the one place the
backend is instantiated.** No conditionals anywhere else.

```
CHOCOLATE_BACKEND=tui            # environment variable
--chocolate-backend=tui          # or launch argument (argument wins over env)
```

Recognized values: `tui`, plus `win32` / `gtk` / `inmemory` accepted as explicit
requests-for-what-you'd-get-anyway (useful for tests and for forcing the headless backend
deliberately rather than by accident). **An unset variable, an empty value, or an unknown
value means: do exactly what today's `#if` chain does.** An unknown value additionally logs
one warning line — degrade visibly, never silently. A requested backend that isn't compiled
into this binary (`tui` on a build without TUIKit) logs and falls back to the platform
default rather than dying.

This is additive: the existing `#if` chain becomes the `default:` path of the override, so
the Win32 and GTK behaviors are byte-identical when the variable is unset.

---

## Step 2 — TUI backend, minimum viable

New directory `Sources/ChocolateKit/Native/TUI/`, every file opening `#if canImport(TUIKit)`
— the same guard shape the GTK backend uses (`#if canImport(CGTK)`), which is also the guard
the selection arm tests.

Substrate: **TUIKit** at `/Users/bobby/src/frameworks/UILess/Code/TUIKit` — ~24,900 lines, a
proper SwiftPM package with a `TUIKit` library product, consumed as a **path dependency** for
the spike (a gate item before anything merges; see Gate Items below).

### Capability tiers — ANSI is the floor, VTG is the bonus

**Non-negotiable: the spike and the backend must run on a standard ANSI terminal.** Every
feature ships in a text-only form that works over plain `xterm`/`ssh`/`tmux` with no
graphics protocol at all. TUIKit probes for VectorTerminal (VTG) support at startup
(~400 ms; `TUIKIT_VTG=0` skips it), and where VTG *is* detected, richer rendering is switched
on — but **detection failing is a normal, fully-supported configuration, not a degraded
build**:

| Feature | ANSI floor (must work) | VTG detected (enhancement) |
|---|---|---|
| Toolbars | **Text-only mode**: labelled items in a single row, focusable, mnemonics, no icons | Real icons drawn as vector chrome above the cell grid |
| Image views | **A focusable, selectable item** — e.g. `[ Image: logo.png ⏎ ]` — that on activation opens the image in the platform's viewer (Preview on macOS, `xdg-open` on Linux, the default handler on Windows) or a web browser | Image rendered inline in place |
| Buttons/bezels | Box-drawing frames, attribute styling | Vector bezels where VTG can draw them |
| Any future rich control | An honest text affordance with the same API and the same actions | The richer form |

Two rules follow, and they are the ones to hold the line on:

1. **The API is identical in both tiers.** `NSToolbar`, `NSImageView` and friends expose the
   exact Apple surface either way; the app never asks which tier it got.
2. **The text tier is a first-class product, not a fallback of last resort.** It is what
   most users over ssh will see. Selecting an image item and having Preview open is a
   *feature* — ground rule 4's "degrade visibly, never silently" made concrete.

Capability detection is centralized (one query, at startup, cached) so no control does its
own probing, and a `CHOCOLATE_TUI_FORCE_ANSI=1` escape hatch forces the floor tier for
testing the path everyone will actually run.

### Coordinates stay in pixels

**Screen and view coordinates remain pixels (points) everywhere above the painter** — `NSRect`,
`frame`, `bounds`, event locations, `measureText` results. The backend separately knows the
**cell metrics** (cell width/height in pixels) and converts pixels → cells at exactly one place:
the painter, at paint time. Mouse input converts cells → pixels on the way in, using the same
metrics, so a click lands where the app thinks the control is.

This is critical for VTG — vector chrome draws at real pixel resolution across cell boundaries,
and if layout has already been rounded to whole cells upstream, that resolution is gone before
the vector layer sees it. For a standard ANSI terminal it is a *useful illusion*: the grid is
still integral, but quantisation happens late, from an intact pixel model, so the app and every
control keep behaving as if they live on a pixel surface. Cell size is a display property, like
DPI — not the app's coordinate system.

For the spike this means: `setFrame` stores the pixel rect unchanged, the cell metric is one
constant queried from one place, and no control or container ever rounds. Full rule and its
consequences: [TermChocolatePlan.md](TermChocolatePlan.md) § *Coordinates stay in pixels*.

### The ~25 requirements the counter needs

Everything else in the 189 is a **loud no-op stub** for the spike: it logs once, draws a
labelled placeholder where a control would go, and never crashes.

| ChocolateKit requirement | TUIKit mapping |
|---|---|
| `runApplication()` | `App(driver: ANSIDriver())` + `try await app.run(window)` — see run-loop note below |
| `makeRunLoopPump()` | Returns `nil` (inherits the default). On real Foundation `RunLoop.installPlatformPump` is a `preconditionFailure` — own-loop style is mandatory |
| `terminateApplication()` | `app.stop()`; driver `end()` must be unconditional and idempotent so a crash still restores the tty |
| `dispatchAsync(_:)` | Main-actor hop |
| `installMainMenu(_:)` | `MenuBar` + `Menu`; `menu.addItem(title, keyEquivalent:) { item.performAction() }`. **Pending-menu replay required** (see trap below) |
| `createWindow(title:frame:styleMask:usesMainMenu:)` | `Window` (full screen) or `FloatingWindow(title:frame:)` for titled/closable |
| `showWindow` / `closeWindow` | `app.present(_:)` / `app.dismiss(_:)` |
| `registerWindowClose/ShouldClose/Resize/MoveAction` | `FloatingWindow.onCloseRequest`; SIGWINCH → resize |
| `createView(frame:parent:)` | A plain `TUIView` container with absolute child frames — **frames stay in pixels**, converted to cells only when painted |
| `setViewFlipped(_:for:)` | No-op — the cell grid is already top-left origin |
| `createButton(title:frame:parent:isBordered:)` | `Button(title) { }` |
| `createTextField(text:frame:parent:options:)` | Non-editable + non-bordered options → `Label`; editable → `TextField` |
| `registerAction(for:action:)` | `button.onActivate = action` — the entire click path is this one call |
| `setText` / `setFrame` / `setHidden` / `setEnabled` | Direct property sets (`Label.text` repaints on set) |
| `setDrawsBackground` / `setTextColor` / `setBackgroundColor` / `setFont` / `setToolTip` | Cell style attributes; `setFont` collapses to bold/dim/underline — that is the documented ceiling |
| `invalidateControl(_:)` | Mark dirty; TUIKit's driver owns diffing |
| `measureText(_:font:)` ×2 | Cell counting **× cell width, returned in pixels** — the caller is layout, which lives in pixels. Spike-grade counting is `text.count`; correct is grapheme clusters + `wcwidth` (CJK = 2 cells, combining marks = 0). Wrong here desynchronises the whole grid — flagged, not solved, in the spike |
| `registerKeyEquivalentHandler(_:)` | TUIKit `keyEquivalent` on menu items; note **^M/^J/^I/^H are unusable** (the decoder turns them into Enter/Tab/Backspace) — Quit uses **^Q** |
| `runContextMenu(_:atScreenPoint:)` | Return `nil` for the spike, exactly as the GTK backend does today |

### The known-hard item: run-loop bridging

TUIKit's entry point is `@MainActor` and **async** (`try await app.run(window)`), while
`NSApplication.run()` is synchronous and expects not to return. Two candidate shapes, to be
decided with a measurement, not a preference:

1. **GTK-style executor install** — mirror
   [GTKNativeControlBackendPart01.swift:95-101](../Sources/ChocolateKit/Native/GTK/GTKNativeControlBackendPart01.swift):
   install a custom main-actor executor, then drive TUIKit's loop, so `Task { @MainActor }`
   jobs still run. This is the shape that already works in this codebase.
2. **`Task { try await app.run(window) }` + a main-queue drain** — simpler to write, but it
   depends on the libdispatch main-queue drain actually running, which is exactly the trap
   that once left a repeating timer dead under the GTK loop.

**macOS first.** Linux TUI is a stretch goal for the spike, not exit criteria — the
`RunLoop`/main-queue behaviors differ there and that is a separate fight.

Two operational notes: `ANSIDriver.begin()` throws without a real TTY (catch it and print a
useful message rather than crashing, as TUIKit's own demo does), and `TUIKIT_VTG=0` skips the
startup probe.

### Package changes

- `.package(path: "/Users/bobby/src/frameworks/UILess/Code/TUIKit")`, depended on by
  `ChocolateKit` only under `.when(platforms: [.macOS])` initially.
- TUIKit requires a **`.macOS("16.0")` platform floor**; adding it to this package's
  `platforms:` must be verified to not disturb Windows/Linux resolution — this is the single
  most likely way the spike breaks Win/Lin, so it is checked first, before any backend code.
- Resolution pulls RichSwift, swift-syntax (macro plugin, a large build) and VectorTerminalSDK.

---

## Step 3 — WASM backend, minimum viable

New directory `Sources/ChocolateKit/Native/WASM/`, every file `#if canImport(JavaScriptKit)`.
Substrate: **SwiftDOM** (`/Users/bobby/AIResearch/WASM/Code/SwiftDOM`), path dependency,
attached only under `.when(platforms: [.wasi])`.

| ChocolateKit requirement | SwiftDOM mapping |
|---|---|
| `runApplication()` | `JavaScriptEventLoop.installGlobalExecutor()`, mount the desktop element into `document.body`, **return** — the browser owns the loop. Retain the app and all closures |
| `makeRunLoopPump()` | `nil` |
| `terminateApplication()` | Visible terminated banner + inert desktop. A page cannot exit; this is a documented permanent divergence |
| `dispatchAsync(_:)` | `queueMicrotask` / `setTimeout(0)` |
| `installMainMenu(_:)` | A menu-bar div + dropdown divs built from `NSMenu.items`; click → `item.performAction()`. Same pending-menu trap |
| `createWindow(...)` | An absolutely-positioned div inside the desktop element, with framework-drawn title bar; close box → shouldClose/close handlers |
| `showWindow` / `closeWindow` | `display` + z-index ladder / remove |
| `createView(frame:parent:)` | `Element.div()` with `position: absolute` |
| `createButton(...)` | `Element.button()` |
| `createTextField(...)` | Label options → a styled div; editable → `Element.input()` |
| `registerAction(for:action:)` | `addEventListener(.click)` — **the token form**, stored in a `[NativeHandle: [EventListener]]` table so `destroyControl` releases. Never `.on(...)`, which retains forever in a global store |
| `setFrame` / `setHidden` / `setEnabled` / colors / font / tooltip | Inline styles, `disabled`, `title` |
| `invalidateControl(_:)` | Repaint the view's `<canvas>` if it has a draw action |
| `measureText(_:font:)` ×2 | Canvas 2D `measureText`. SwiftDOM does not wrap it yet — the spike may reach through the `rawValue` / `DOM.jsWindow` escape hatch, marked `// SPIKE:`, with the real fix landing upstream as SwiftDOM row S1 |
| `registerKeyEquivalentHandler(_:)` | Document-level `keydown`, suppressing browser defaults only for claimed equivalents |
| `runContextMenu(...)` | `nil` for the spike |

**Build loop:** `build-wasm.sh` cloned from `/Users/bobby/AIResearch/WASM/Code/SwiftDOMDemo/build.sh`
— `swift build --swift-sdk swift-6.3.1-RELEASE_wasm`, then
`swift package --swift-sdk … plugin js --output WebBuild --use-cdn`, then a static server —
plus a 12-line `index.html` that imports `./WebBuild/index.js` and calls `init()`.
**Always build the executable**, never a library-only wasm build: that path false-fails on a
JavaScriptKit C-shim issue (`/Users/bobby/AIResearch/WASM/Code/Freebird/PLAN.md:74`).

---

## The trap both backends share

`NSApplication.mainMenu`'s `didSet` calls `installMainMenu` **immediately**, and CounterDemo
(like every AppKit app) sets the menu *before* creating its window. Win32 tolerates this
because it can stash an `HMENU`; GTK does not, and solves it by holding a
`pendingMainMenu` and replaying it when the first window appears
([GTKNativeControlBackendPart20.swift:238-267](../Sources/ChocolateKit/Native/GTK/GTKNativeControlBackendPart20.swift)).

Both new backends attach their menu bar to a window (TUI: the top row of the window; WASM:
the desktop element or the window div) and therefore **hit this identically**. Implement the
pending-replay from the start in both; do not rediscover it.

---

## Verification

Run in this order — the first three are the regression gates and run on every slice:

```bash
swift build && swift run WinChocolateContractTests
```

```bash
./run-linux.sh --build
```

```bash
CHOCOLATE_BACKEND=tui swift run CounterDemo
```

```bash
./build-wasm.sh && python3 -m http.server 8080 --directory Demo/CounterDemo
```

Plus, on a Windows machine: `buildandrun.bat` and `buildandrun.bat counter`.

Manual checklist:

- [ ] Win32 demo unchanged; GTK demo unchanged; contract tests green
- [ ] `CHOCOLATE_BACKEND` unset → identical behavior to before the spike, all three OSes
- [ ] TUI: counter increments on mouse click **and** Tab-then-Enter
- [ ] TUI: File menu opens, Quit exits, terminal is restored (also after a forced crash)
- [ ] TUI: works on a plain ANSI terminal with `TUIKIT_VTG=0` and over `ssh`
- [ ] TUI: with VTG unavailable, a toolbar renders text-only and an image view is a selectable
      item that opens the image externally — both still fully operable
- [ ] TUI: no `NSRect` anywhere holds a cell coordinate; a click at a known pixel frame hits the
      control the app placed there (round-trip pixels → cells → pixels)
- [ ] WASM: counter increments on click and keyboard in Chrome
- [ ] WASM: File→Quit shows the terminated state; no console errors; reload is clean
- [ ] Every unimplemented control shows a labelled placeholder, not a blank

Automated, where cheap: TUIKit's `HeadlessDriver` (`send(_:)` / `snapshotText()`, harness
pattern in TUIKit's `Tests/TUIKitTutorialTests/TutorialMilestoneTests.swift`) can click the
button and assert the label text without a tty; SwiftDOM's zero-npm Chrome DevTools Protocol
harness (`/Users/bobby/AIResearch/WASM/Code/SwiftDOM/browser-test.sh`) does the same in a
browser. Both are worth wiring during the spike, because they are what makes the follow-on
phases testable at all.

---

## Findings ledger

*Executed 2026-08-16. This section is the spike's real output.*

### Stub error counts (publish the number)

| Backend | Target | Errors on first compile | Errors after the work below | Verdict |
|---|---|---|---|---|
| WASM | `CounterDemo` for `wasm32-unknown-wasip1` | **873** | **0** | **adapter — decisively** |
| TUI | — | not reached | — | **blocked before the spike could start** |

873 → 0, and the counter runs in a browser. For scale, the same core aimed at macOS produces
**9,919** errors — that is not a defect, it is the architecture: ChocolateKit *is* the
reimplementation of AppKit and CoreGraphics, so on macOS there is no Chocolate at all and the
demos build against the real frameworks as the control group.

The 873 broke down into three causes, none of them about UI:

| Cause | Errors | Resolution |
|---|---|---|
| `NotificationCenter` — WASI ships the new Observation-shaped API (`post(_:subject:)`), not AppKit's classic `post(name:object:)` | ~570 | `Sources/ChocolateKit/Runtime/WASIFoundationShims.swift` — a third arm of conditional C1 |
| `RunLoop` — declared but marked unavailable on WASI | ~60 | Same file; honest about the fact that a page cannot have a run loop |
| `WASMNativeControlBackend` not yet written | ~60 | Written |
| Remainder | rest | Fell out with the above |

### What was built

| Piece | Where |
|---|---|
| The shared proof app | [Demo/CounterDemo/](../Demo/CounterDemo/) — ~90 lines, one import switch, no other conditional |
| Backend selection (`CHOCOLATE_BACKEND`) | [Sources/ChocolateKit/Application/ChocolateBackendSelection.swift](../Sources/ChocolateKit/Application/ChocolateBackendSelection.swift), used once in `NSApplication.makeDefaultNativeBackend()` |
| WASI Foundation seam | [Sources/ChocolateKit/Runtime/WASIFoundationShims.swift](../Sources/ChocolateKit/Runtime/WASIFoundationShims.swift) |
| The browser backend | [Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift](../Sources/ChocolateKit/Native/WASM/WASMNativeControlBackend.swift) — ~16 overrides |
| Façade + build script + page | [Sources/WASMChocolate/](../Sources/WASMChocolate/), [build-wasm.sh](../build-wasm.sh), `Demo/CounterDemo/index.html` |

Verified in a browser: window with title bar renders; **Increment** increments; **Reset**
resets; the **File** menu opens; **File → Quit** terminates through the responder chain and
shows the honest terminated state. No console errors.

### Findings

| # | Surface | Finding | Lands as |
|---|---|---|---|
| F1 | Architecture | **The in-memory recorder is the right base class for a new backend.** Subclassing it gives all 189 requirements as honest no-ops, so a backend can be built ~16 methods at a time and never crash on the rest. Blocked at first: Swift cannot override methods declared in extensions, and the recorder was split across 9 extension files. Sixteen methods were moved into the class body under a "core seam" MARK; `final` was lifted. | Done. The moved set *is* the minimum seam a backend must answer for |
| F2 | SwiftPM | **`.when(platforms:)` gates use, not resolution.** Naming SwiftDOM unconditionally broke the Linux build outright — the path does not exist in the container, and JavaScriptKit's manifest needs a newer toolchain than it carries. Fixed by making the manifest *not name* the dependency unless `CHOCOLATE_WASM` is set; a manifest is a Swift program, so this is one `if`. | Done. This is the mechanism that keeps Win/Lin untouched |
| F3 | SwiftDOM | **Listener tokens must be retained.** `addEventListener` returns a token whose `deinit` removes the listener, so `_ = element.addEventListener(...)` unregisters it the instant the statement ends. The menu bar rendered perfectly and did nothing when clicked. Predicted as W-H7; still cost a debugging round | Done — tokens held per handle and per menu |
| F4 | Core | **A window's title arrives as `setText(_:for:)`,** the same call a label gets. Writing it to the window element replaced the title bar and content area with a text node. Backends that synthesize chrome must steer window text to their title label | Done — `windowTitleLabels` |
| F5 | Core | **`registerAction` is called more than once per control** (peer realization, then target/action changes). Appending a listener each time makes one click fire twice — the counter showed 6 for 3 clicks, which a less honest demo would have hidden | Done — the action listener is replaced, not appended |
| F6 | Build | A library-only wasm build is not a valid check (JavaScriptKit C-shim). `build-wasm.sh` always builds the executable, and PackageToJS needs `--product` when the package has several | Done |
| F7 | macOS | `RunLoopDemo` did not compile on macOS at all: the package declared no `platforms:`, so SwiftPM assumed 10.13 and `MainActor` was unavailable. Pre-existing, and it made the AppKit control group unusable | Fixed — `platforms: [.macOS(.v13)]`, Apple-only, no effect on Win/Lin |
| F8 | Tests | `Tests/.../TestDeclarations19.swift:341` failed the whole contract-test target on Linux with a type-checker timeout on one arithmetic literal. Pre-existing at `HEAD` (proved with a clean worktree build), and it blocked the regression gate | Fixed — expression split |

### The TUI blocker (read before planning terminal work)

**The terminal half could not start, and the reason is structural, not incidental.** Three
facts, each verified today, form a triangle with no platform in it:

1. **ChocolateKit compiles on Windows and Linux only.** On macOS it produces 9,919 errors by
   design — it *is* the AppKit/CoreGraphics reimplementation, so macOS uses the real ones.
2. **TUIKit is macOS-only in practice.** `Package.swift` declares `platforms: [.macOS("16.0")]`
   and depends unconditionally on `VectorTerminalSDK`, whose floor that is.
3. **The Linux container is Swift 6.0.3**, which cannot even parse TUIKit's
   `swift-tools-version: 6.3` manifest.

So there is currently **no platform on which ChocolateKit and TUIKit can both build**. This is
not a code problem in either project; it is a packaging and toolchain problem, and both
substrates are Bobby's, so it is schedulable rather than a dependency risk.

The unblocking work, smallest first:

| # | Work | Where |
|---|---|---|
| B1 | Upgrade the Linux image to Swift 6.3 | `Dockerfile` in this repo — it is one line: `ARG SWIFT_TAG=6.0-noble` |
| B2 | Make `VectorTerminalSDK` a conditional/optional dependency so TUIKit resolves without it, and drop the macOS floor for non-Apple builds | TUIKit — this is exactly TermChocolatePlan **Part U2** |
| B3 | Confirm TUIKit's driver builds against swift-corelibs-foundation on Linux | TUIKit Part U2 |

Only after B1–B3 does Step 2 of this document become executable. Note the pleasant
consequence of the ANSI-floor rule: B2 is *required* by the capability-tier design anyway —
VTG must already be optional for the plain-terminal tier to exist.

### Findings

| # | Surface | Finding | Lands as |
|---|---|---|---|

### Substrate gaps — file them, don't fake them

**TUIKit, VectorTerminalSDK (VTG) and SwiftDOM are all Bobby's own frameworks.** A missing
primitive is therefore a scheduling question, not a dependency risk — it can be added at the
source. That makes the rule simple and worth following even when working around it would be
faster:

> When the spike needs something the substrate does not have, **write it down here and ask for
> it**, rather than reaching around the substrate (raw JavaScriptKit inside the WASM backend,
> hand-rolled ANSI inside the TUI backend) to fake it in ChocolateKit.

Spike-grade code may use an escape hatch to keep moving, but only with a `// SPIKE:` marker
naming the row below that replaces it. The corresponding plan phase cannot land while the marker
is still there.

| # | Substrate | What's missing | Needed by | Lands as | Status |
|---|---|---|---|---|---|
| G1 | SwiftDOM | Canvas `measureText` / `TextMetrics` wrapper | Text measurement — the backend reaches through `rawValue.getContext("2d")` today, marked `// SPIKE:` | WASM plan row S1 | **open** |
| G2 | TUIKit | Resolve and build without `VectorTerminalSDK`, and without a macOS-only platform floor | The entire TUI half — see the blocker above | TermChocolate Part U2 | **open, blocking** |
| G3 | SwiftDOM | Nothing else. Elements, events, styles, timers and canvas covered every other need the counter had | — | — | — |

G3 is worth stating plainly: the hope that **SwiftDOM alone** would be enough of the browser
held for this spike. The only gap hit in anger was `measureText`.

Expect this table to be the most valuable thing the spike produces: it is a concrete, prioritised
feature list for three frameworks, derived from real use rather than speculation.

---

## Gate items

These must be resolved before any of this merges beyond the spike branch:

1. **Path dependencies are machine-specific.** TUIKit
   (`/Users/bobby/src/frameworks/UILess/Code/TUIKit`) and SwiftDOM
   (`/Users/bobby/AIResearch/WASM/Code/SwiftDOM`) are both consumed by path. A fresh clone
   cannot build the TUI or WASM backends. Options: publish tags, vendor, or keep path deps
   and gate the targets — decide before `develop`. Both are Bobby's own repos, so tagging is
   available whenever the spike's discovered changes have settled — which argues for path deps
   *during* the spike (fast iteration on both sides at once) and tags at the merge gate.
2. **TUIKit's published tag (0.1.3) predates much of the API this spike uses**, which is why
   path is the spike choice; a new tag is the likely resolution of item 1.
3. **The macOS 16.0 platform floor** that TUIKit imposes must be proven harmless to
   Windows/Linux resolution.
4. **Security, unrelated to the spike but found while surveying it:** the TUIKit checkout's
   git remote URL has a GitHub personal access token embedded in it, stored in plaintext in
   `.git/config`. It will leak into any log, screen share, or `git remote -v` output. Rotate
   the token and switch the remote to SSH or a credential helper.

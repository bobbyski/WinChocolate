# ActiveUI — Terminal Backend Plan (TermChocolate)

*This is a plan document only; no code here. It is scheduled for the future, not for now.*

**Working name:** TermChocolate — the terminal member of the Chocolate family.
**Intended home when it lands:** `Documents/SUPPORT_TERMINAL_PLAN.md`, with a cross-link row added to `Documents/PLAN.md` (Part 3 · Platform Expansion) and a paragraph in `Documents/Porting.md`.

---

## Context

Bobby wants ActiveUI apps to run in a console. The stated bar is honest and low: *"like surfing the web in lynx — you can do it but you won't often choose to."* Some things will not be the same; an image may become a button that opens Preview or a browser.

The reason to do it anyway is that ActiveUI's whole premise is one source tree across backends, and a terminal is the harshest possible test of that premise. If a screen written once renders on AppKit, UIKit, Win32, GTK **and** a character grid, the abstraction is real. It also unlocks the thing nobody else has: a full ActiveUI app usable over ssh on a headless box.

Three facts discovered while planning change the shape of this work completely, and they are why this is worth doing at all:

1. **TUIKit already exists and is 83% complete.** `/Users/bobby/src/frameworks/UILess/Code/TUIKit` — 24,912 lines, self-described as *"An AppKit-inspired terminal UI framework for Swift… AppKit's shape. Views own local coordinates; containers own clipping and translation; a responder chain routes keys; windows and dialogs own their focus scopes."* It has the cell buffer, the ANSI driver, termios raw mode, SGR-1006 mouse, SIGWINCH, 44 controls, a layout engine, focus scopes, and a headless driver for CI. It is not a starting point; it is a substrate.
2. **WinChocolate is not a monolith — it is a core plus swappable backends.** `ChocolateKit` (210 files, 52,558 lines) is the shared AppKit surface. `NativeControlBackend` (`Sources/ChocolateKit/Native/NativeControlBackend.swift`) is one protocol with ~200 requirements; `Win32NativeControlBackend`, `GTKNativeControlBackend` and `InMemoryNativeControlBackend` implement it. `WinChocolate` and `LinChocolate` are 21- and 16-line façades that do nothing but `@_exported import ChocolateKit`.
3. **Therefore the terminal backend is a fourth `NativeControlBackend`, not a fifth framework.** The AppKit surface, the layout solver, the run-loop pump design, the event model, the drawing protocol and the parity discipline are all already written. What is missing is one adapter directory and a façade.

That is the whole idea: **`TUINativeControlBackend` inside ChocolateKit, driven by TUIKit, fronted by a `TermChocolate` façade.** ActiveUI's 155 file headers gain one `#elseif` branch and nothing else changes.

Bobby's own note — *"TUIKit will need to be expanded, I am quite certain"* — is correct and is planned for explicitly as **Part U**, rather than being discovered late as slippage.

### Decisions already taken

| Question | Answer |
|---|---|
| Where the backend attaches | **A third Chocolate.** Not a `#if ACTIVEUI_TUI` arm through 63 control files. |
| Reach | **Anywhere Swift runs** — macOS, Linux over ssh, Windows console. |
| Fidelity | **Full interactive TUI, plus rich terminal extras** — VTG vector chrome where the host is VectorTerminal, iTerm2/Kitty inline images elsewhere, box-drawing and braille as the floor. |
| Proof apps | **All four, easiest → hardest**: CounterDemo → TestApp → Catalog → a real app. Later ones may be rev 2 or rev 3, but **what doesn't work must still run, just missing features.** |

---

## Ground rules

These extend the three iOS ground rules (`SUPPORT_IPAD_AND_IPHONE_PLAN.md`); they do not replace them.

1. **AppKit can never break.** Every slice is additive. The macOS suite, demo and screenshot probes stay green in the same change that lands terminal work. The header sweep in T3 adds a branch that is only taken when `TermChocolate` is importable, and it never is in a normal macOS build.
2. **The user never writes a conditional.** Zero `#if os(...)` in app code — a screen renders in a terminal because it was compiled against a different Chocolate, not because it was written for one. Framework-internal conditionals are allowed and concentrated at seams.
3. **We implement the Apple API, not something similar.** Inherited verbatim from `WinChocolate/CONTROL_PARITY.md`: exact API including defaults; never substitute or combine controls on the app's behalf; where the terminal has no equivalent, build a compound control from primitives that exposes the exact Apple API; a terminal *look* is fine, substituted *behaviour* is not.
4. **Degrade visibly, never silently.** A control the terminal cannot render shows a labelled placeholder band — never a blank rectangle and never a lie. An image renders inline where the terminal supports images and becomes a focusable "Open in Preview ⏎" affordance where it does not.
5. **Everything still runs.** Bobby's rule for the proof apps generalises: a missing feature degrades to an honest stub; it never crashes, never blocks launch, and never removes the screen.
6. **Upstream fixes go upstream.** A gap in TUIKit is fixed in TUIKit (Part U) and cross-linked, not worked around inside ChocolateKit. Same discipline as `WINCHOCOLATE_CHANGE_REQUESTS.md`. **TUIKit and VectorTerminalSDK (VTG) are both Bobby's own frameworks**, so this rule is enforceable rather than aspirational: a missing terminal primitive or a missing VTG drawing capability is *added at the source* — raise it as a Part U row and it can be built. Reaching around the substrate to fake something inside ChocolateKit is the wrong move even when it is the faster one, and the Part U list is expected to grow as Parts T and P discover what is actually missing.
7. **The dashboard ships current.** Bars move in the same change that lands the work. The number *is* the metric.

### Capability tiers — a standard ANSI terminal is the floor

Rules 4 and 5 have a specific, load-bearing consequence that is easy to lose in the excitement
about VTG, so it is stated here as a rule of its own:

**TermChocolate must run on a plain ANSI terminal.** `xterm` over `ssh`, inside `tmux`, with no
graphics protocol whatsoever, is the *primary* target and the configuration most users will
actually see. VTG (and iTerm2/Kitty inline images) are detected at startup and switch on richer
rendering where present — but **detection failing is a normal, fully-supported configuration,
not a degraded build.** Nothing is VTG-only; every feature ships in a text form first.

| Feature | ANSI floor — must work | VTG / rich terminal detected |
|---|---|---|
| Toolbars (`NSToolbar`) | **Text-only mode**: labelled items in a row, focusable, keyboard-reachable, mnemonics — no icons | Icons drawn as real vector chrome |
| Image views (`NSImageView`) | **A selectable, focusable item** (`[ Image: logo.png ⏎ ]`) that on activation opens the image in the platform viewer — Preview on macOS, `xdg-open` on Linux, the default handler on Windows — or a web browser | Rendered inline in place |
| Buttons and bezels | Box-drawing frames plus attribute styling | Vector bezels |
| Anything added later | An honest text affordance carrying the same API and the same actions | The richer form |

Two invariants hold the line:

1. **The API is identical in both tiers.** The app never asks which tier it got, and never
   branches on it.
2. **The text tier is a first-class product, not a fallback of last resort.** Selecting an image
   and having Preview open is a designed feature, not an apology.

Capability detection is centralized — probed once at startup, cached, queried from one place —
so no control does its own detection, and `CHOCOLATE_TUI_FORCE_ANSI=1` forces the floor tier so
the path everyone actually runs is the path that gets tested. (`TUIKIT_VTG=0` disables TUIKit's
own ~400 ms probe.) Phase L1 formalises the detection; Phase T11 and Part U6 add the rich tier
*on top of* a floor that already works.

### Coordinates stay in pixels

**Screen and view coordinates remain pixels (points) everywhere above the painter.** `NSRect`,
`NSPoint`, `frame`, `bounds`, `NSEvent.locationInWindow`, hit-testing, `measureText` results —
all of it stays in the units AppKit uses. The backend additionally knows the **cell metrics**
(cell width and height in pixels, queried from the terminal where it will tell us, otherwise a
fixed contract value) and converts pixels → cells at exactly one place: the painter, at paint
time.

This is not a stylistic preference; it is load-bearing in both tiers:

- **Critical for VTG.** Vector chrome draws at real pixel resolution *between* and *across*
  cell boundaries. If layout has already been rounded to whole cells upstream, that resolution
  is gone before the vector layer ever sees it, and VTG output is permanently as coarse as the
  ANSI output. Keeping pixels intact all the way down is the only way the rich tier can be
  genuinely richer.
- **A useful illusion for standard ANSI.** The floor tier still quantises — it must, the grid is
  integral — but it quantises *late*, from an intact pixel model, using shared cell metrics. The
  app, the layout math and every control keep behaving as if they live on a pixel surface, which
  is what makes the same source render everywhere. Cell size becomes a display property, like
  DPI, rather than the app's coordinate system.

Consequences to hold to: never store a cell coordinate in an `NSRect`; never round in a control
or a container, only in the painter; report cell metrics through the same seam that reports
screen geometry (`primaryScreenFrame`, `winDisplayScale`) so a resize changes metrics rather
than reinterpreting frames; and mouse input converts cells → pixels on the way *in*, using the
same metrics, so a click lands where the app thinks the control is. T1.4 fixes the metric
contract before any painting exists, precisely because H1 is unforgiving about inconsistency.

---

## Where we actually are (measured 2026-08-16)

- **ActiveUI is 183 files / 53,158 lines**, one target. **155 of them** carry the six-line Chocolate import header (`#if canImport(LinChocolate) / #elseif canImport(WinChocolate) / #elseif canImport(AppKit) / #elseif canImport(UIKit)`). That header is the entire ActiveUI-side integration point.
- **The seam is a compile flag, not a protocol.** `Code/ActiveUI/Package.swift:28` — `.define("ACTIVEUI_APPKIT", .when(platforms: [.macOS, .windows, .linux]))`. There is no `ViewPeer`; `ARCHITECTURE_REVIEW.md` recommended one in 2026-07 and it was never built. **We are not building it now** — the Chocolate route is what lets us skip it.
- **`AUIView.nativeView` is `public let`, non-optional, typed `AUINativeView`** (`AUIView.swift:968`). Every control constructs a concrete native object. This is exactly why the Chocolate route wins: `AUINativeView` becomes ChocolateKit's `NSView` and nothing in ActiveUI notices.
- **Layout is 100% ActiveUI's own.** No Auto Layout, no `NSStackView`. `layoutSize(fitting:)` (`AUIView.swift:1208`) → `place(in:)` (`AUIView.swift:1250`) → one `AUIAnimationRunner.setFrame` call. Pure `CGFloat` geometry, flexbox-shaped, already headlessly testable. **This is the single biggest asset for a terminal port** — the math is intact, only the units change.
- **No reactivity to reimplement.** Retained objects, explicit `refresh()`, provider closures re-pull. `Documents/Repaint-and-Update-Model.md`.
- **A self-drawing control tier already exists and was justified by this exact use case.** 14 `AUIDrawn*` controls plus `Drawing/`. `Drawing/AUIDrawnStyle.swift:12` — *"the drawn look exists for canvases, custom controls, and ports that render ActiveUI controls without AppKit underneath."* `Drawing/AUIButtonBezel.swift:21` — *"this file is the reference rendering WinChocolate reproduces."*
- **ChocolateKit's drawing seam is already the right size.** `NativeDrawingContext` (`NativeControlBackend.swift:266`) is nine methods — fill/stroke path, draw text, draw image (path or RGBA), linear gradient, clip, save/restore. `measureText(_:font:)` at `:1089` and a wrapping variant at `:1096`. A cell painter implements these.
- **ChocolateKit's backend selection is one `#if` in a convenience init** (`NSApplication.swift:114-119`), and `public init(nativeBackend:)` at `:124` already exists for explicit injection.
- **TUIKit's driver seam matches.** `TerminalDriver` (`Terminal/TerminalDriver.swift:32`) is `begin/end/present/setCursor/inputStream/setClipboard/suspend/resume`, and its `present(_:)` doc states *"The driver owns diffing"* — the seam for damage-based repaint exists even though the optimisation does not yet.
- **TUIKit gaps, named now:** full redraw per frame (`ANSIDriver.swift:22, 262-273`), macOS-only platform floor (`.macOS("16.0")`, set by VectorTerminalSDK), no Windows console driver, Controls v3 at 0%, VTG chrome at 75%, code editor at 62%.
- **Test vehicles that already exist and transfer:** `Tests/ActiveUIWindowsSmoke/main.swift` — a plain executable smoke runner written precisely because swift-testing was absent from a foreign toolchain. It is the pattern for a terminal smoke runner. TUIKit's `Terminal/HeadlessDriver.swift` (215 lines) is the CI renderer.
- **Nothing terminal-shaped exists inside ActiveUI today.** `Code/ActiveUITerminal` is the opposite thing — a SwiftTerm pty *emulator embedded as an ActiveUI control*. Zero hits for `ncurses`, `curses`, `TUI` in `Sources/`.

---

## Dashboard

```
Overall Progress                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 / 25 phases)

Part T · TermChocolate Backend  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 / 12)  ⏳
Part U · TUIKit Expansion       ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 /  6)  ⏳
Part P · Proof Apps             ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 /  4)  ⏳
Part L · Terminal Last Mile     ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ( 0 /  3)  ⏳

── Part T · TermChocolate Backend (the fourth NativeControlBackend) ────
Phase T0  · Honest Baseline           ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T1  · Backend Decision (gate)   ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T2  · Terminal App Harness      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T3  · Core Seam & Cell Painter  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T4  · Input Core                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T5  · Theme, Colour & CSS       ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T6  · Controls                  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T7  · Windows & Presentation    ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T8  · Tables & Collections      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T9  · Subsystems                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T10 · Tests Run In A Terminal   ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase T11 · Rich Terminal Extras      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
── Part U · TUIKit Expansion (upstream, runs alongside T) ──────────────
Phase U1  · Damage-Diff Repaint       ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase U2  · Linux Driver              ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase U3  · Windows Console Driver    ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase U4  · Controls v3               ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase U5  · Text Metrics & wcwidth    ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase U6  · VTG Chrome Completion     ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
── Part P · Proof Apps (easiest → hardest; rev 2 and 3 allowed) ────────
Phase P1  · ActiveUICounterDemo       ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase P2  · ActiveUITestApp           ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase P3  · ActiveUICatalog           ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase P4  · A Real App                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
── Part L · Terminal Last Mile ────────────────────────────────────────
Phase L1  · Capability Detection      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase L2  · ssh / tmux / screen Pass  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
Phase L3  · Distribution              ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; 🚫 Blocked &nbsp;|&nbsp; ⏸ Postponed

> **Ordering.** T0 → T1 is a gate: nothing else starts until the packaging question is answered and the spike has a measured error count. T2 comes before T3 so there is something on screen to be wrong. Part U is *not* sequential after Part T — U1, U2 and U5 are pulled forward the moment T3/T4 need them, and each U phase is a pull request against TUIKit that T waits on. Part P interleaves: P1 lands at the end of T4 and is the gate for T6; P2 rides T6–T8; P3 and P4 are exposure tests that will find work and push bars backwards. Part L runs last and only makes sense once P3 renders.

> **Discovery caveat.** Like Parts C and D of the iOS plan, Part P exists to *find* work as much as to do it. Every gap the TestApp, Catalog or a real app exposes lands here as a new row or an upstream TUIKit issue. **Expect the bars to move backward before they finish.** That is the plan working, not the plan failing.

---

## The architecture, in one diagram

```
   User's screen source (zero #if — ground rule 2)
                    │
              ActiveUI  (183 files, unchanged except 155 header lines)
                    │   AUINativeView = NSView, layout math is ActiveUI's own
                    │
        ┌───────────┴───────────┐
   import AppKit          import TermChocolate      ← the 21-line façade
   (macOS GUI)                  │                     @_exported import ChocolateKit
                                │
                          ChocolateKit  (52,558 lines — already written)
                          NSView/NSWindow/NSButton/NSEvent/NSBezierPath…
                                │
                       NativeControlBackend  (one protocol, ~200 reqs)
                                │
      ┌──────────┬──────────────┼──────────────┬─────────────────┐
   Win32        GTK         InMemory      TUINativeControlBackend   ← NEW: the only
  (exists)    (exists)      (exists)              │                   real new code
                                                  │
                                              TUIKit  (24,912 lines, 83%)
                                        CellBuffer · ANSIDriver · TerminalDriver
                                        termios · SGR-1006 mouse · SIGWINCH
                                                  │
                                    ┌─────────────┼─────────────┐
                                 ANSIDriver   HeadlessDriver   VTG chrome
                                 (terminal)      (CI)      (VectorTerminalSDK)
```

The new code is one directory — `ChocolateKit/Native/TUI/` — plus a façade. Everything above and below it exists.

---

## Difficult issues

### Hard and unavoidable

| # | Issue | Why it is hard |
|---|---|---|
| **H1** | **Points → cells, without ever leaving points.** ActiveUI lays out in `CGFloat` points and calls `place(in:)` with sub-pixel frames. A cell grid is integral and anisotropic (~8×16 pt). | The coordinate system stays pixels — see *Coordinates stay in pixels* above — so the difficulty moves to the painter, where it belongs: quantisation must be *consistent* or adjacent controls overlap or leave gaps. Rounding independently per view is wrong; the painter snaps on a shared grid and containers absorb the remainder. Text that fits in 80pt does not fit in 10 cells. |
| **H2** | **`NativeDrawingContext` is vector-shaped.** `fillPath`, `strokePath`, `drawLinearGradient`, `clip(to:)`, `NSBezierPath` bezels with 0.5pt insets and top-edge highlights. | A cell painter has to answer these meaningfully, not just no-op: a filled rounded rect becomes a box-drawing frame, a gradient becomes a single resolved colour, a stroke becomes a line-drawing glyph. This is the single largest piece of genuinely new logic. VTG (T11/U6) makes a subset of it real vector output instead. |
| **H3** | **Text measurement.** ~20 CoreText call sites (`AUILabel.swift:340`, `AUIRangeSlider.swift:495`, `AUIDrawnSegmentedControl.swift:246/318/330`, …) plus ChocolateKit's `measureText`. | Must become grapheme-cluster + `wcwidth` counting: CJK is 2 cells, emoji are 2 and inconsistent across terminals, combining marks are 0, and ZWJ sequences are a lottery. Getting this wrong desynchronises the whole grid, not just one label. |
| **H4** | **Modal APIs use nested run loops.** `AUIAlert`/`AUISheet` call `NSApplication.runModal`. | Was H4 on the iOS plan too. ChocolateKit already declares `runModal`/`stopModal` on the backend protocol, so the shape exists — but a terminal run loop is `poll()` on stdin plus a timer deadline, and re-entering it needs the same care Win32 needed. `Docs/RunLoopDesign.md` is the reference. |
| **H5** | **Focus and hit-testing are the platform's, and ActiveUI owns neither.** It broadcasts `.auiFocusDidChange` and reads `window.firstResponder`; there is no focus ring and no tab order in ActiveUI. | The terminal must *build* focus, not port it. Good news: TUIKit already has it (windows are focus scopes, Tab/Shift-Tab traversal, `acceptsFirstResponder`), so the work is wiring ChocolateKit's responder chain to TUIKit's rather than inventing one. |
| **H6** | **Packaging: how does a macOS build import TermChocolate instead of AppKit?** SwiftPM conditional dependencies are keyed on *platform*, and macOS is the same platform for both builds. | The LinChocolate façade comment documents exactly this trap in reverse. Resolved in T1: SwiftPM **package traits** (tools 6.1+; TUIKit is already on 6.3) is the intended answer, with a parallel second target over the same `path` as the fallback. Nothing else starts until this is decided. |
| **H7** | **Test blindness.** 194 `#if os(macOS)` guards in `Tests/ActiveUITests/` — the same trap the iOS plan named. | A green terminal run would prove nothing if the tests compile to nothing. T10 de-gates in the corrected `ACTIVEUI_APPKIT` style, and the terminal smoke runner must be provably able to fail — a deliberate canary at least once. |
| **H8** | **TUIKit redraws the whole tree every frame** (`ANSIDriver.swift:22`). | Fine for a 44-control demo, not fine for the Catalog over ssh at 200ms RTT. U1 is not optional by P3. |

### Real but postponable

| # | Issue | Postpone by |
|---|---|---|
| **P1** | `AUITable`/`AUIOutlineView`/`AUICollectionView` — 2,400+ lines against `NSTableView`/`NSOutlineView` | TUIKit has `TableView`/`TreeView`/`ListView`; ship single-column first, columns in T8 rev 2 |
| **P2** | `AUITextEditor`, `AUISyntaxTextView`, the code editor | TUIKit has `TextView`/`SyntaxTextView` at 62%; honest read-only band until U4 |
| **P3** | `AUIBrowser`, `AUIWeb` (WKWebView) | Permanently a "Open in browser ⏎" affordance — ground rule 4 |
| **P4** | Drag & drop | No terminal idiom; cut/paste via OSC 52 covers the real need |
| **P5** | Printing | Render to text/PDF via the existing `AUICanvas.render(in:bounds:)` escape hatch, later |
| **P6** | `AUIVisualEffectView`, shadows, corner radius, gradients | Already `canImport(QuartzCore)`-guarded and already degrade; resolve to flat colour |
| **P7** | Animation / `AUITicker` | Terminal-rate ticking works; ease curves collapse to steps. Defer polish. |
| **P8** | Accessibility | The terminal *is* the accessibility surface for screen readers; revisit after L1 |
| **P9** | `ActiveUITerminal` (the pty control) inside a terminal app | A terminal in a terminal. Genuinely funny, genuinely deferred to P3 rev 3. |

### Permanently absent

Sub-cell geometry. True vector bezels outside VTG. Sub-pixel animation. Hover on terminals without mouse reporting. Colour fidelity below the terminal's palette. `NSVisualEffectView` blur. Real font rendering — `AUIFont`'s `.body`/`.headline`/`.caption` collapse to bold/dim/underline attribute sets and that is the ceiling. None of these get a stub that pretends otherwise; each gets a documented no-op and a row in `TERMINAL_PARITY.md`.

---

## Part T — TermChocolate Backend

### Phase T0 — Honest Baseline ⏳

Tell the truth before writing anything.

| # | Area | Notes |
|---|---|---|
| T0.1 | This document lands as `Documents/SUPPORT_TERMINAL_PLAN.md` | Plus a cross-link row in `PLAN.md` Part 3 and a paragraph in `Porting.md` |
| T0.2 | `TERMINAL_PARITY.md` created, empty but structured | Copy `WinChocolate/CONTROL_PARITY.md` columns wholesale; replace "Classic Win32 counterpart" with "TUIKit counterpart", "Modern Windows" with "VTG" |
| T0.3 | Measure and record TUIKit's real state | Its `PLAN.md` claims 83% (73/88). Verify, and record which of Phases 8/10/11/15 block us |
| T0.4 | `buildcheck-term.sh` | Compile-only check, header copied from `buildcheck-ios.sh`: *green here proves no AppKit type leaked into the terminal path; it does not prove the terminal works* |
| T0.5 | Sweep ActiveUI doc comments that claim "every platform" | The `AUINativeHost` comment (*"a hosted NSView travels nowhere"*) is already correct and becomes load-bearing |

**Exit:** the plan, the parity file and the build check exist, and `PLAN.md` links here. No Swift written.

### Phase T1 — Backend Decision (gate) ⏳

The one phase that can cancel the project. Mirrors iOS A1.

| # | Area | Notes |
|---|---|---|
| T1.1 | **Resolve H6** — traits vs. second target vs. env-var backend injection | Recommendation: SwiftPM package traits. `NSApplication.init(nativeBackend:)` (`NSApplication.swift:124`) already exists as the injection point, so runtime selection is the cheap fallback on Linux where `LinChocolate` already resolves |
| T1.2 | **The spike, with a number.** Stub `TUINativeControlBackend` conforming to `NativeControlBackend` with every method `fatalError`, wire the façade, compile ActiveUI against it | The iOS A1 spike went 385 → 313 errors and that number is what made the decision real. Do the same here: publish the error count |
| T1.3 | Inventory `NativeControlBackend`'s ~200 requirements against TUIKit's surface | Three buckets: *direct adapt* / *compound from primitives* (ground rule 3) / *honest no-op*. This inventory becomes `TERMINAL_PARITY.md`'s first fill |
| T1.4 | Cell-metric decision | Fix the point→cell ratio (proposal: 8pt × 16pt) and decide who rounds — the painter, not the view. Write it into `Porting.md` as a contract, because H1 is unforgiving |
| T1.5 | Run-loop design note | `poll()`/`select()` on stdin + timer deadline, as a `RunLoopPlatformPump` (`waitForEvents(until:)` / `wake()`). TUIKit's `inputStream` is an `AsyncStream`; reconcile the two models here, on paper |
| T1.6 | Decide the ActiveUI header sweep shape | One `#elseif canImport(TermChocolate)` placed **first** in all 155 headers, scripted, reviewed as one commit. It must be provably inert in a normal macOS build |

**Exit:** a written decision in `Porting.md` with a measured error count behind it, and a stub backend that compiles. If the count says this is a rewrite rather than an adapter, the plan stops here and says so.

### Phase T2 — Terminal App Harness ⏳

Something on screen to be wrong.

| # | Area | Notes |
|---|---|---|
| T2.1 | `Code/ActiveUITermHarness/` — a SwiftPM executable, no XcodeGen needed | Renders one hard-coded `AUIStack` with a label and a button |
| T2.2 | `buildandrun-term.sh` | Build, run, restore the terminal on exit *and on crash* — an app that leaves the tty in raw mode is unusable |
| T2.3 | Alt-screen lifecycle wired through `NSApplication.run()` | `TerminalDriver.begin()`/`end()`; `end()` must be unconditional and idempotent — TUIKit's protocol already promises this |
| T2.4 | SIGWINCH → `NSWindow` resize → ActiveUI `invalidateLayout()` | TUIKit has the signal source (`ANSIDriver.swift:575-604`); the work is the bridge |

**Exit:** `./buildandrun-term.sh` shows a label and a button in Terminal.app, resizes correctly, and Ctrl-C leaves the terminal clean.

### Phase T3 — Core Seam & Cell Painter ⏳

The largest genuinely new code (H2).

| # | Area | Notes |
|---|---|---|
| T3.1 | The 155-header sweep | One scripted commit. macOS suite green in the same change — ground rule 1's first real test |
| T3.2 | `TUIDrawingContext: NativeDrawingContext` | The nine methods over `CellBuffer`. `fillPath` → block fill; `strokePath` → box-drawing/line glyphs; `clip(to:)` → `CellBuffer`'s already-clipped writes |
| T3.3 | `measureText(_:font:)` and the wrapping variant | Depends on **U5**. Until U5 lands, ASCII-only `count` with a loud TODO — and a test that fails on CJK so it can't be forgotten |
| T3.4 | Cell quantisation per T1.4 | Container absorbs remainder; snap on a shared grid. Golden-file tests over `HeadlessDriver` from day one |
| T3.5 | Ride the drawn tier | `AUIDrawn*` (14 controls) + `Drawing/` route through T3.2 with no per-control work. This is the beachhead the iOS plan measured at ~⅓ of the framework |
| T3.6 | `AUIButtonBezel` → cell bezel | It is explicitly *"the reference rendering WinChocolate reproduces"* — reproduce it in cells and the drawn tier follows |

**Exit:** an `AUIDrawnButton` renders as a recognisable button in cells, and a golden-file test over `HeadlessDriver` locks the output. A deliberately broken bezel turns that test red.

### Phase T4 — Input Core ⏳

| # | Area | Notes |
|---|---|---|
| T4.1 | Key decode → `NSEvent` → ActiveUI `AUIKeyEvent` | `AUIKeyEvent` is already a platform-neutral value type — reuse it verbatim. TUIKit's `Key` enum covers arrows, function keys, home/end/page |
| T4.2 | SGR-1006 mouse → `mouseDown`/`mouseUp`/`mouseDragged`/`scrollWheel` | ActiveUI is responder-chain based *on purpose* (`AUIPlatform.swift:57`), which is exactly what a terminal can deliver — no gesture recognisers to fake |
| T4.3 | Focus: bridge ChocolateKit's responder chain to TUIKit's focus scopes (H5) | Tab/Shift-Tab traversal, visible focus indicator (reverse video or a VTG ring), `.auiFocusDidChange` fires |
| T4.4 | Hover → `:hover` where mouse reporting exists; inert where it does not | `onHover` is already a single closure on both existing backends |
| T4.5 | Input testability | The iOS lesson and the `no-accessibility-synthetic-input` rule both apply: drive `HeadlessDriver` with a scripted byte stream, plus a control experiment that must fail |

**Exit:** `ActiveUICounterDemo` — unmodified, 36 lines, zero conditionals — runs in a terminal and the count increments on click **and** on Tab-then-Enter. This is **P1**.

### Phase T5 — Theme, Colour & CSS ⏳

| # | Area | Notes |
|---|---|---|
| T5.1 | `AUICSSColor` → 24-bit truecolor, with 256- and 16-colour fallbacks | The CSS parser is already nearly platform-free — ~39 `NS`/`UI` hits in 506 lines |
| T5.2 | Font traits collapse to SGR attributes | bold / dim / italic / underline / reverse. `.headline` → bold, `.caption` → dim. Documented as a ceiling, not a bug |
| T5.3 | Box model in cells | `padding`/`margin`/`gap` quantise; `border` → box-drawing; `border-radius` → rounded box-drawing corners where the charset allows |
| T5.4 | `:hover` / `:active` / `:focus` re-resolve in place | `AUIThemeInteraction.swift` already does this; only the paint path changes |
| T5.5 | `@media (prefers-color-scheme)` from terminal background detection | OSC 11 query; default dark, since that is what terminals are |
| T5.6 | Decide the drawn-swap policy | `AUIThemeSwappable.makeThemedTwin()` — on the terminal, is the drawn twin always used? Probably not, since TUIKit's own controls are richer. Record the answer; remember `theme-swap-drops-control-state` and `stale-child-refs-after-theme-swap` |

**Exit:** the Catalog's shipped `.css` theme files change the terminal app's appearance, and a light/dark switch is visible.

### Phase T6 — Controls ⏳

Ground rule 3 applied ~50 times. TUIKit's 44 controls do most of it.

| # | Area | Notes |
|---|---|---|
| T6.1 | Text tier — `NSTextField`, `AUILabel`, `AUISearchField` | TUIKit `TextField` |
| T6.2 | Buttons & toggles — `NSButton`, `AUIToggle`, `AUISwitch`, `AUIRadioGroup`, `AUICheckbox` | Direct adapt |
| T6.3 | Value tier — `AUISlider`, `AUIStepper`, `AUIProgressBar`, `AUILevelIndicator`, `AUIGauge` | Direct adapt; `AUIGauge`/`AUIGradientRing` are compound-from-primitives or braille |
| T6.4 | Pickers — `AUIPicker`, `AUIComboBox`, `AUIDatePicker`, `AUIColorWell` | `NSDatePicker` is *the* worked example of ground rule 3 in `CONTROL_PARITY.md`; TUIKit has `DatePicker`, `CalendarView`, `ColorPicker` |
| T6.5 | `AUISegmentedControl`, `AUITokenField`, `AUIPathControl` | TUIKit has `SegmentedControl`, `PathControl`; token field is compound |
| T6.6 | Media tier — `AUIImageView` | **The lynx moment.** Inline image where supported (T11); otherwise a focusable band: `[🖼 diagram.png — Open ⏎]` opening Preview or `$BROWSER` |
| T6.7 | Every control that lands updates `TERMINAL_PARITY.md` in the same slice | And, per `catalog-is-part-of-done`, the Catalog page gains its terminal band |
| T6.8 | No-equivalent set → honest unavailable stubs | Ground rules 4 and 5: labelled placeholder, app still runs |

**Exit:** `ActiveUITestApp` launches in a terminal with every screen reachable. Missing controls show labelled bands. Nothing crashes. This is **P2**.

### Phase T7 — Windows & Presentation ⏳

| # | Area | Notes |
|---|---|---|
| T7.1 | `NSWindow` → TUIKit `Window`/`FloatingWindow`/`Panel` | TUIKit windows are already focus scopes with their own chrome |
| T7.2 | `AUIAlert`, `AUISheet`, `AUIPopover` → centred modal panels | **H4** — the nested-run-loop question resolved here in code |
| T7.3 | Menus — `AUIMenuBar`, context menus | TUIKit `MenuBar`; `AUIThemeElement.swift` already treats `NSMenu` as a model-rendered non-view, which is the right shape |
| T7.4 | `AUIToolbar` → TUIKit `Toolbar`/`StatusBar` | |
| T7.5 | `AUISplitView`, `AUISidebarSplitView`, `AUIScrollView` | TUIKit has `SplitView`, `ScrollView`, `TabView` |
| T7.6 | File / colour / font dialogs | TUIKit `FileDialog`; `runFileDialog`/`runColorChooser` are already on the backend protocol |

**Exit:** an alert opens, blocks, returns a result, and the screen underneath repaints correctly. Menu bar navigable by keyboard.

### Phase T8 — Tables & Collections ⏳

The largest single subsystem, exactly as it was on iOS.

| # | Area | Notes |
|---|---|---|
| T8.1 | `AUITable` → TUIKit `TableView` | Rev 1: single column. Rev 2: real columns with width negotiation in cells |
| T8.2 | `AUIOutlineView` → TUIKit `TreeView` | Disclosure triangles are `▸`/`▾` — the one place the terminal is arguably better |
| T8.3 | `AUICollectionView` → `ListView` with flow | Rev 2 |
| T8.4 | Selection, activation, keyboard navigation | Arrows + Enter; mouse where available |
| T8.5 | Virtualisation | A 10,000-row table over ssh is the case that makes **U1** mandatory |

**Exit:** a 10,000-row table scrolls at readable speed over a real ssh session to a real remote host.

### Phase T9 — Subsystems ⏳

Honest-subset depth, as A9 was.

| # | Area | Notes |
|---|---|---|
| T9.1 | Pasteboard → OSC 52 | TUIKit already has `setClipboard` on the driver |
| T9.2 | Drag & drop → **P4, absent** | Documented no-op |
| T9.3 | Printing → text/PDF via `AUICanvas.render(in:bounds:)` | The escape hatch already renders into an arbitrary context |
| T9.4 | Accessibility → the terminal is the surface | Ensure focus/labels reach a screen reader reading the tty |
| T9.5 | Undo — `NSUndoManager` | ChocolateKit `Runtime/` already has it |
| T9.6 | Timers / animation → `AppTimer` at terminal frame rate | Ease curves collapse to steps (**P7**) |

**Exit:** copy from a terminal ActiveUI app pastes into another Mac app. Everything else has a documented, tested no-op.

### Phase T10 — Tests Run In A Terminal ⏳

Runs continuously from T3; gets its own bar so progress cannot be faked (H7).

| # | Area | Notes |
|---|---|---|
| T10.1 | `Tests/ActiveUITerminalSmoke/main.swift` | Plain executable, copying `ActiveUIWindowsSmoke`'s pattern and its stated rationale verbatim |
| T10.2 | De-gate the 194 `#if os(macOS)` tests to `ACTIVEUI_APPKIT` where correct | The corrected pattern already covers 56 |
| T10.3 | Golden-file cell rendering over `HeadlessDriver` | The terminal's answer to screenshot probes. A `CellBuffer` diff is a far better test artifact than a PNG |
| T10.4 | Scripted-byte-stream input tests | Per T4.5 |
| T10.5 | **The canary.** Deliberately break a bezel and prove the suite goes red the same day | Non-negotiable — this is what makes T10's bar mean anything |

**Exit:** a red terminal regression turns a slice red the same day it lands, proven at least once by an intentional canary.

### Phase T11 — Rich Terminal Extras ⏳

The ceiling Bobby asked for — full interactive TUI *plus* the good stuff.

| # | Area | Notes |
|---|---|---|
| T11.1 | Capability probe → a `TerminalCapabilities` value | Truecolor, mouse, images (which protocol), VTG, charset. Everything below degrades off this |
| T11.2 | **VTG vector chrome** via `VectorTerminalSDK` (≥1.5.6) | TUIKit's Phase 10 (75%, **U6**). Where the host is VectorTerminal, `strokePath`/`fillPath`/gradients become *real vector output* rather than glyph approximations — H2 largely dissolves |
| T11.3 | Inline images — iTerm2 OSC 1337, Kitty graphics, sixel | The other half of T6.6. `AUIImageView` renders for real where it can |
| T11.4 | `ActiveUICharts` via braille (U+2800) | 2×4 sub-cell resolution; VTG where available |
| T11.5 | `ActiveUIDiagram` / `ActiveUIBoards` | Box-drawing; VTG where available |
| T11.6 | The Preview / `$BROWSER` escape hatch as the documented floor | Bobby's original instinct, kept as the honest fallback rather than the default |

**Exit:** the same chart renders as braille in Terminal.app and as real vectors in VectorTerminal, from one unmodified `ActiveUICharts` call.

---

## Part U — TUIKit Expansion

Upstream work in `/Users/bobby/src/frameworks/UILess/Code/TUIKit`, pulled forward as Part T needs it. Ground rule 6: fixed there, not worked around here.

**Both substrates are Bobby's — TUIKit and VectorTerminalSDK (VTG).** So a discovered gap is a
scheduling question, not a dependency risk: name the missing primitive, add a U-row, build it.
The rows below are what is known missing *today*; Parts T and P will find more, and a new U-row
appearing mid-phase is the process working. Where a gap sits in VTG rather than TUIKit
(a drawing capability the vector layer cannot yet express — icon rendering for toolbars, inline
images, vector bezel primitives), it lands as a **U6-series** row against VectorTerminalSDK
with the same discipline, and the ANSI floor tier must keep working while it is outstanding.

| # | Phase | What | Pulled forward by |
|---|---|---|---|
| **U1** | Damage-Diff Repaint | `ANSIDriver.present()` redraws the full tree every frame (`ANSIDriver.swift:22, 262-273`). The `TerminalDriver` contract already says *"the driver owns diffing"* — implement it. Same for `SceneRenderer`'s v1 dirty-gating | T8.5, hard requirement by P3 |
| **U2** | Linux Driver | Platform floor is `.macOS("16.0")`, set by VectorTerminalSDK. Needs a Linux build, swift-corelibs-foundation audit, and VTG made optional so the floor can drop | The "anywhere Swift runs" answer; blocks L2 |
| **U3** | Windows Console Driver | No console driver exists. TermKit's `Drivers/WindowsDriver.swift` (in `SwiftTUIDE/Code/TermKit`) is the reference | Lowest priority of the three platforms |
| **U4** | Controls v3 | TUIKit Phase 11 is 0%; Phase 15 (code editor) 62% | T6 gaps, P3 |
| **U5** | Text Metrics & wcwidth | Grapheme clusters, CJK width, emoji, combining marks (**H3**). TermKit's `Core/WcWidth.swift` is prior art | T3.3 — blocks correct layout |
| **U6** | VTG Chrome Completion | TUIKit Phase 10 at 75% | T11.2 |

**Exit for Part U:** each phase is a landed TUIKit change with its own tests, cross-linked from `TERMINAL_PARITY.md`, and TUIKit's own dashboard moved in the same change.

---

## Part P — Proof Apps

Easiest → hardest, per Bobby. **Rev 2 and rev 3 are expected.** Ground rule 5 governs: what doesn't work must still run, just missing features.

| # | Phase | App | Gate |
|---|---|---|---|
| **P1** | ActiveUICounterDemo | 36 lines, one file, zero conditionals | Exit of T4. If this needs *one* edit to the demo, ground rule 2 is broken and T1 was wrong |
| **P2** | ActiveUITestApp | 25 files / 5,170 lines | Exit of T6. Every screen reachable; catalogued failures tracked like the iOS 23 |
| **P3** | ActiveUICatalog | 34 files, ~78 entries, **eight satellite packages** (Charts, Markdown, Code, Wizard, Web, Terminal, Boards, Diagram) | The honest end-state. Note `main.swift` calls `AUIApplication.run` at file scope — likely needs the closure form, as iOS C3.2 found. Per `catalog-is-part-of-done`, pages gain terminal bands |
| **P4** | A real app | FreebirdStudio, OmegaCLIDE, or VGTerm | The brutal one: something a person would actually choose to use over ssh |

Each phase ends with a **findings ledger** that must be empty or fully converted into rows in Part T or Part U.

---

## Part L — Terminal Last Mile

| # | Phase | What |
|---|---|---|
| **L1** | Capability Detection | Terminal matrix: Terminal.app, iTerm2, Kitty, Alacritty, WezTerm, VectorTerminal, Windows Terminal, plain xterm, `TERM=dumb`. Each gets a recorded capability profile and a screenshot. Degradation is *tested*, not assumed |
| **L2** | ssh / tmux / screen Pass | Latency, `TERM` mangling, mouse passthrough, OSC 52 through tmux (it needs `set-clipboard on`), 256-colour clamping, resize propagation through a multiplexer |
| **L3** | Distribution | A single static binary, no Xcode, no bundle. `AUIApplication.run` under a plain `main`. Ship instructions for "scp it to the box and run it" |

**Exit:** an ActiveUI app scp'd to a fresh Linux box runs over ssh inside tmux with mouse and colour, and degrades legibly under `TERM=dumb`.

---

## Cross-cutting principles

- **Every slice keeps the macOS suite green.** Not "at the end of the phase" — in the same commit. Ground rule 1.
- **Every control that lands updates `TERMINAL_PARITY.md` and its Catalog page in the same slice.** `catalog-is-part-of-done` and `new-controls-must-honour-css` both apply: CSS support is part of "done", not a finishing touch.
- **Copy WinChocolate's verification trick.** `Demo/ViewInfo` is a swift-syntax tool that dumps every view, every property set on it, and its actions from demo source, so a foreign build can be diffed control-by-control against the AppKit build of the *same* demo. That is what makes a parity table falsifiable. Build the terminal equivalent early — it is cheap and it is the difference between a real parity claim and an aspirational one.
- **Golden `CellBuffer` files beat screenshots.** Diffable, greppable, reviewable in a PR. This is the one place the terminal backend has better tests than the GUI one.
- **New ActiveUI source files break dependents** (`swiftpm-stale-source-list`) — `swift package reset` per dependent, and the error will blame the framework.
- **Never hand-edit generated project files**; no `.xcodeproj` is needed here, which is one small mercy.
- **Scope lint sweeps to `Sources/`/`Tests/`** — TUIKit and WinChocolate both carry large `.build/checkouts` trees.

---

## Open questions

- **H6 packaging** — traits vs. second target. **Resolved in T1.1**; everything waits on it.
- **Point→cell ratio** — 8×16 proposed. **Resolved in T1.4**, and it is a contract, not a constant.
- **Does the drawn tier win on the terminal, or do TUIKit's own controls?** TUIKit has 44 real controls; ActiveUI has 14 drawn ones. Using both is the worst answer. **Resolved in T5.6.**
- **Does `ChocolateKit` take the TUI backend, or does TermChocolate get its own core?** Strong preference for the former — it is why this plan is small. Confirmed by T1.2's error count.
- **Is `AUIApplication.run`'s file-scope form workable in a terminal**, or does the terminal need the closure form iOS needed? Likely the latter (`no-uikit-views-before-uiapplicationmain` has a terminal analogue: no views before the alt screen). **Resolved in T2.3.**
- **Async boundary.** TUIKit is `async`-shaped (`var size: Size { get async }`, `AsyncStream` input); ChocolateKit's backend protocol is synchronous and `@MainActor`. Reconciled on paper in T1.5, in code in T2.

---

## Manual test checklist

Run these by hand at the end of each iteration.

- [ ] `./buildandrun-term.sh` launches the harness in Terminal.app; the alt screen enters and exits cleanly
- [ ] Ctrl-C mid-run leaves the terminal usable — no raw mode, no hidden cursor, no colour bleed
- [ ] Resize the window: layout reflows, nothing overlaps, nothing is left painted at the old size
- [ ] Tab and Shift-Tab walk every focusable control in a sensible order; the focus indicator is visible
- [ ] Enter activates the focused control; Escape dismisses the frontmost panel
- [ ] Click a button with the mouse; scroll a list with the wheel
- [ ] The counter demo increments by mouse and by keyboard, and the source has zero `#if`
- [ ] Switch CSS themes; light and dark both look deliberate
- [ ] An image control shows a labelled band and opens Preview on Enter (or renders inline in iTerm2)
- [ ] Open an alert; confirm the screen beneath repaints correctly on dismiss
- [ ] Copy from the app; paste into another Mac app (OSC 52)
- [ ] Same app over ssh to a real remote host — usable, not just running
- [ ] Same app inside tmux — mouse and colour survive
- [ ] `TERM=dumb` — degrades legibly instead of crashing
- [ ] The macOS GUI build of the same app is byte-for-byte unaffected

---

## Verification

- **Compile gate:** `./buildcheck-term.sh` — proves no AppKit-only type leaked into the terminal path. Green here is a compile check only; it does not prove the terminal works.
- **Unit/golden:** `swift test` for ActiveUI (macOS, unchanged) plus golden `CellBuffer` files rendered through TUIKit's `HeadlessDriver`.
- **Smoke:** `swift run ActiveUITerminalSmoke` — the plain-executable runner, following `ActiveUIWindowsSmoke`'s precedent.
- **Canary:** T10.5 — break a bezel on purpose, prove the suite goes red, revert.
- **Human:** the checklist above, plus the terminal matrix in L1.

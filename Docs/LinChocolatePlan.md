# LinChocolate — Build Plan (Linux)

## Dashboard

```text
Overall Progress                            ██████████████████░░░░░░░░   69%  🔄 L4–L9 complete; L10 advancing; building L10–L13

── Foundations ───────────────────────────────────────────────
Phase L1  · Backend Strategy                ██████████████████████████  100%  ✅ GTK4 chosen & proven on dev loop
Phase L2  · Toolchain & Harness             ██████████████████████████  100%  ✅ Reproducible one-command Ring 1 loop
Phase L3  · Core Shell & First Control      ██████████████████████████  100%  ✅ Click-counter, AppKit coords, tests green
── AppKit surface (the "all of AppKit" work) ─────────────────
Phase L4  · Basic & Value Controls          ██████████████████████████  100%  ✅ Milestone met — all basic/value/choice controls, 17 types
Phase L5  · Text System                     ██████████████████████████  100%  ✅ NSTextView + attributed text + NSForm/NSMatrix — milestone met
Phase L6  · Layout Containers & Scrolling   ██████████████████████████  100%  ✅ Tab/box/split + full scroll stack (clip view, scrollers) — milestone met
Phase L7  · Tables, Lists, Collections      ██████████████████████████  100%  ✅ Table + outline + collection + NSBrowser + sorting/double-click — milestone met
Phase L8  · Images & Custom Drawing         ██████████████████████████  100%  ✅ NSImage + draw/NSBezierPath (arcs, rounded) + NSGradient (Cairo) — milestone met
Phase L9  · Menus & Toolbar                 ██████████████████████████  100%  ✅ Menu bar + key equivalents + toolbar (icons) + customization sheet — milestone met
Phase L10 · Dialogs & Panels                ███████████████████░░░░░░░   75%  🔄 NSAlert + panels + materials + NSPopover done; NSColorPanel / NSPanel remain
Phase L11 · Auto Layout                     ███████████████████░░░░░░░   75%  🔄 NSLayoutConstraint + anchors + solver done; intrinsic sizing / resize remain
Phase L12 · Appearance & Accessibility      ██████████░░░░░░░░░░░░░░░░   40%  🔄 Dark mode + materials + toolbar polish done; focus / AT-SPI remain
Phase L13 · Advanced Interaction            ████████░░░░░░░░░░░░░░░░░░   30%  🔄 Pasteboard + drag & drop done; printing / documents remain
── Verification & convergence ────────────────────────────────
Phase L14 · Linux VMs & Distribution        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Ring 2; packaging
Phase L15 · Three-Platform Proof            ████████████░░░░░░░░░░░░   50%  🔄 RealDemo (shared source) COMPILES+LINKS+RUNS on LinChocolate/GTK; AppKit shim + L15.3 remain
Phase L16 · Pi Cleanup                      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Ring 3; real Pi hardware
Phase L17 · Shared-Core Convergence         ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Deferred (post-WinChocolate-stable)
```

**Phases run serially:** each ends in the **Milestone** stated at its heading, and the next phase does not begin until that milestone is demonstrated. Progress bars reflect one active phase at a time. (L17 · Convergence is deferred on an external trigger — the normal Linux track runs L1→L16, with L17 slotting in once WinChocolate stabilizes.)

> **Scope note (2026-07-08):** the plan was expanded from 8 to 17 phases to reflect the real goal — *all* of AppKit, using WinChocolate's own phase breakdown as the reference. Overall % dropped (34%→15%) not because work was lost but because the denominator now honestly covers the full surface (text system, tables/collections, drawing, auto layout, accessibility, documents, …). The old monolithic "Control Parity Pass" is now Phases L4–L13.

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; 🚫 Blocked

---

## Summary

LinChocolate brings the same AppKit-shaped Swift API to Linux that WinChocolate brings to Windows: Apple API in, native Linux look out. Application sources stay byte-identical across macOS, Windows, and Linux via the single conditional-import idiom (`import AppKit` on Mac, `import WinChocolate` on Windows, `import LinChocolate` on Linux). Work starts **after the Windows framework is going** (roughly: WinChocolate Phases 3–8 mature); until then the later phases stay deliberately high-level and get detailed the way WinChocolate's did once work approached.

LinChocolate is a **sibling** to WinChocolate, not a sub-project: it starts as its own package that references WinChocolate's already-proven Apple-compatible API, and converges onto shared elements only once WinChocolate stabilizes (Phase L17). The defining environment change from the earlier draft of this plan: development and everyday testing now happen **on the Mac, using Docker + XQuartz** — a Linux container builds and runs honest Linux binaries, and their GUI windows display on the Mac desktop through XQuartz (X11). **Real Linux VMs and Raspberry Pi hardware** are the verification rings that catch what the container hides (Wayland, real GPU/RAM, packaging, aarch64 hardware quirks). This plan follows the AI-coding-rules plan format (`AICoding rules.md`) and is tracked separately from `ProjectPlan.md` — LinChocolate items never count toward WinChocolate percentages.

## Project Goals

1. **PRIMARY GOAL — Apple AppKit API compatibility**, identical to WinChocolate's: most Mac AppKit programs build and run (at least their UI) by swapping `import AppKit` for `import LinChocolate`. When any design decision conflicts with this goal, Apple API compatibility wins.
2. **Native Linux presentation — modern only.** Apps should look like modern Linux apps. Unlike WinChocolate there is **no classic/legacy look and no presentation switch**: the classic Win32 look on Windows exists for historical reasons, not as a pattern to replicate. LinChocolate ships one contemporary presentation; what exactly it follows (GNOME HIG? theme-following?) is a Phase L1 decision. The Apple-look toolbar exception carries over unchanged.
3. **Sibling now, shared core later.** LinChocolate starts as a **sibling package** alongside WinChocolate — its own package that mirrors WinChocolate's AppKit-shaped layout and uses it as a *reference implementation*, with only the backend behind `NativeControlBackend` written fresh for Linux. The Apple API surface is duplicated at first and synced by hand. **Once WinChocolate's API stabilizes**, the plan converges the two onto shared elements (Phase L17): the platform-neutral API, the `NativeControlBackend` protocol, the in-memory backend, the contract tests, and the composed controls get extracted into a common core both siblings consume. Every design decision keeps that seam narrow and platform-neutral so the later extraction is mechanical, not a rewrite.
4. **Raspberry Pi OS is a primary target.** LinChocolate must run well on Raspberry Pi hardware (aarch64, modest GPU/RAM), not just desktop distros — substrate and rendering choices are made with the Pi in mind.
5. **Mac + Docker + XQuartz is the preferred development loop; WSL on Windows is the secondary loop.** Day-to-day work happens on the Mac (preferred): Swift and the Linux GUI stack run inside a Linux Docker container, and GUI windows display on the Mac through XQuartz over X11. On Apple Silicon the container is **aarch64 Linux**, which matches the Pi's architecture — the fast loop and the primary hardware target share an ISA. **WSL2 on the Windows machine is a fully supported second inner loop** for when work is happening on Windows; it complements the Mac loop rather than replacing it — WSLg runs a real Wayland compositor (plus XWayland), so it exercises the Wayland path that XQuartz cannot. Everything must build and run in the container, but **nothing may only work there** (or only under WSL): real GPU behavior and packaging are still proven on the verification rings below.

## Hard constraints

- **No Qt.** Ruled out on licensing grounds (GPL/LGPL-with-strings or commercial); candidate substrates are GTK or a custom X11/Wayland + Cairo backend.
- **X11 and Wayland are both required.** Current Raspberry Pi OS (Bookworm, 2023+) defaults to **Wayland** (Wayfire, then labwc) on Pi 4/5, while older Pi models and older images still run X11 — so the backend must work on both. **XQuartz is an X11 server only**, so the Mac dev loop exercises the X11 path exclusively; Wayland is therefore verified on the real-Linux rings, never assumed from a green container run. The backend must not drift into being X11-only just because the daily loop is X11. A toolkit like GTK abstracts the two; a hand-rolled backend must not be Wayland-only or X11-only.
- **Architecture parity with the Pi.** Prefer aarch64 containers on Apple Silicon so the dev loop mirrors the Pi; also test x86-64 (emulated locally via Docker/QEMU, native on an x86-64 VM) so the framework is not accidentally aarch64-only.

## Standing constraints inherited from WinChocolate

- The `NativeControlBackend` protocol is the substitution point; LinChocolate must not require API-layer changes.
- The in-memory backend and contract tests are platform-neutral and must pass unchanged on Linux.
- The symbol-image glyph set (WinChocolate plan, item 12.2) is original, copyright-clean artwork designed to be reused here.

---

## Environments & Test Matrix

Three concentric rings, fastest first. Each ring exists to catch what the ring inside it cannot see.

| Ring | Where | Display path | Arch | Catches | Cadence |
|---|---|---|---|---|---|
| **1 · Inner loop (preferred)** | Mac + Docker (Linux container) + XQuartz | X11 → XQuartz | aarch64 (native on Apple Silicon); x86-64 emulated | Build breaks, contract-test regressions, X11 rendering/layout, event bridge | Every edit |
| **1b · Inner loop (Windows)** | WSL2 on the Windows machine + WSLg | Wayland **and** XWayland (WSLg) | x86-64 (or aarch64 on Arm Windows) | Same as Ring 1, **plus** an early Wayland read that XQuartz can't give | When working on Windows |
| **2 · Linux VMs** | x86-64 VM and aarch64 VM (UTM/QEMU on Mac, or cloud) | X11 **and** Wayland compositor | x86-64 + aarch64 | Wayland path, real display server, packaging, non-container filesystem/DPI | Per milestone / before merge |
| **3 · Raspberry Pi** | Raspberry Pi OS Bookworm on Pi 4/5 (and the minimum supported model) | Wayland (labwc/Wayfire) + X11 fallback | aarch64 | Real GPU/RAM limits, Pi compositor quirks, performance, first-run install | Per phase / before tagging a release |

Rules for the matrix:

- **Green in Ring 1 is necessary, not sufficient.** A feature that touches windowing, compositing, DPI, input, or packaging is not "done" until it has passed the ring that actually exercises that concern (Wayland ⇒ Ring 2+, GPU/perf ⇒ Ring 3).
- **XQuartz covers X11 only.** Never infer Wayland behavior from an XQuartz run. WSLg (Ring 1b) gives an early Wayland read, but real hardware (Rings 2–3) is still the arbiter for Wayland and DPI.
- **Keep the loop reproducible.** The container image, the XQuartz bridge, and the run scripts are checked in (Phase L2) so any machine reproduces Ring 1 identically.
- **Record ring results** the way WinChocolate records hardware caveats: real-hardware-only issues (keyboard modifiers, focus, DPI, compositor bugs) go in `NEEDS_HUMAN.md`.

---

## Demo Parity — Replicating the WinChocolate Demo

WinChocolate ships one comprehensive demo (`Demo/DemoApplication/main.swift`, ~3,400 lines) that exercises nearly the whole AppKit surface across tabbed pages, a toolbar, tables/outlines/collections/browsers, dialogs, and custom drawing. It does a good job, so it is LinChocolate's **yardstick**: `LinChocolateDemo` targets the same coverage, and the north star is that the *same* AppKit-shaped demo source builds and runs on Linux (Goal 1), diverging only where a control isn't ported yet.

This is a **cross-cutting deliverable, not a serial phase** (like the test matrix above): its rows are delivered across the AppKit-surface phases **L4–L13**, and the *unmodified* WinChocolate demo/apps running on Linux is the **L15** milestone. The current Controls-page `LinChocolateDemo` is the first slice — it maps 1:1 to the "basic + value controls" rows below.

| Demo area (WinChocolate) | Representative controls | LinChocolate status | Delivered by |
|---|---|---|---|
| App shell + window | `NSApplication`, `NSWindow` | ✅ done | L3 |
| Basic controls | `NSButton` (push/check/radio), `NSTextField`, `NSSecureTextField`, `NSComboBox`, `NSSearchField`, `NSTokenField` | ✅ all done | L4 |
| Value controls | `NSSlider`, `NSStepper`, `NSProgressIndicator`, `NSLevelIndicator`, `NSDatePicker`, `NSColorWell` | ✅ all six done | L4 |
| Choice controls | `NSPopUpButton`, `NSSegmentedControl` | ✅ both done | L4 |
| Multiline & structured text | `NSTextView`, `NSForm`, `NSMatrix`, `NSPathControl` | 🔄 `NSTextView` + `NSForm` + `NSMatrix` done (Text/Forms pages); `NSPathControl` remains | L5 |
| Layout containers | `NSTabView` (the page switcher), `NSSplitView`, `NSBox` | ✅ all three done — demo paged like WinChocolate's, with a Layout page | L6 |
| Scrolling | `NSScrollView`, `NSClipView`, `NSScroller` | ✅ all three done — clip-view offset, scroller knob/proportion, policy, `scroll(to:)`/`onScroll` (demo "Layout" page) | L6 |
| Tables / lists / collections | `NSTableView`, `NSOutlineView`, `NSBrowser`, `NSCollectionView` + data source / delegate / sort descriptors | ✅ all four + sort descriptors + double-click done (Table/Grid/Browser pages) | L7 |
| Images & custom drawing | `NSImageView`, `NSBezierPath`, `NSGraphicsContext` | ✅ all three + `NSView.draw(_:)` (arcs/gradients later) | L8 |
| Menu bar + Toolbar (**Apple-look exception**) | `NSMenu`/`NSMenuItem`, `NSToolbar`/`NSToolbarItem` + customization | ✅ menu bar + key equivalents + toolbar (icons) + customization sheet done | L9 |
| Dialogs & panels | `NSAlert`, `NSOpenPanel`/`NSSavePanel`, `NSColorPanel`, `NSPopover`, `NSPanel` | 🔄 alert + open/save panels + NSPopover done; NSColorPanel / NSPanel remain | L10 |
| Materials | `NSVisualEffectView` | ✅ theme-aware material surfaces (demo "Appearance" page); no real blur over non-composited XQuartz | L12 |
| Appearance / dark mode | `NSAppearance`, `NSApp.appearance`/`effectiveAppearance` | ✅ live light/dark toggle re-themes every control (demo "Appearance" page); per-view override + toolbar polish remain | L12 |
| Auto Layout | `NSLayoutConstraint`, layout anchors, `translatesAutoresizingMaskIntoConstraints` | 🔄 constraints + anchors + equality solver done (demo "Auto Layout" page); intrinsic sizing / inequalities / resize remain | L11 |
| Drag & drop | `NSDraggingSource`/`NSDraggingInfo`, `NSPasteboard` | 🔄 pasteboard copy/paste + drag source/destination done (demo "Drag & Drop" page); live GTK drag gesture needs manual XQuartz check | L13 |
| Printing | `NSPrintOperation` | ⏳ | L13 |
| Document architecture | `NSDocument`, `NSDocumentController` | ⏳ | L13 |

**Acceptance:** `LinChocolateDemo` reaches the WinChocolate demo's page/feature coverage (tracked by the rows above), and ultimately the *same* demo source compiles and runs on Linux via the conditional-import idiom — the concrete proof of Goal 1, demonstrated in Phase L15. Per-control detail lives in [`LinChocolateControlParity.md`](LinChocolateControlParity.md).

---

## Phase L1 — Backend Strategy ✅

**Milestone (met):** GTK4 chosen as the substrate and *proven runnable from Swift on the Ring 1 dev loop* — a GTK4 window renders over XQuartz.

| # | Item | Status | Notes |
|---|---|---|---|
| L1.1 | Native substrate choice | ✅ Done | **GTK 4 via Swift C-interop, Cairo renderer for the XQuartz loop** — see [LinChocolateSubstrate.md](LinChocolateSubstrate.md). Only candidate delivering a native, modern, theme-following look (Goal 2) with Wayland+X11, HiDPI, IME, and AT-SPI already solved; the Pi's own toolkit; Swift↔GTK4 binding path real and Swift.org-endorsed. Validated by **S1** (compiles), **S2** (renders over XQuartz), **S4** (seam swappable). GTK3 is the documented fallback; custom X11/Wayland+Cairo rejected. Pi confirmation (**S3**) is the Phase L16 gate, not a blocker on the decision. |
| L1.2 | Target look baseline | ✅ Decided | Baseline is **plain GTK4 (follows the active system theme)** — right for the Pi's PIXEL desktop; libadwaita optional where a polished GNOME look is wanted. The plain-vs-libadwaita call is refined in L4 with a Pi in hand (substrate doc §5). |

## Phase L2 — Toolchain & Harness ✅

**Milestone (met):** a reproducible, checked-in **one-command Ring 1 loop** (`./run-linux.sh`) that builds the container and shows a native window on the Mac, with the sibling package building against real Foundation.

| # | Item | Status | Notes |
|---|---|---|---|
| L2.1 | Swift toolchain pin | ✅ Done | `swift:6.0-noble` pinned in the image (GTK 4.14.5; aarch64 on Apple Silicon, `SWIFT_TAG` build-arg for x86-64); GTK4 C-interop builds cleanly. Re-confirmed on the VMs in L5 and the Pi in L8. |
| L2.2 | Docker dev image | ✅ Done | `LinChocolate/Dockerfile` — `swift:6.0-noble` + `libgtk-4-dev` + `dbus-x11`, aarch64 to match the Pi. Image builds; `swift build` green (**S1**). |
| L2.3 | XQuartz display bridge | ✅ Done | `LinChocolate/run-linux.sh` auto-enables XQuartz TCP, restarts it, `xhost +`, dials `DISPLAY=<en0-IP>:0`, `GSK_RENDERER=cairo`. Window renders on the Mac (**S2**). (Ring 1b WSLg loop doc → L5.) |
| L2.4 | Real Foundation | ✅ Confirmed | corelibs Foundation works on Linux out of the box — `NSRect`/`NSPoint`/`NSMakeRect`/`CGFloat` used directly, no WinFoundation-style shim needed. `USE_REAL_FOUNDATION` is simply the default here. |
| L2.5 | Sibling package layout | ✅ Done | `LinChocolate/` stood up as its own package (nested for now; graduates to a true sibling dir at convergence) mirroring WinChocolate: AppKit-shaped `LinChocolate` target + GTK/in-memory backends + demo + contract tests. `NativeControlBackend` seam mirrors WinChocolate's shape for L7. WinChocolate untouched. |

## Phase L3 — Core Shell & First Control ✅

**Milestone (met):** the AppKit-shaped **click-counter runs as native GTK controls with green contract tests** — `NSApplication`/`NSWindow`/`NSButton`/`NSTextField` driving GTK through the `NativeControlBackend` seam, with frames matching AppKit's bottom-left coordinate model. Demo renders over XQuartz; 17 contract tests green.

| # | Item | Status | Notes |
|---|---|---|---|
| L3.1 | Application shell | ✅ Done | `NSApplication`/`NSWindow` over GTK4 (`GMainLoop` lifecycle, window create/show, close→terminate); renders over XQuartz and quits cleanly. |
| L3.2 | Backend seam + first controls | ✅ Done | `NativeControlBackend` + GTK and in-memory backends; `NSView` (GtkFixed), `NSButton` (GtkButton), `NSTextField` label (GtkLabel); event bridge `registerAction` → GTK `clicked`. Click-counter demo works. |
| L3.3 | Contract tests | ✅ Done | `LinChocolateContractTests` 13/13 green (in-memory backend), including the full API→backend click path (**S4**). |
| L3.4 | AppKit coordinate model | ✅ Done | `CoordinateSpace.gtkY` (pure, unit-tested) flips AppKit bottom-left → GTK top-left in `addSubview`/`setFrame`; `NSView.frame` setter repositions live, `NSWindow.setContentSize` resizes. Demo now lays out button-above-label as AppKit intends. 4 coordinate tests added (17 total green). |

## Phase L4 — Basic & Value Controls 🔄 (ACTIVE)

**Milestone:** the everyday control set renders and is event-wired — buttons (push / checkbox / radio), the text-field family (label / editable / secure / search / combo / token), and the value & choice controls (slider, stepper, progress, level indicator, date picker, color well, pop-up, segmented) — enough for the demo's basic Controls pages.

| # | Item | Status | Notes |
|---|---|---|---|
| L4.1 | Core control set | ✅ Done | Seven types over GTK4, event-wired: label + editable `NSTextField` (GtkLabel/GtkEntry), push/checkbox/radio `NSButton` (GtkButton/GtkCheckButton, radios grouped), `NSSlider` (GtkScale), `NSProgressIndicator` (GtkProgressBar), `NSPopUpButton` (GtkDropDown). Controls page demo — **XQuartz-verified**, **32 contract tests green**. |
| L4.2 | Remaining text inputs | 🔄 Mostly done | ✅ `NSSecureTextField` (GtkPasswordEntry), ✅ `NSSearchField` (GtkSearchEntry), ✅ `NSComboBox` (GtkComboBoxText w/ entry — editable, deprecated GTK peer but the direct analog); each event-wired, 38 contract tests green. **Remaining:** `NSTokenField` (needs a composite; no clean GTK peer). |
| L4.3 | Remaining value controls | ⏳ Pending | `NSStepper` (GtkSpinButton), `NSDatePicker` (GtkCalendar), `NSLevelIndicator`, `NSColorWell` (GtkColorButton). |
| L4.4 | `NSSegmentedControl` | ⏳ Pending | Composed from linked GtkToggleButtons. |
| L4.5 | Parity matrix upkeep | 🔄 Ongoing | Keep [LinChocolateControlParity.md](LinChocolateControlParity.md) current as controls land (also records the opaque-vs-nominal GTK import finding). |

## Phase L5 — Text System ✅

**Milestone (met):** multiline rich text works — `NSTextView` editing inside a scroll view, `NSAttributedString` styling with `NSFont`/`NSColor`, plus the `NSForm`/`NSMatrix` composed layouts the demo uses.

| # | Item | Status | Notes |
|---|---|---|---|
| L5.1 | `NSTextView` | ✅ Done | Multiline editing over `GtkTextView`; buffer-backed `string`/`onTextChange`, `NSFont`. |
| L5.2 | Attributed text | ✅ Done | Foundation `NSAttributedString` + AppKit `.foregroundColor`/`.font` keys → Pango markup on `NSTextField.attributedStringValue`. |
| L5.3 | `NSForm` / `NSMatrix` | ✅ Done | Composed controls (no GTK peer): `NSForm` stacks `NSTextField` label+field rows (`titleWidth`, `addEntry`, `textField(at:)`, `setStringValue(at:)`); `NSMatrix` is a rows×columns `NSButton` grid (`NSButtonCell` prototype, `cellSize`/`intercellSpacing`, `selectCell(atRow:column:)`, `selectedRow`/`Column`, `onAction`). Verified live over GTK (demo "Forms" page) + contract tests. Legacy grid chrome dropped for native fields/buttons (Goal 2). |
| L5.4 | `NSPathControl` | ⏳ Later | A path-component breadcrumb (over `GtkBox` of buttons + `GFile`). Not a milestone gate — the demo doesn't require it — but tracked here for full demo-parity. |

## Phase L6 — Layout Containers & Scrolling ✅

**Milestone (met):** the demo's page switcher and split panes work — `NSTabView`, `NSSplitView`, `NSBox`, and the `NSScrollView`/`NSClipView`/`NSScroller` stack.

| # | Item | Status | Notes |
|---|---|---|---|
| L6.1 | `NSTabView` | ✅ Done | Page switcher over `GtkNotebook`; `addTabViewItem`, `selectTabViewItem(at:)`, `onSelectionChange`. |
| L6.2 | `NSSplitView` / `NSBox` | ✅ Done | `GtkPaned` panes (`addArrangedSubview`, `setPosition`); `GtkFrame` group boxes (`contentView`). Pane resize behavior pinned so the divider honors `setPosition` (leading pane fixed at the position, trailing pane fills the rest and won't shrink below its content) — the GtkPaned default otherwise let the leading pane grow to its natural width, squeezing the trailing pane so its box was clipped on the right (reported + fixed). |
| L6.3 | Scrolling stack | ✅ Done | `NSScrollView` gains `contentView` (`NSClipView`), `verticalScroller`/`horizontalScroller` (`NSScroller`), `hasVertical/HorizontalScroller` policy, `documentVisibleRect`, `scroll(to:)`, `scrollToEndOfDocument`/`scrollToBeginningOfDocument` (clamped so the document end aligns to the viewport bottom), and `onScroll`. `NSClipView.bounds.origin` is the scroll offset (flipped clip, y grows down); `NSScroller.doubleValue`/`knobProportion`/`isVisible` derive from the geometry. Over `GtkScrolledWindow` via its `GtkAdjustment`s (offset = value, document = upper, viewport = page-size; `value-changed` → `onScroll`), clamped to range. Verified live over GTK (demo "Layout" page "Scroll to bottom" → offset (0, 400)) + contract tests. Scrollbars reserve a permanent gutter (`gtk_scrolled_window_set_overlay_scrolling(false)`) like AppKit's legacy scrollers — GTK's overlay scrollbar otherwise floats over the right edge and, on non-composited XQuartz, draws as an opaque strip clipping content instead of the viewport resizing (reported + fixed). |

## Phase L7 — Tables, Lists, Collections ✅

**Milestone (met):** data-driven views work — `NSTableView`, `NSOutlineView`, `NSBrowser`, and `NSCollectionView` with data source/delegate, selection, and sort descriptors (mirrors WinChocolate Phase 5).

| # | Item | Status | Notes |
|---|---|---|---|
| L7.1 | `NSTableView` | ✅ Done | `NSTableColumn` + data source over `GtkColumnView`; count-only model + Swift cell provider; single-selection. |
| L7.2 | `NSOutlineView` / `NSBrowser` | ✅ Done | Outline via `GtkColumnView`+`GtkTreeListModel`+`GtkTreeExpander` (dot-path items). `NSBrowser` is a **composed** Miller-column navigator — a fixed row of single-column `NSTableView`s driven by an item-based `NSBrowserDelegate` + a selection path; deeper columns auto-title with the selected parent; `path()`, `selectRow(_:inColumn:)`. No backend surface of its own. |
| L7.3 | `NSCollectionView` | ✅ Done | Grid over `GtkGridView`; count-only model + tile provider; single-selection. |
| L7.4 | Selection & sorting | ✅ Done | `NSSortDescriptor` (LinChocolate's own — Foundation's Linux one dropped `key:`) + `NSTableColumn.sortDescriptorPrototype`; a sortable column gets a clickable GTK header (no-op `GtkCustomSorter` + `GtkColumnViewSorter::changed`) that delivers the descriptor to `dataSource.tableView(_:sortDescriptorsDidChange:)`, which re-sorts and reloads; the header shows the ▲/▼ indicator. Double-click / Enter → `NSTableView.onDoubleClick` via `GtkColumnView::activate`. **Verified live over GTK** (demo "Table" sort + double-click; "Browser" navigation) + contract tests. |

## Phase L8 — Images & Custom Drawing ✅ (LinCoreGraphics)

**Milestone (met):** bitmaps display and custom drawing works — `NSImageView`/`NSImage`, plus a Core-Graphics-shaped drawing layer (`NSBezierPath`, `NSGraphicsContext`, `NSGradient`, `NSColor`) over Cairo so `draw(_:)`-style views render (the Linux peer of WinChocolate's WinCoreGraphics).

| # | Item | Status | Notes |
|---|---|---|---|
| L8.1 | `NSImageView` / `NSImage` | ✅ Done | File-backed image via `GtkPicture`; aspect-fit. |
| L8.2 | LinCoreGraphics | ✅ Done | `NSBezierPath` (rect/oval/move/line/curve/**arc**/**roundedRect**, fill/stroke), `NSGraphicsContext`, `NSColor` fill/stroke, and **`NSGradient`** (linear at angle, path-clipped via save/clip/restore, radial) over Cairo patterns. Arc direction handles the y-flipped context (default CCW → `cairo_arc`, so a full 0…2π sweep stays a full circle). **Verified live** (demo Drawing tab: gradient-filled capsule + circle) + contract tests. |
| L8.3 | Custom view drawing | ✅ Done | `NSView.draw(_:)` over `GtkDrawingArea` inside the `GtkOverlay`, flipped to AppKit bottom-left. |

## Phase L9 — Menus & Toolbar ✅

**Milestone (met):** the app menu bar and the Apple-look toolbar work — `NSMenu`/`NSMenuItem` with key equivalents, and `NSToolbar`/`NSToolbarItem` (the deliberate Apple-look exception, Goal 2) with icons and the customization sheet (mirrors WinChocolate Phase 6).

| # | Item | Status | Notes |
|---|---|---|---|
| L9.1 | Menu bar | ✅ Done | `NSApp.mainMenu` of `NSMenu`/`NSMenuItem` (separators, closures) → `GMenu` model + window-scoped `GSimpleAction`s + `GtkPopoverMenuBar` packed above the content view. **Key equivalents**: `NSMenuItem.keyEquivalent`/`keyEquivalentModifierMask` (Command→Control on Linux) become `GtkShortcut`s on a window `GtkShortcutController` (+ the `accel` display attribute). Verified live: Ctrl+R fired File ▸ Reset Counter (Clicks 3 → "0 (reset)") headlessly, 0 CRITICALs. |
| L9.2 | `NSToolbar` | ✅ Done | Apple-look composed strip (light gradient, hairline, flat hover buttons) — the one deliberate non-native control; docks under the menu bar via `NSWindow.toolbar`. Items carry `NSImage(named:)` **icons** rendered above their labels (GTK theme icons, macOS layout). |
| L9.3 | Customization | ✅ Done | `NSToolbarDelegate` (allowed/default identifiers + `itemForItemIdentifier`), `allowsUserCustomization`, `insertItem`/`removeItem`, and `runCustomizationPalette(_:)` → a composed sheet with a toggle per allowed item (checked = present); toggling adds/removes items live. Verified: the palette renders (Open/Save/Info/Customize/Flexible Space) and toggles update the toolbar; contract-tested end-to-end via `simulate*` hooks. |

## Phase L10 — Dialogs & Panels ⏳

**Milestone:** standard dialogs work — `NSAlert`, open/save panels, color panel, popover, `NSPanel` subclasses, and `NSVisualEffectView` materials.

| # | Item | Status | Notes |
|---|---|---|---|
| L10.1 | `NSAlert` | ✅ Done | Composed modal `GtkWindow` + nested `GMainLoop` (GTK4 has no blocking dialogs); `runModal()` returns the button index. |
| L10.2 | Open/Save panels | ✅ Done | `NSOpenPanel`/`NSSavePanel` over `GtkFileDialog` (async → nested loop). |
| L10.3 | Color panel | 🔄 `NSColorWell` done | `NSColorWell` over `GtkColorButton`; the shared `NSColorPanel` remains. |
| L10.4 | Popover & panels | 🔄 Popover done | **`NSPopover`** (+ minimal `NSViewController`) over `GtkPopover`: `contentViewController`, `contentSize`, `behavior`, `show(relativeTo:of:preferredEdge:)`/`performClose`, `NSRectEdge`, AppKit-rect → GTK pointing flip, non-composited flatten + outside-click dismissal. Builds clean, 0 CRITICALs, contract-tested; live visual needs XQuartz (like menus, GtkPopover doesn't render on headless Xvfb). `NSPanel` (needs opening up `NSWindow`) remains. |
| L10.5 | Materials | ✅ Done | `NSVisualEffectView` theme-derived material surface (see L12.2). |

## Phase L11 — Auto Layout 🔄

**Milestone:** AppKit Auto Layout works — `NSLayoutConstraint`, layout anchors, intrinsic content size, priorities, hugging/compression resistance, and `translatesAutoresizingMaskIntoConstraints` — so apps aren't limited to manual frames (mirrors WinChocolate Phase 9).

| # | Item | Status | Notes |
|---|---|---|---|
| L11.1 | Constraints & anchors | ✅ Done | `NSLayoutConstraint` (item/attr/relation/multiplier/constant/priority) + X/Y/Dimension anchors (`leadingAnchor`, `widthAnchor`, …) + `activate`/`deactivate`. |
| L11.2 | Constraint solver | ✅ Done | `LayoutSolver`: equality constraints → linear system → Gaussian elimination (RREF); free dims fall back to current frame; multiplier + sibling chains verified. Inequalities/priority tie-breaking still pending. |
| L11.3 | Backend integration | ✅ Done | `layoutSubtreeIfNeeded()` solves and writes child frames through the existing `setFrame` seam (backend-agnostic — works on GTK **and** in-memory). Window presentation runs an initial pass. Live resize re-layout still pending. |
| L11.4 | Intrinsic sizing | ⏳ Pending | Intrinsic content size, content hugging, compression resistance, priority-weighted solving. |

**Verified:** contract tests (leading/center/trailing row → exact frames, `width = 0.5·container` multiplier → 243, sibling chain `v2.leading = v1.trailing + 10` → 130) all green; live GTK render of the Auto Layout demo tab shows three `.zero`-initialized boxes placed and sized entirely by constraints.

## Phase L12 — Appearance & Accessibility 🔄

**Milestone:** the app looks native and is accessible — dark mode / theme-following (finalizing the plain-GTK4-vs-libadwaita baseline), the full `NSResponder` key-view focus loop, and AT-SPI accessibility (mirrors WinChocolate Phase 10).

| # | Item | Status | Notes |
|---|---|---|---|
| L12.1 | Appearance & dark mode | ✅ Done | `NSAppearance` (`.aqua`/`.darkAqua`/vibrant, `isDark`), `NSApp.appearance` / `effectiveAppearance`, `NSView.effectiveAppearance`. Setting the app appearance flips GTK's `gtk-application-prefer-dark-theme` (via GValue — no C-variadic `g_object_set`), re-theming every existing control live. **Verified** by light/dark screenshots of a demo toggle. Per-view appearance overrides + finalizing plain-GTK4-vs-libadwaita remain. |
| L12.2 | Materials (`NSVisualEffectView`) | ✅ Done | Material backdrop (`.sidebar`/`.contentBackground`/`.hudWindow`/…) as a theme-derived tinted surface (`shade(@theme_bg_color,…)`, `alpha(@theme_fg_color,…)`) that tracks the appearance; no real blur over non-composited XQuartz. It's a full `NSView` (hosts subviews / draws). |
| L12.3 | Toolbar dark-mode polish | ✅ Done | The Apple-look toolbar strip now uses theme-named colors (`shade(@theme_bg_color,…)` gradient, `alpha(@theme_fg_color,…)` hairline + hover), so it darkens with the app and its Open/Save/Info labels stay readable. Verified light+dark on XQuartz. |
| L12.4 | Responder & focus | ⏳ Pending | `NSResponder` chain, first responder, `nextKeyView` loop, focus-ring visibility. |
| L12.5 | Accessibility | ⏳ Pending | Roles / states / keyboard model via `GtkAccessible` / AT-SPI. |

## Phase L13 — Advanced Interaction 🔄

**Milestone:** drag & drop, printing, and the document architecture work — `NSDraggingSource`/`NSDraggingInfo` + `NSPasteboard`, `NSPrintOperation`, and `NSDocument`/`NSDocumentController`.

| # | Item | Status | Notes |
|---|---|---|---|
| L13.1 | Pasteboard | ✅ Done | `NSPasteboard` (general + transient, `PasteboardType`, `clearContents`/`changeCount`, `setString`/`string(forType:)`). General board pushes text to `GdkClipboard`. Copy/paste **verified live over GTK** (demo "Drag & Drop" page). Inbound cross-app paste (async clipboard read) remains. |
| L13.2 | Drag & drop | 🔄 Mostly done | `NSView.registerForDraggedTypes` + `onDraggingEntered`/`onPerformDragOperation`, `NSDraggingInfo`, `NSDragOperation`; drag sources via `registerDraggingSource`. Backed by `GtkDropTarget`/`GtkDragSource` (string content via `GdkContentProvider`), drop point flipped to AppKit coords. Data path **verified by contract tests** (source→destination, entered-mask, `.none` rejection) via in-memory `simulateDrop`/`simulateDragAndDrop`. The live GTK drag *gesture* needs manual XQuartz confirmation — synthetic Xvfb XTEST drags don't reliably trip GTK4's drag threshold. Multi-type / file-URL / image payloads remain. |
| L13.3 | Printing | ⏳ Pending | `NSPrintOperation` → `GtkPrintOperation`. |
| L13.4 | Documents | ⏳ Pending | `NSDocument`/`NSDocumentController` open / save / dirty lifecycle. |

## Phase L14 — Linux VMs & Distribution ⏳

**Milestone:** the demo **runs on x86-64 + aarch64 Linux VMs (X11 and Wayland)** — Ring 2 stood up, the Wayland path proven (XQuartz cannot), and the distribution/packaging shape decided. *(Raspberry Pi hardware is its own focused phase — L16.)*

| # | Item | Status | Notes |
|---|---|---|---|
| L14.1 | Linux VM ring (Ring 2) | ⏳ Pending | x86-64 + aarch64 VMs with both an X11 and a Wayland session; the demo runs on each. Wayland path proven (XQuartz cannot). |
| L14.2 | Distribution shape | ⏳ Pending | SwiftPM-only vs distro packaging; minimum supported distros/desktops. Pi OS primary; mainstream x86-64 distros follow. |
| L14.3 | WSLg secondary loop | ⏳ Pending | Document the Ring 1b WSLg loop so the demo runs on the Windows machine over Wayland/XWayland. |
| L14.4 | CI | ⏳ Pending | Wire the container ring (build + contract tests) into CI; define the periodic verification cadence. |

## Phase L15 — Three-Platform Proof 🔄

**Milestone:** the **WinChocolate demo and Phase 11 apps build and run unmodified on macOS, Windows, and Linux** (the concrete proof of Goal 1 — see the Demo Parity section), verified through all rings, with Linux-only gaps logged back into this plan.

**Pipeline (done):** the shared demo (`Demo/DemoApplication/main.swift`) now selects the library with a tri-target conditional import (LinChocolate / WinChocolate / real AppKit); a `RealDemo` target in `LinChocolate/Package.swift` builds that same source (symlinked) against LinChocolate; LinChocolate re-exports Foundation (`FoundationBridge.swift`) as WinChocolate re-exports WinFoundation.

**✅ LinChocolate compile taken to ZERO (2026-07-12).** The shared WinChocolate demo compiles, links, and runs against LinChocolate/GTK4 — `.build/…/debug/RealDemo` launches under Xvfb and renders the full window (toolbar, token field, text view, alert-style buttons, matrix, form, action-button row, status bands). Trajectory: 2,555 → 0 errors. Reaching zero drove out a large, real AppKit-parity convenience surface (frame-only `init(frame:)` on stepper/combo/search/level/progress/text views; `onAction`/`onTextChanged` aliases; `NSGridView`/`NSGridColumn` placement; `NSClipView`/`NSScroller` promoted to standalone `NSView` subclasses; `NSTextStorage`, `NSAlert.Style`/`init(error:)`, modal-response `Int` statics, extended toolbar identifiers, `NSAttributedString.Key` set, `NSFont(name:size:weight:italic:)`, etc.).

**One genuine Foundation divergence, resolved in-source:** real Foundation types `Timer.scheduledTimer` and `NotificationCenter.addObserver` blocks `@Sendable`, so they can't touch the demo's main-actor UI globals; WinFoundation's blocks are not `@Sendable`. Extension overloads can't win resolution against Foundation's primary declarations, so the shared demo now hops to the main actor for the two affected callbacks under `#if !canImport(WinChocolate)` (LinChocolate + AppKit path) via `Task { @MainActor in … }`, leaving the WinChocolate path byte-for-byte synchronous. Logged in [AppKitCompatibilityDivergences.md](AppKitCompatibilityDivergences.md).

**✅ NIB / xib loading ported (2026-07-14).** A develop merge added a **Nib (15)** demo page that instantiates `DemoNibPanel.xib` at runtime through `NSNib`. Ported WinChocolate's whole nib stack to LinChocolate so the shared demo compiles + runs: `Nib/NibXML.swift` (dependency-free recursive-descent xib XML parser, verbatim port), `Nib/NSNib.swift` (`NSNib` + `winInstantiate` → `NibInstance` with `topLevelObjects`/`objectsByID`/`connections`/`view(withIdentifier:)`, plus `NibConnection` `.action`/`.outlet` records and `NibCustomObject`), and `Nib/NibDecoder.swift` (builds the control graph, y-flipping xib bottom-up frames to top-left, resolving `<outlet>`/`<action>` connections and applying `target`/`action`). Added the supporting real-AppKit surface LinChocolate lacked: a `Selector` value type (`Runtime/Selector.swift`), `NSButton.action`/`.target`, frame-only `NSButton`/`NSTextField` inits, `NSSlider.isContinuous`. `run-linux.sh` now stages the demo `Resources/` (artwork + xib) next to the built binary. **Verified:** the Nib page renders the xib-loaded panel (title, field, Increment button + count, checkbox, Show-Outlet-Values, slider, Cocoa popup, box) at correct positions, and reports "11 identified objects, 2 action connections (increment:, showValues:), 5 outlets on File's Owner" — matching WinChocolate. Contract tests pass; other pages unregressed.

**macOS/AppKit build harness (2026-07-14).** Added `run-mac.sh` at the repo root — builds the shared demo against the real macOS AppKit SDK (`swiftc` over `Demo/DemoApplication/*.swift` + `Demo/AppKitCompat.swift`), wraps it in a `WinChocolateDemo.app` bundle (Info.plist + nested `Resources/Resources` matching the demo's `Bundle.main` loader), and launches it via `open` (flags `--dark`/`--light`/`--page N`/`--stress`/`--test`/`--build`/`--clean` pass through). Harness verified end-to-end. **The AppKit build itself is the remaining L15.1 work: 748 shim errors** — the macOS shims (`Demo/AppKitCompat.swift` + `PlatformShims.swift`) must re-express the demo's conveniences over Apple's types. Top categories mirror the LinChocolate surface (`NSView.backgroundColor`, `onAction` on menu/controls, `winIsDark`, `NSToolbar.addItem`, `NSForm.textField`, frame inits) **plus the two genuine hard divergences that can't be shimmed** (`NSToolbarItem.Identifier`-as-struct → 42 `String`-conversion errors; get-only `previousKeyView` → 66) — these need the framework+demo fixes tracked in L15.3 / the divergences doc.

**✅ Menu + toolbar navigation working (2026-07-12).** You can now page through the whole demo on Linux two ways: the toolbar's **page-selector pop-up** ("Controls / Values / Tables·Media / Drawing / New in 3.x / Lists / Bezels / Auto Layout") and the **View menu** (Ctrl+1…8). Fixes:
- **Toolbar item duplication** — the demo both sets a `delegate` (which auto-loads defaults) and calls `addItem` explicitly; the first explicit `addItem` now clears the delegate-loaded set (`NSToolbar.itemsAreDelegateLoaded`), so items appear once, not twice.
- **View-based toolbar items** — `NSToolbarItem.view` (page pop-up, search field) now renders the real control widget in the GTK toolbar strip (via `NativeToolbarItemSpec.viewHandle` + widget reparenting that survives toolbar rebuilds) instead of a dead label.
- **Dynamic pop-up items** — `NSPopUpButton.addItems(withTitles:)`/`removeAllItems`/`selectItem` were no-op stubs; now backed by a real `setPopUpItems` that rebuilds the `GtkDropDown` model (the page selector + alert-style pop-up were showing "(None)").
- **Menu bar not showing** — the demo attaches submenus via `menuItem.submenu = …`, but `menuBarSpecs()` only read the parent's `setSubmenu` map; it now honors `item.submenu`, so the **WinChocolate / Edit / View** bar renders.

**✅ Coordinate-origin flip fixed (2026-07-12).** The whole demo was rendering vertically mirrored (Clicks at the bottom, Tokens at the top). Root cause: a genuine WinChocolate-vs-AppKit divergence. The **native `LinChocolateDemo` is authored bottom-left** (AppKit-faithful, +Y up), but the **shared WinChocolate demo is authored top-left** (Win32/WinChocolate use a top-left origin). LinChocolate was flipping *everything* to bottom-left. Fix: added AppKit's `NSView.isFlipped` (with an app-wide `NSView.defaultIsFlipped`); the backend only applies the bottom-left flip when the parent view is **not** flipped (`GTKNativeControlBackend.flippedViews` / `setViewFlipped`). `RealDemo` sets `NSView.defaultIsFlipped = true` in its `#if canImport(LinChocolate)` block so its top-left coordinates match WinChocolate; `LinChocolateDemo` keeps the bottom-left default (verified unchanged). Composite controls that lay out their own children (`NSForm`, `NSMatrix`) now branch on `isFlipped` too. This also makes the shared source render correctly on **real AppKit** (isFlipped=true → top-left there as well).

**✅ Custom drawing no longer upside-down (2026-07-12).** The `GtkDrawingArea` draw func unconditionally flipped the Cairo context into AppKit's bottom-left space, so the top-left-authored WinChocolate demo drew inverted. Now the draw flip honors the drawing view's own `isFlipped` (each view's flag is registered in `flippedViews` when added): a flipped view draws in GTK's native top-left space directly; an unflipped AppKit view still gets the axis flip. Arc winding (`CairoGraphicsContext(flipped:)`) is chosen to match the coordinate space. Verified: the Drawing page's canvas + path shapes (X, circle, star, curve, gradients) render right-side-up matching WinChocolate.

**✅ Widget sizing quirks fixed (2026-07-12).** Ordering/orientation is correct across pages; this pass fixed the controls that were mis-sized:
- **`NSLevelIndicator` overflow** — `GtkLevelBar`'s natural width is unbounded and `GtkFixed` honors natural size (it can't be size-capped there). Now rendered as a `GtkProgressBar`, which respects `size_request` exactly and shows the same value/max fill fraction.
- **Vertical `NSSlider`** — `isVertical` was a compat no-op; it's now a real property that reorients the `GtkScale` (`setSliderVertical` → `gtk_orientable_set_orientation` + inverted range so min sits at the bottom, matching AppKit).
- **Oversized date picker** — `NSDatePicker` always built a full `GtkCalendar`, so the default `.textFieldAndStepper` picker (a compact 184×28 field) rendered a giant month grid that overflowed. Now the default style is a compact read-only entry showing the formatted date; `.clockAndCalendar` swaps in a `GtkCalendar` (`setDatePickerGraphical` recreates the widget in place before it's parented). The Tables/Media page overlaps were already resolved by the coordinate-flip fix (it now matches the WinChocolate reference).

**✅ Controls-page control types fixed (2026-07-12).** The demo builds several controls as plain `NSButton(title:)` then calls `setButtonType(_:)`, which was a compat no-op — so a checkbox and three radios rendered as push buttons, and the alert-style pop-up (given 96px of menu height) rendered as a giant dropdown overflowing its box. Fixes:
- **`setButtonType`** is now real: it recreates the native control as a `GtkCheckButton` (checkbox) or radio and re-wires the toggle (`setButtonKind` recreates the widget in place, before it's parented). Radios **auto-group by superview** in `addSubview` (mirroring AppKit, which groups radios sharing a superview), so they render round and are mutually exclusive. "Show count in title" is now a checkbox; Info/Warning/Critical are radios with Info selected.
- **Pop-up height** — `NSPopUpButton` (GtkDropDown) fills its requested height; it now uses its natural control height and top-aligns, so the alert-style pop-up sits normally inside its box (matching AppKit/WinChocolate).

**✅ Control density tightened (2026-07-12).** GTK's Adwaita theme floors controls at ~34px `min-height`, so fields the demo sized at 24px still rendered chunky and taller than their Win32 counterparts. A display-wide compact-control CSS provider (`installCompactControlStyle`, priority 590 so per-widget/toolbar rules still win) drops the theme `min-height` and trims padding on buttons/entries/dropdowns/spinbuttons/checkbuttons/scales/etc., so each control honors its requested frame height and reads at a density comparable to Win32/macOS. Verified across Controls + Values pages (the calendar also packs tighter now).

**✅ Labels no longer render as fields (2026-07-12).** Every `NSTextField(string:)` was a bordered `GtkEntry`, so labels ("Slider:", "Tokens:", "Clicks: 0", …) showed field boxes. WinChocolate keys the box off `isEditable` (Win32 `EDIT` vs `STATIC`), not `isBordered` — a non-editable field is a borderless static label. Matched it: `NSTextField.isEditable` now defaults to `false` and is a real property; a non-editable field is a frameless, transparent, read-only entry (a `.linchocolate-label` CSS class strips the chrome), and `isEditable = true` turns it into a framed field (`setTextEditable`). `NSForm` entries are marked editable (framed); the two editable `NSTextField(string:)` fields in the native `LinChocolateDemo` were updated to set `isEditable = true` (it had relied on LinChocolate's old editable-by-default, which diverged from WinChocolate). Verified: labels are now plain text, editable fields (Type here/Password/Name/Status/Price) keep their boxes.

**✅ Develop merge repaired + CG surface ported; both new pages run (2026-07-13).** The `675141c` merge of develop had resolved the shared demo's conflict to ours wholesale, silently dropping develop's two new pages. Repaired by taking develop's demo (10 pages) and re-applying the four Linux edit sites (tri-target import header, GTK-backend + `defaultIsFlipped` block, Timer hop, `applyLiveAppearanceRefresh`). The new **CoreGraphics (13)** page needed a CG-shaped drawing surface; ported WinChocolate's `CGCompat.swift` + WinCoreGraphics' `CGImage` to LinChocolate (`Appearance/CGCompat.swift`, `Appearance/CGImage.swift`): `CGColor`=NSColor, `CGContext`=NSGraphicsContext (+CG op surface routed through the `NativeGraphicsContext` seam → Cairo), `CGPath`/`CGMutablePath` (segment-recording, Bézier-flattened arcs/ellipses/rounded rects), `CGGradient`/`CGColorSpace`/`CFArray`, transform stack (translate/scale/rotate applied to segments), radial gradients as 48 interpolated rings, and the RGBA8 `CGImage` with the BMP codec. Plus `NSImage(data:)` (staged to a temp file for the path-backed store) and frame-only `NSSlider`/`NSPopUpButton`/frameless `NSTextField(labelWithString:)` inits. **Compiled zero-errors on the first build**; both pages verified rendering under Xvfb — the CG artboard's leaf/gradient ramp/radial disc/transform rosette/BMP heart sprite all draw correctly, and Scroll Stress renders near-identically to the Windows reference (`--page 8` / `--stress` flags work).

**✅ All-pages size/placement audit + fixes (2026-07-13).** Screenshot-audited all 10 pages under Xvfb and fixed the layout breakage found:
- **`NSView.backgroundColor` was a dead stored property** — never reached the backend, so every colored plain view was invisible (Tables page clip/split quadrants, the entire Auto Layout page). Now wired through a new `setBackgroundColor` seam method (GTK: per-widget CSS provider at priority 800, replaced on re-set).
- **Collection views showed one empty tile** — the demo implements AppKit's `itemForRepresentedObjectAt`, which was only an extension method (statically dispatched), so LinChocolate's `representedObjectForItemAt` default returned nil. The AppKit-shaped methods are now optional protocol requirements; the default bridges the item's `textField`/`representedObject` into the text-tile pipeline. Lists-page grid now renders its items.
- **`NSStackView`/`NSGridView` stubs didn't lay out** — added real layout (equal-share distribution along the orientation; grid rows/columns honoring explicit column widths) driven by a new `NSView.layout()` hook called on frame changes. Both stack demos + the contact-details grid form render.
- **Auto Layout solver: intrinsic sizes + flipped coordinates** — unconstrained dimensions now fall back to `intrinsicContentSize` (added an estimate to `NSTextField`), both for free variables and dimensions absent from the system; and the solver's top/bottom expressions now honor `container.isFlipped` (the demo authors constraints in top-left space). The intrinsic-labels column and all panel insets now match Windows.
- **Pop-up natural height** (alert-style box), earlier this pass: `GtkDropDown` no longer honors oversized frame heights.
Verified: all 10 pages render with correct structure; contract tests pass; native demo unregressed.

**Remaining polish:**
- Custom-drawn **text** (`String.draw`) and **images** (`NSImage.draw`) are still no-op stubs from the compile-to-zero pass — the Drawing page's "WinChocolate" label and phoenix image, the CG page's section captions + `NSImage(data:)` blit (the one missing exhibit), and the Tables page's image view don't appear yet (Pango text + Cairo image compositing are the follow-up).
- Minor: New-in-3.x spinner renders as a thin bar; framework-drawn table column widths.
- Minor: `Price` uses raw `1234.5` rather than a currency formatter; token pills styled as chips; placeholder text; `Matrix` cell labels show "Choice" without row/col numbers.
- Minor: the clock-and-calendar grid slightly overlaps its neighbour; vertical-slider knob position; `NSCollectionView` partial render.
- Non-fatal `Gtk-CRITICAL` warnings from the standalone-control + grid stubs remain.

| # | Item | Status | Notes |
|---|---|---|---|
| L15.1 | Unmodified demo & apps | 🔄 Linux done | **LinChocolate: shared demo compiles + links + runs (0 errors).** Remaining: the additive AppKit convenience shim (`Demo/AppKitCompat.swift`, was ~858 errors) so the same source type-checks against real AppKit on macOS. |
| L15.2 | Parity gap log | 🔄 In progress | See [AppKitCompatibilityDivergences.md](AppKitCompatibilityDivergences.md) — the AppKit type-check surfaced the exact convenience surface + three *hard divergences* (Identifier-as-String, non-`@MainActor` helpers, settable `previousKeyView`). |
| L15.3 | Mirror AppKit-divergence fixes | ⏳ Pending (blocked on WinChocolate) | **Once the WinChocolate AppKit-divergence update lands** (per [AppKitCompatibilityDivergences.md](AppKitCompatibilityDivergences.md)), mirror the framework-side fixes in LinChocolate to match Apple exactly: (a) promote `NSToolbarItem.Identifier` / `NSUserInterfaceItemIdentifier` from the current `String` typealias to a real `RawRepresentable`+`ExpressibleByStringLiteral` struct; (b) make `NSView.previousKeyView` get-only and derive it internally from `nextKeyView` assignments. Then re-sync the shared demo and re-run all three compiles. |

## Phase L16 — Pi Cleanup ⏳

**Milestone:** the demo and the test apps **run cleanly on Raspberry Pi OS (Bookworm, aarch64) under Wayland (labwc/Wayfire) at good performance** — Pi-specific quirks resolved, the minimum supported Pi model set, and first-run install smooth. This is the dedicated Ring 3 pass that finally confirms the substrate on real Pi hardware (**S3**), delivering Goal 4 (Pi as a primary target). It runs on the normal Linux track, independent of the deferred L17.

| # | Item | Status | Notes |
|---|---|---|---|
| L16.1 | Pi bring-up (Ring 3, **S3**) | ⏳ Pending | Build and run on Raspberry Pi OS Bookworm aarch64 under labwc/Wayfire; confirm the Swift toolchain + GTK4 install and that the demo renders. First real-Pi confirmation of the substrate. |
| L16.2 | Performance & footprint | ⏳ Pending | Tune for the Pi's GPU/RAM (Cairo vs GL renderer on Pi, memory, startup time); decide the minimum supported Pi model. |
| L16.3 | Compositor & display quirks | ⏳ Pending | Resolve Wayland (labwc/Wayfire) and X11-fallback quirks, DPI/scaling, and input/keyboard on the Pi's PIXEL desktop. |
| L16.4 | First-run & packaging on Pi | ⏳ Pending | Smooth install/first-run on Pi OS; log every Pi-only finding to `NEEDS_HUMAN.md`. |

## Phase L17 — Shared-Core Convergence ⏳ (Deferred)

**Milestone:** **one shared core consumed by both siblings** — the platform-neutral API/protocol/tests/composed-controls hoisted out, both backends rebased onto it with no app-visible change, and an anti-drift CI guard in place.

Deferred until WinChocolate's API stabilizes. Sibling-first (Goal 3) means the Apple API is duplicated across the two packages during L1–L16; this phase pays that back so the API stops being maintained twice. Do not start until WinChocolate signals API stability.

| # | Item | Status | Notes |
|---|---|---|---|
| L17.1 | Convergence trigger | ⏳ Deferred | Define what "WinChocolate stable enough" means (e.g. Phase 8 modern look at parity, no churn in the `NativeControlBackend` surface for N releases) and confirm before starting. |
| L17.2 | Extract shared core | ⏳ Deferred | Hoist the platform-neutral pieces — AppKit-shaped API, `NativeControlBackend` protocol, in-memory backend, contract tests, composed controls (toolbar/alerts/panels) — into a common core target. |
| L17.3 | Rebase both siblings | ⏳ Deferred | Re-point WinChocolate (Win32 backend) and LinChocolate (Linux backend) at the shared core; delete the duplicated surface. No app-visible API change on either platform. |
| L17.4 | Anti-drift guard | ⏳ Deferred | Ensure the shared contract tests run in all three platforms' CI so the core cannot silently diverge again. |

---

## Maintenance Rules

- **Phases are serial.** Each phase ends in the **Milestone** stated at its heading — a demonstrable capability, not a checklist average. Do not start a later phase until the current phase's milestone is demonstrated; keep exactly one phase active. If work naturally spills into a later phase (as substrate validation did), that is a signal the item is mis-placed — move it to the phase it belongs to rather than opening two phases at once.
- **The AppKit surface (L4–L13) mirrors WinChocolate's phase breakdown** so the two siblings stay comparable and Phase L17 convergence stays mechanical. When a new area of AppKit surfaces (from the demo or a real app), add it to the right L4–L13 phase rather than widening one phase past its milestone.
- Keep this plan separate from `ProjectPlan.md`; LinChocolate items never count toward WinChocolate percentages.
- Track per-item percentages, milestone-first. Honor the ring rules: no windowing/compositing/perf/packaging item is "done" on a green XQuartz run alone — hence Wayland confirmation lives in Phase L14 (VMs) and Pi confirmation/cleanup in Phase L16.
- Real-hardware-only findings (Wayland, DPI, keyboard modifiers, Pi GPU/perf) are logged in `NEEDS_HUMAN.md`.
- **Sibling discipline:** while the Apple API is duplicated (L1–L16), any change to the shared-shaped surface should be made compatibly on both siblings, and the `NativeControlBackend` seam kept identical, so Phase L17's extraction stays mechanical. When you feel the pain of syncing by hand, that is the signal WinChocolate may be stable enough to trigger L17 — not a reason to fork the API.

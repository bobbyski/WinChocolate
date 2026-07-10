# LinChocolate — Build Plan (Linux)

## Dashboard

```text
Overall Progress                            ██████░░░░░░░░░░░░░░░░░░░░   24%  🔄 L4/L6 — building the AppKit surface

── Foundations ───────────────────────────────────────────────
Phase L1  · Backend Strategy                ██████████████████████████  100%  ✅ GTK4 chosen & proven on dev loop
Phase L2  · Toolchain & Harness             ██████████████████████████  100%  ✅ Reproducible one-command Ring 1 loop
Phase L3  · Core Shell & First Control      ██████████████████████████  100%  ✅ Click-counter, AppKit coords, tests green
── AppKit surface (the "all of AppKit" work) ─────────────────
Phase L4  · Basic & Value Controls          ███████████████████░░░░░░░   75%  🔄 Active — 14 control types; value controls complete
Phase L5  · Text System                     ███░░░░░░░░░░░░░░░░░░░░░░░   12%  🔄 NSTextView (multiline) landed; attributed strings, fonts next
Phase L6  · Layout Containers & Scrolling   ███████████████████░░░░░░░   75%  🔄 Tab/box/split/scroll done; NSClipView/NSScroller remain
Phase L7  · Tables, Lists, Collections      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Table / outline / browser / collection
Phase L8  · Images & Custom Drawing         ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ NSImage + LinCoreGraphics (Cairo)
Phase L9  · Menus & Toolbar                 ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Menu bar + Apple-look toolbar
Phase L10 · Dialogs & Panels                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Alert / open-save / color / popover
Phase L11 · Auto Layout                     ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ NSLayoutConstraint, anchors
Phase L12 · Appearance & Accessibility      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Dark mode, focus, AT-SPI
Phase L13 · Advanced Interaction            ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Drag & drop, printing, documents
── Verification & convergence ────────────────────────────────
Phase L14 · Linux VMs & Distribution        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Ring 2; packaging
Phase L15 · Three-Platform Proof            ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Unmodified WinChocolate demo/apps
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
| Basic controls | `NSButton` (push/check/radio), `NSTextField`, `NSSecureTextField`, `NSComboBox`, `NSSearchField`, `NSTokenField` | 🔄 all done except `NSTokenField` | L4 |
| Value controls | `NSSlider`, `NSStepper`, `NSProgressIndicator`, `NSLevelIndicator`, `NSDatePicker`, `NSColorWell` | ✅ all six done | L4 |
| Choice controls | `NSPopUpButton`, `NSSegmentedControl` | 🔄 pop-up done; segmented ⏳ | L4 |
| Multiline & structured text | `NSTextView`, `NSForm`, `NSMatrix`, `NSPathControl` | ⏳ | L5 |
| Layout containers | `NSTabView` (the page switcher), `NSSplitView`, `NSBox` | ✅ all three done — demo paged like WinChocolate's, with a Layout page | L6 |
| Scrolling | `NSScrollView`, `NSClipView`, `NSScroller` | 🔄 `NSScrollView` done | L6 |
| Tables / lists / collections | `NSTableView`, `NSOutlineView`, `NSBrowser`, `NSCollectionView` + data source / delegate / sort descriptors | ⏳ | L7 |
| Images & custom drawing | `NSImageView`, `NSBezierPath`, `NSGraphicsContext` | ⏳ | L8 |
| Menu bar + Toolbar (**Apple-look exception**) | `NSMenu`/`NSMenuItem`, `NSToolbar`/`NSToolbarItem` + customization | ⏳ | L9 |
| Dialogs & panels | `NSAlert`, `NSOpenPanel`/`NSSavePanel`, `NSColorPanel`, `NSPopover`, `NSPanel` | ⏳ | L10 |
| Materials | `NSVisualEffectView` | ⏳ | L10 |
| Drag & drop | `NSDraggingSource`/`NSDraggingInfo`, `NSPasteboard` | ⏳ | L13 |
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

## Phase L5 — Text System ⏳

**Milestone:** multiline rich text works — `NSTextView` editing inside a scroll view, `NSAttributedString` styling with `NSFont`/`NSColor`, plus the `NSForm`/`NSMatrix` composed layouts the demo uses.

| # | Item | Status | Notes |
|---|---|---|---|
| L5.1 | `NSTextView` | ⏳ Pending | Multiline editing over `GtkTextView` in a `GtkScrolledWindow`; editable/selectable, dirty state. |
| L5.2 | Attributed text | ⏳ Pending | `NSAttributedString` + `NSFont` + `NSColor` runs mapped to Pango attributes. |
| L5.3 | `NSForm` / `NSMatrix` | ⏳ Pending | Composed label/field grids. |

## Phase L6 — Layout Containers & Scrolling ⏳

**Milestone:** the demo's page switcher and split panes work — `NSTabView`, `NSSplitView`, `NSBox`, and the `NSScrollView`/`NSClipView`/`NSScroller` stack.

| # | Item | Status | Notes |
|---|---|---|---|
| L6.1 | `NSTabView` | ⏳ Pending | Page switcher over `GtkNotebook` (or `GtkStack` + `GtkStackSwitcher`). |
| L6.2 | `NSSplitView` / `NSBox` | ⏳ Pending | `GtkPaned` panes; `GtkFrame` group boxes. |
| L6.3 | Scrolling stack | ⏳ Pending | `NSScrollView`/`NSClipView`/`NSScroller` over `GtkScrolledWindow`; document view + offset. |

## Phase L7 — Tables, Lists, Collections ⏳

**Milestone:** data-driven views work — `NSTableView`, `NSOutlineView`, `NSBrowser`, and `NSCollectionView` with data source/delegate, selection, and sort descriptors (mirrors WinChocolate Phase 5).

| # | Item | Status | Notes |
|---|---|---|---|
| L7.1 | `NSTableView` | ⏳ Pending | `NSTableColumn` + data source/delegate over `GtkColumnView`; cell/view reuse. |
| L7.2 | `NSOutlineView` / `NSBrowser` | ⏳ Pending | Tree / column navigation (`GtkTreeListModel`). |
| L7.3 | `NSCollectionView` | ⏳ Pending | Grid / flow layout over `GtkGridView`/`GtkFlowBox`. |
| L7.4 | Selection & sorting | ⏳ Pending | Row/column selection, action/double-action, `NSSortDescriptor`. |

## Phase L8 — Images & Custom Drawing ⏳ (LinCoreGraphics)

**Milestone:** bitmaps display and custom drawing works — `NSImageView`/`NSImage`, plus a Core-Graphics-shaped drawing layer (`NSBezierPath`, `NSGraphicsContext`, `NSGradient`, `NSColor`) over Cairo so `draw(_:)`-style views render (the Linux peer of WinChocolate's WinCoreGraphics).

| # | Item | Status | Notes |
|---|---|---|---|
| L8.1 | `NSImageView` / `NSImage` | ⏳ Pending | Bitmap load / scale / align via GdkPixbuf / `GtkPicture`. |
| L8.2 | LinCoreGraphics | ⏳ Pending | `NSBezierPath`, `NSGraphicsContext`, `NSColor`/`NSGradient` fill/stroke over Cairo. |
| L8.3 | Custom view drawing | ⏳ Pending | `NSView.draw(_:)` hook via `GtkDrawingArea` / snapshot. |

## Phase L9 — Menus & Toolbar ⏳

**Milestone:** the app menu bar and the Apple-look toolbar work — `NSMenu`/`NSMenuItem` with key equivalents, and `NSToolbar`/`NSToolbarItem` (the deliberate Apple-look exception, Goal 2) with the customization sheet (mirrors WinChocolate Phase 6).

| # | Item | Status | Notes |
|---|---|---|---|
| L9.1 | Menu bar | ⏳ Pending | `NSMenu`/`NSMenuItem` + key equivalents via `GMenu` / `GtkPopoverMenuBar`. |
| L9.2 | `NSToolbar` | ⏳ Pending | Apple-look composed (hand-drawn) — the one deliberate non-native control. |
| L9.3 | Customization | ⏳ Pending | Toolbar customization sheet. |

## Phase L10 — Dialogs & Panels ⏳

**Milestone:** standard dialogs work — `NSAlert`, open/save panels, color panel, popover, `NSPanel` subclasses, and `NSVisualEffectView` materials.

| # | Item | Status | Notes |
|---|---|---|---|
| L10.1 | `NSAlert` | ⏳ Pending | `AdwMessageDialog` / `GtkAlertDialog`. |
| L10.2 | Open/Save panels | ⏳ Pending | `NSOpenPanel`/`NSSavePanel` over `GtkFileDialog`. |
| L10.3 | Color panel | ⏳ Pending | `NSColorPanel`/`NSColorWell` over `GtkColorDialog`. |
| L10.4 | Popover & panels | ⏳ Pending | `NSPopover` (`GtkPopover`); `NSPanel` subclasses. |
| L10.5 | Materials | ⏳ Pending | `NSVisualEffectView` blur/material surface. |

## Phase L11 — Auto Layout ⏳

**Milestone:** AppKit Auto Layout works — `NSLayoutConstraint`, layout anchors, intrinsic content size, priorities, hugging/compression resistance, and `translatesAutoresizingMaskIntoConstraints` — so apps aren't limited to manual frames (mirrors WinChocolate Phase 9).

| # | Item | Status | Notes |
|---|---|---|---|
| L11.1 | Constraints & anchors | ⏳ Pending | `NSLayoutConstraint` + layout-anchor API and a constraint solver. |
| L11.2 | Intrinsic sizing | ⏳ Pending | Intrinsic content size, content hugging, compression resistance, priorities. |
| L11.3 | Backend integration | ⏳ Pending | Solve constraints → child frames in the GtkFixed content view. |

## Phase L12 — Appearance & Accessibility ⏳

**Milestone:** the app looks native and is accessible — dark mode / theme-following (finalizing the plain-GTK4-vs-libadwaita baseline), the full `NSResponder` key-view focus loop, and AT-SPI accessibility (mirrors WinChocolate Phase 10).

| # | Item | Status | Notes |
|---|---|---|---|
| L12.1 | Appearance | ⏳ Pending | Dark mode / theme-following; settle plain-GTK4 vs libadwaita (the L1.2 baseline, with a Pi in hand). |
| L12.2 | Responder & focus | ⏳ Pending | `NSResponder` chain, first responder, `nextKeyView` loop, focus-ring visibility. |
| L12.3 | Accessibility | ⏳ Pending | Roles / states / keyboard model via `GtkAccessible` / AT-SPI. |

## Phase L13 — Advanced Interaction ⏳

**Milestone:** drag & drop, printing, and the document architecture work — `NSDraggingSource`/`NSDraggingInfo` + `NSPasteboard`, `NSPrintOperation`, and `NSDocument`/`NSDocumentController`.

| # | Item | Status | Notes |
|---|---|---|---|
| L13.1 | Drag & drop | ⏳ Pending | `NSPasteboard` + drag source/destination over GTK DnD / `GdkClipboard`. |
| L13.2 | Printing | ⏳ Pending | `NSPrintOperation` → `GtkPrintOperation`. |
| L13.3 | Documents | ⏳ Pending | `NSDocument`/`NSDocumentController` open / save / dirty lifecycle. |

## Phase L14 — Linux VMs & Distribution ⏳

**Milestone:** the demo **runs on x86-64 + aarch64 Linux VMs (X11 and Wayland)** — Ring 2 stood up, the Wayland path proven (XQuartz cannot), and the distribution/packaging shape decided. *(Raspberry Pi hardware is its own focused phase — L16.)*

| # | Item | Status | Notes |
|---|---|---|---|
| L14.1 | Linux VM ring (Ring 2) | ⏳ Pending | x86-64 + aarch64 VMs with both an X11 and a Wayland session; the demo runs on each. Wayland path proven (XQuartz cannot). |
| L14.2 | Distribution shape | ⏳ Pending | SwiftPM-only vs distro packaging; minimum supported distros/desktops. Pi OS primary; mainstream x86-64 distros follow. |
| L14.3 | WSLg secondary loop | ⏳ Pending | Document the Ring 1b WSLg loop so the demo runs on the Windows machine over Wayland/XWayland. |
| L14.4 | CI | ⏳ Pending | Wire the container ring (build + contract tests) into CI; define the periodic verification cadence. |

## Phase L15 — Three-Platform Proof ⏳

**Milestone:** the **WinChocolate demo and Phase 11 apps build and run unmodified on macOS, Windows, and Linux** (the concrete proof of Goal 1 — see the Demo Parity section), verified through all rings, with Linux-only gaps logged back into this plan.

| # | Item | Status | Notes |
|---|---|---|---|
| L15.1 | Unmodified demo & apps | ⏳ Pending | The WinChocolate demo and Phase 11 apps build and run unmodified on all three platforms via the conditional-import idiom; the dual-platform harness grows a third target. |
| L15.2 | Parity gap log | ⏳ Pending | Linux-only gaps (and Wayland-vs-X11 or Pi-only gaps) feed back into this plan the way WinChocolate 11.7 feeds the Windows phases. |

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

# LinChocolate — Build Plan (Linux)

## Dashboard

```text
Overall Progress                           █████░░░░░░░░░░░░░░░░░░░░░   20%  🔄 Phase L3 active

Phase L1 · Backend Strategy                ██████████████████████████  100%  ✅ Milestone met — GTK4 chosen & proven on dev loop
Phase L2 · Toolchain & Harness             ██████████████████████████  100%  ✅ Milestone met — reproducible one-command Ring 1 loop
Phase L3 · Core Shell & First Control      ██████████████████░░░░░░░░   70%  🔄 Active — native click-counter runs, tests green
Phase L4 · Control Parity Pass             ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L5 · Real-Hardware & Distribution    ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L6 · Three-Platform Proof            ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L7 · Shared-Core Convergence         ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Deferred (post-WinChocolate-stable)
```

**Phases run serially:** each ends in the **Milestone** stated at its heading, and the next phase does not begin until that milestone is demonstrated. Progress bars reflect one active phase at a time.

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; 🚫 Blocked

---

## Summary

LinChocolate brings the same AppKit-shaped Swift API to Linux that WinChocolate brings to Windows: Apple API in, native Linux look out. Application sources stay byte-identical across macOS, Windows, and Linux via the single conditional-import idiom (`import AppKit` on Mac, `import WinChocolate` on Windows, `import LinChocolate` on Linux). Work starts **after the Windows framework is going** (roughly: WinChocolate Phases 3–8 mature); until then the later phases stay deliberately high-level and get detailed the way WinChocolate's did once work approached.

LinChocolate is a **sibling** to WinChocolate, not a sub-project: it starts as its own package that references WinChocolate's already-proven Apple-compatible API, and converges onto shared elements only once WinChocolate stabilizes (Phase L7). The defining environment change from the earlier draft of this plan: development and everyday testing now happen **on the Mac, using Docker + XQuartz** — a Linux container builds and runs honest Linux binaries, and their GUI windows display on the Mac desktop through XQuartz (X11). **Real Linux VMs and Raspberry Pi hardware** are the verification rings that catch what the container hides (Wayland, real GPU/RAM, packaging, aarch64 hardware quirks). This plan follows the AI-coding-rules plan format (`AICoding rules.md`) and is tracked separately from `ProjectPlan.md` — LinChocolate items never count toward WinChocolate percentages.

## Project Goals

1. **PRIMARY GOAL — Apple AppKit API compatibility**, identical to WinChocolate's: most Mac AppKit programs build and run (at least their UI) by swapping `import AppKit` for `import LinChocolate`. When any design decision conflicts with this goal, Apple API compatibility wins.
2. **Native Linux presentation — modern only.** Apps should look like modern Linux apps. Unlike WinChocolate there is **no classic/legacy look and no presentation switch**: the classic Win32 look on Windows exists for historical reasons, not as a pattern to replicate. LinChocolate ships one contemporary presentation; what exactly it follows (GNOME HIG? theme-following?) is a Phase L1 decision. The Apple-look toolbar exception carries over unchanged.
3. **Sibling now, shared core later.** LinChocolate starts as a **sibling package** alongside WinChocolate — its own package that mirrors WinChocolate's AppKit-shaped layout and uses it as a *reference implementation*, with only the backend behind `NativeControlBackend` written fresh for Linux. The Apple API surface is duplicated at first and synced by hand. **Once WinChocolate's API stabilizes**, the plan converges the two onto shared elements (Phase L7): the platform-neutral API, the `NativeControlBackend` protocol, the in-memory backend, the contract tests, and the composed controls get extracted into a common core both siblings consume. Every design decision keeps that seam narrow and platform-neutral so the later extraction is mechanical, not a rewrite.
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

## Phase L1 — Backend Strategy ✅

**Milestone (met):** GTK4 chosen as the substrate and *proven runnable from Swift on the Ring 1 dev loop* — a GTK4 window renders over XQuartz.

| # | Item | Status | Notes |
|---|---|---|---|
| L1.1 | Native substrate choice | ✅ Done | **GTK 4 via Swift C-interop, Cairo renderer for the XQuartz loop** — see [LinChocolateSubstrate.md](LinChocolateSubstrate.md). Only candidate delivering a native, modern, theme-following look (Goal 2) with Wayland+X11, HiDPI, IME, and AT-SPI already solved; the Pi's own toolkit; Swift↔GTK4 binding path real and Swift.org-endorsed. Validated by **S1** (compiles), **S2** (renders over XQuartz), **S4** (seam swappable). GTK3 is the documented fallback; custom X11/Wayland+Cairo rejected. Pi confirmation (**S3**) is a Phase L5 gate, not a blocker on the decision. |
| L1.2 | Target look baseline | ✅ Decided | Baseline is **plain GTK4 (follows the active system theme)** — right for the Pi's PIXEL desktop; libadwaita optional where a polished GNOME look is wanted. The plain-vs-libadwaita call is refined in L4 with a Pi in hand (substrate doc §5). |

## Phase L2 — Toolchain & Harness ✅

**Milestone (met):** a reproducible, checked-in **one-command Ring 1 loop** (`./run-linux.sh`) that builds the container and shows a native window on the Mac, with the sibling package building against real Foundation.

| # | Item | Status | Notes |
|---|---|---|---|
| L2.1 | Swift toolchain pin | ✅ Done | `swift:6.0-noble` pinned in the image (GTK 4.14.5; aarch64 on Apple Silicon, `SWIFT_TAG` build-arg for x86-64); GTK4 C-interop builds cleanly. Re-confirmed on VMs/Pi in L5. |
| L2.2 | Docker dev image | ✅ Done | `LinChocolate/Dockerfile` — `swift:6.0-noble` + `libgtk-4-dev` + `dbus-x11`, aarch64 to match the Pi. Image builds; `swift build` green (**S1**). |
| L2.3 | XQuartz display bridge | ✅ Done | `LinChocolate/run-linux.sh` auto-enables XQuartz TCP, restarts it, `xhost +`, dials `DISPLAY=<en0-IP>:0`, `GSK_RENDERER=cairo`. Window renders on the Mac (**S2**). (Ring 1b WSLg loop doc → L5.) |
| L2.4 | Real Foundation | ✅ Confirmed | corelibs Foundation works on Linux out of the box — `NSRect`/`NSPoint`/`NSMakeRect`/`CGFloat` used directly, no WinFoundation-style shim needed. `USE_REAL_FOUNDATION` is simply the default here. |
| L2.5 | Sibling package layout | ✅ Done | `LinChocolate/` stood up as its own package (nested for now; graduates to a true sibling dir at convergence) mirroring WinChocolate: AppKit-shaped `LinChocolate` target + GTK/in-memory backends + demo + contract tests. `NativeControlBackend` seam mirrors WinChocolate's shape for L7. WinChocolate untouched. |

## Phase L3 — Core Shell & First Control 🔄 (ACTIVE)

**Milestone:** the AppKit-shaped **click-counter runs as native GTK controls with green contract tests** — `NSApplication`/`NSWindow`/`NSButton`/`NSTextField` driving GTK through the `NativeControlBackend` seam, with frames matching AppKit's coordinate model. *(Demo + tests already work; the coordinate model closes it.)*

| # | Item | Status | Notes |
|---|---|---|---|
| L3.1 | Application shell | ✅ Done | `NSApplication`/`NSWindow` over GTK4 (`GMainLoop` lifecycle, window create/show, close→terminate); renders over XQuartz and quits cleanly. |
| L3.2 | Backend seam + first controls | ✅ Done | `NativeControlBackend` + GTK and in-memory backends; `NSView` (GtkFixed), `NSButton` (GtkButton), `NSTextField` label (GtkLabel); event bridge `registerAction` → GTK `clicked`. Click-counter demo works. |
| L3.3 | Contract tests | ✅ Done | `LinChocolateContractTests` 13/13 green (in-memory backend), including the full API→backend click path (**S4**). |
| L3.4 | AppKit coordinate model | ⏳ Pending | GTK top-left → AppKit bottom-left Y-flip, plus live `setFrame`/window resize, so frames match AppKit exactly. **Closes the L3 milestone.** |

## Phase L4 — Control Parity Pass ⏳

**Milestone:** the demo's **Controls-page equivalent runs** — the core control set (editable text, checkboxes/radios, and more) with each `NS*` mapped to its GTK peer in `CONTROL_PARITY.md`, and composed controls reused where GTK lacks a native peer.

| # | Item | Status | Notes |
|---|---|---|---|
| L4.1 | Core control set | ⏳ Pending | Editable `NSTextField`, checkbox/radio `NSButton`, and enough of the matrix to run a Controls page. |
| L4.2 | Parity matrix | ⏳ Pending | Extend `CONTROL_PARITY.md` with a Linux column; map each `NS*` control to its GTK peer. |
| L4.3 | Composed-control reuse | ⏳ Pending | Reuse composed designs (toolbar, alerts, panels, customization sheet) where GTK lacks a native peer; keep the Apple-look toolbar exception. |
| L4.4 | Look refinement | ⏳ Pending | Settle plain-GTK4 vs libadwaita (the L1.2 baseline) with a Pi in hand. |

## Phase L5 — Real-Hardware & Distribution ⏳

**Milestone:** the demo **runs on a real Raspberry Pi under Wayland (S3)** and on **x86-64 + aarch64 Linux VMs (X11 and Wayland)** — Rings 2–3 stood up, Wayland proven, and the distribution/packaging shape decided. This is where the substrate's Pi/Wayland assumptions are finally confirmed on hardware.

| # | Item | Status | Notes |
|---|---|---|---|
| L5.1 | Linux VM ring (Ring 2) | ⏳ Pending | x86-64 + aarch64 VMs with both an X11 and a Wayland session; the demo runs on each. Wayland path proven (XQuartz cannot). |
| L5.2 | Raspberry Pi (Ring 3, **S3**) | ⏳ Pending | Build+run on Raspberry Pi OS Bookworm aarch64 under labwc/Wayfire at acceptable perf; decide the minimum supported Pi model. Confirms the substrate on real hardware. |
| L5.3 | Distribution shape | ⏳ Pending | SwiftPM-only vs distro packaging; minimum supported distros/desktops. Pi OS primary; mainstream x86-64 distros follow. |
| L5.4 | WSLg secondary loop | ⏳ Pending | Document the Ring 1b WSLg loop so the demo runs on the Windows machine over Wayland/XWayland. |
| L5.5 | CI | ⏳ Pending | Wire the container ring (build + contract tests) into CI; define the periodic real-hardware verification cadence. |

## Phase L6 — Three-Platform Proof ⏳

**Milestone:** the **WinChocolate Phase 11 apps build and run unmodified on macOS, Windows, and Linux**, verified through all rings, with Linux-only gaps logged back into this plan.

| # | Item | Status | Notes |
|---|---|---|---|
| L6.1 | Test apps unmodified | ⏳ Pending | WinChocolate Phase 11 apps build and run unmodified on all three platforms; the dual-platform harness (11.6) grows a third target. |
| L6.2 | Parity gap log | ⏳ Pending | Linux-only gaps (and Wayland-vs-X11 or Pi-only gaps) feed back into this plan the way WinChocolate 11.7 feeds the Windows phases. |

## Phase L7 — Shared-Core Convergence ⏳ (Deferred)

**Milestone:** **one shared core consumed by both siblings** — the platform-neutral API/protocol/tests/composed-controls hoisted out, both backends rebased onto it with no app-visible change, and an anti-drift CI guard in place.

Deferred until WinChocolate's API stabilizes. Sibling-first (Goal 3) means the Apple API is duplicated across the two packages during L1–L6; this phase pays that back so the API stops being maintained twice. Do not start until WinChocolate signals API stability.

| # | Item | Status | Notes |
|---|---|---|---|
| L7.1 | Convergence trigger | ⏳ Deferred | Define what "WinChocolate stable enough" means (e.g. Phase 8 modern look at parity, no churn in the `NativeControlBackend` surface for N releases) and confirm before starting. |
| L7.2 | Extract shared core | ⏳ Deferred | Hoist the platform-neutral pieces — AppKit-shaped API, `NativeControlBackend` protocol, in-memory backend, contract tests, composed controls (toolbar/alerts/panels) — into a common core target. |
| L7.3 | Rebase both siblings | ⏳ Deferred | Re-point WinChocolate (Win32 backend) and LinChocolate (Linux backend) at the shared core; delete the duplicated surface. No app-visible API change on either platform. |
| L7.4 | Anti-drift guard | ⏳ Deferred | Ensure the shared contract tests run in all three platforms' CI so the core cannot silently diverge again. |

---

## Maintenance Rules

- **Phases are serial.** Each phase ends in the **Milestone** stated at its heading — a demonstrable capability, not a checklist average. Do not start a later phase until the current phase's milestone is demonstrated; keep exactly one phase active. If work naturally spills into a later phase (as substrate validation did), that is a signal the item is mis-placed — move it to the phase it belongs to rather than opening two phases at once.
- Keep this plan separate from `ProjectPlan.md`; LinChocolate items never count toward WinChocolate percentages.
- Track per-item percentages, milestone-first. Honor the ring rules: no windowing/compositing/perf/packaging item is "done" on a green XQuartz run alone — hence Wayland/Pi confirmation lives in Phase L5.
- Real-hardware-only findings (Wayland, DPI, keyboard modifiers, Pi GPU/perf) are logged in `NEEDS_HUMAN.md`.
- **Sibling discipline:** while the Apple API is duplicated (L1–L6), any change to the shared-shaped surface should be made compatibly on both siblings, and the `NativeControlBackend` seam kept identical, so Phase L7's extraction stays mechanical. When you feel the pain of syncing by hand, that is the signal WinChocolate may be stable enough to trigger L7 — not a reason to fork the API.

# LinChocolate — Build Plan (Linux)

## Summary

LinChocolate brings the same AppKit-shaped Swift API to Linux that WinChocolate brings to Windows: Apple API in, native Linux look out. Work starts **after the Windows framework is going** (roughly: WinChocolate Phases 3-8 mature). Until then this plan stays deliberately high-level; phases get detailed the way WinChocolate's Phases 3-10 did once work approaches.

This plan is tracked separately from `ProjectPlan.md` (the WinChocolate plan) and does not count toward its progress percentages.

## Project Goals

1. **PRIMARY GOAL — Apple AppKit API compatibility**, identical to WinChocolate's: most Mac AppKit programs build and run (at least their UI) by swapping `import AppKit` for `import LinChocolate`. Application sources stay byte-identical across macOS, Windows, and Linux via the single conditional-import idiom (WinChocolate plan, item 11.1).
2. **Native Linux presentation — modern only.** Apps should look like modern Linux apps. Unlike WinChocolate there is **no classic/legacy look and no presentation switch**: the classic Win32 look on Windows exists for historical reasons (Codex happened to start there and it proved useful on Windows), not as a pattern to replicate. LinChocolate ships one contemporary presentation; what exactly it follows (GNOME HIG? theme-following?) is a Phase L1 decision.
3. **One shared core.** The AppKit-shaped API layer is shared; only the backend behind `NativeControlBackend` is platform-specific. Windows-era decisions keep that boundary narrow and platform-neutral.
4. **Raspberry Pi OS is a primary target.** LinChocolate must run well on Raspberry Pi hardware (aarch64, modest GPU/RAM), not just desktop distros — substrate and rendering choices are made with the Pi in mind.
5. **WSL is the primary development environment.** Day-to-day development happens in WSL2 on the Windows machine (WSLg runs GUI apps over Wayland/X11 out of the box), with periodic verification passes on real Linux — Raspberry Pi OS first. Everything must build and run under WSL; nothing may *only* work there.

## Hard constraints

- **No Qt.** Ruled out on licensing grounds (GPL/LGPL-with-strings or commercial); candidate substrates are GTK or a custom X11/Wayland + Cairo backend.
- **Display server:** current Raspberry Pi OS (Bookworm, 2023+) defaults to **Wayland** (Wayfire, then labwc) on Pi 4/5, while older Pi models and older images still run X11 — so the backend must work on both. A toolkit like GTK abstracts the two; a hand-rolled backend must not be Wayland-only or X11-only.

## Standing constraints inherited from WinChocolate

- The `NativeControlBackend` protocol is the substitution point; LinChocolate must not require API-layer changes.
- The in-memory backend and contract tests are platform-neutral and must pass unchanged on Linux.
- The symbol-image glyph set (WinChocolate plan, item 12.2 — a Rev 2.0 issue, formerly 3.24) is original, copyright-clean artwork designed to be reused here.

---

## Dashboard

```text
Overall Progress                           ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Not started

Phase L1 · Backend Strategy                ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L2 · Toolchain and Foundation Audit  ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L3 · Core Shell Port                 ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L4 · Control Parity Pass             ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L5 · Three-Platform Proof            ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
```

---

## Phase L1 — Backend Strategy ⏳

Decide before writing any Linux code.

| # | Item | Status | Notes |
|---|---|---|---|
| L1.1 | Native substrate choice | ⏳ Pending | GTK (3 or 4) vs X11/Wayland + Cairo custom rendering — Qt is ruled out (license, see Hard constraints). Weigh: native-look fidelity, C-interop ergonomics from Swift, X11+Wayland coverage (required for the Pi range), performance on Pi-class hardware, and how much of the composed-control work (toolbar, alerts, panels) carries over unchanged. |
| L1.2 | Target look definition | ⏳ Pending | Define "looks like a modern Linux app" (GNOME HIG as the default? follow the active theme? PIXEL desktop conventions on Pi?). Modern only — no classic look and no presentation switch on Linux (see goal 2); the Apple-look toolbar exception carries over unchanged. |
| L1.3 | Distribution shape | ⏳ Pending | SwiftPM-only vs distro packaging expectations; minimum supported distros/desktop environments. Raspberry Pi OS (Bookworm, aarch64) is the primary target; mainstream x86-64 distros follow. |
| L1.4 | Pi hardware validation | ⏳ Pending | Confirm the Swift toolchain and chosen substrate build and run acceptably on Raspberry Pi OS aarch64 (and decide the minimum supported Pi model) before committing to the substrate. |

## Phase L2 — Toolchain and Foundation Audit ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L2.1 | Swift-on-Linux validation | ⏳ Pending | Pin a toolchain — in WSL2 (primary dev environment), on Raspberry Pi OS aarch64, and on a mainstream x86-64 distro — and confirm C-interop with the chosen substrate builds cleanly on all three. |
| L2.2 | Real Foundation | ⏳ Pending | Swift on Linux ships working corelibs Foundation, so the `USE_REAL_FOUNDATION` path (WinChocolate plan, 7.2) likely replaces WinFoundation entirely here; rerun the canary from `FOUNDATION_SHIMS.md` and record the result. |
| L2.3 | Package layout | ⏳ Pending | Restructure to one AppKit-shaped core target with per-platform backend targets (Win32, Linux, in-memory), without breaking WinChocolate consumers. |
| L2.4 | WSL development loop | ⏳ Pending | Prove the edit-build-run loop in WSL2 with WSLg (GUI windows over Wayland/X11), including debugging; document the setup so the loop is reproducible. Define the cadence and checklist for periodic real-Linux verification passes (Pi first). |

## Phase L3 — Core Shell Port ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L3.1 | Application shell | ⏳ Pending | Run loop, application lifecycle, window creation/close/resize over the chosen substrate. |
| L3.2 | First control set | ⏳ Pending | Buttons, labels, text fields, and the event bridge — enough to run the demo's Controls page. |
| L3.3 | Contract tests on Linux CI | ⏳ Pending | The existing WinChocolate contract tests (in-memory backend) pass unchanged on Linux; add backend-specific contract coverage as peers land. |

## Phase L4 — Control Parity Pass ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L4.1 | Parity matrix | ⏳ Pending | Extend `CONTROL_PARITY.md` with a Linux column and walk the control matrix. |
| L4.2 | Composed-control reuse | ⏳ Pending | Reuse the composed designs (toolbar, alerts, panels, customization sheet) where the substrate lacks a native peer; keep the Apple-look toolbar exception. |

## Phase L5 — Three-Platform Proof ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L5.1 | Test apps unmodified | ⏳ Pending | The WinChocolate Phase 11 apps build and run unmodified on macOS, Windows, and Linux; the dual-platform harness (11.6) grows a third target. |
| L5.2 | Parity gap log | ⏳ Pending | Linux-only gaps feed back into this plan the way 11.7 feeds the Windows phases. |

---

## Maintenance Rules

- Keep this plan separate from `ProjectPlan.md`; LinChocolate items never count toward WinChocolate percentages.
- Until work starts, only revisit this plan when a Windows-side decision would affect the backend boundary — record the consequence here.
- When work starts, adopt the same per-item percentage discipline and milestone-first working method as the WinChocolate plan.

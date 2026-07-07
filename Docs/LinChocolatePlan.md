# LinChocolate — Build Plan (Linux)

## Dashboard

```text
Overall Progress                           ███░░░░░░░░░░░░░░░░░░░░░░░    9%  🔄 Ring 1 loop proven end-to-end

Phase L1 · Backend Strategy                █████░░░░░░░░░░░░░░░░░░░░░   22%  🔄 GTK4 recommended (S1+S2 passed)
Phase L2 · Toolchain & Environment         █████████░░░░░░░░░░░░░░░░░   35%  🔄 Ring 1 harness verified
Phase L3 · Core Shell Port                 ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L4 · Control Parity Pass             ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L5 · Three-Platform Proof            ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase L6 · Shared-Core Convergence         ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Deferred (post-WinChocolate-stable)
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; 🚫 Blocked

---

## Summary

LinChocolate brings the same AppKit-shaped Swift API to Linux that WinChocolate brings to Windows: Apple API in, native Linux look out. Application sources stay byte-identical across macOS, Windows, and Linux via the single conditional-import idiom (`import AppKit` on Mac, `import WinChocolate` on Windows, `import LinChocolate` on Linux). Work starts **after the Windows framework is going** (roughly: WinChocolate Phases 3–8 mature); until then the later phases stay deliberately high-level and get detailed the way WinChocolate's did once work approached.

LinChocolate is a **sibling** to WinChocolate, not a sub-project: it starts as its own package that references WinChocolate's already-proven Apple-compatible API, and converges onto shared elements only once WinChocolate stabilizes (Phase L6). The defining environment change from the earlier draft of this plan: development and everyday testing now happen **on the Mac, using Docker + XQuartz** — a Linux container builds and runs honest Linux binaries, and their GUI windows display on the Mac desktop through XQuartz (X11). **Real Linux VMs and Raspberry Pi hardware** are the verification rings that catch what the container hides (Wayland, real GPU/RAM, packaging, aarch64 hardware quirks). This plan follows the AI-coding-rules plan format (`AICoding rules.md`) and is tracked separately from `ProjectPlan.md` — LinChocolate items never count toward WinChocolate percentages.

## Project Goals

1. **PRIMARY GOAL — Apple AppKit API compatibility**, identical to WinChocolate's: most Mac AppKit programs build and run (at least their UI) by swapping `import AppKit` for `import LinChocolate`. When any design decision conflicts with this goal, Apple API compatibility wins.
2. **Native Linux presentation — modern only.** Apps should look like modern Linux apps. Unlike WinChocolate there is **no classic/legacy look and no presentation switch**: the classic Win32 look on Windows exists for historical reasons, not as a pattern to replicate. LinChocolate ships one contemporary presentation; what exactly it follows (GNOME HIG? theme-following?) is a Phase L1 decision. The Apple-look toolbar exception carries over unchanged.
3. **Sibling now, shared core later.** LinChocolate starts as a **sibling package** alongside WinChocolate — its own package that mirrors WinChocolate's AppKit-shaped layout and uses it as a *reference implementation*, with only the backend behind `NativeControlBackend` written fresh for Linux. The Apple API surface is duplicated at first and synced by hand. **Once WinChocolate's API stabilizes**, the plan converges the two onto shared elements (Phase L6): the platform-neutral API, the `NativeControlBackend` protocol, the in-memory backend, the contract tests, and the composed controls get extracted into a common core both siblings consume. Every design decision keeps that seam narrow and platform-neutral so the later extraction is mechanical, not a rewrite.
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

## Phase L1 — Backend Strategy ⏳

Decide before writing any Linux code.

| # | Item | Status | Notes |
|---|---|---|---|
| L1.1 | Native substrate choice | 🔄 Recommended | **GTK 4 via Swift C-interop, Cairo renderer for the XQuartz loop** — see [LinChocolateSubstrate.md](LinChocolateSubstrate.md) for the full evaluation. GTK4 is the only candidate delivering a native, modern, theme-following look (Goal 2) with Wayland+X11, HiDPI, IME, and AT-SPI accessibility already solved; it's the Pi's own toolkit; and the Swift↔GTK4 binding path is real and Swift.org-endorsed. GTK3 is a documented fallback; custom X11/Wayland+Cairo is rejected (contradicts Goal 2, reinvents a toolkit). Recommendation stays 🔄 until validation spikes S1–S4 pass. |
| L1.2 | Target look definition | ⏳ Pending | Define "looks like a modern Linux app" (GNOME HIG default? follow the active theme? PIXEL desktop conventions on Pi?). Modern only — no classic look, no presentation switch (goal 2). |
| L1.3 | Distribution shape | ⏳ Pending | SwiftPM-only vs distro packaging expectations; minimum supported distros/desktop environments. Raspberry Pi OS (Bookworm, aarch64) is the primary target; mainstream x86-64 distros follow. |
| L1.4 | Pi hardware validation | ⏳ Pending | Confirm the Swift toolchain and chosen substrate build and run acceptably on Raspberry Pi OS aarch64 (Ring 3), and decide the minimum supported Pi model, **before** committing to the substrate. |

## Phase L2 — Toolchain & Environment ⏳

Stand up the three-ring environment (see matrix) and the Foundation/package groundwork.

| # | Item | Status | Notes |
|---|---|---|---|
| L2.1 | Swift-on-Linux toolchain pin | ⏳ Pending | Pin one Swift toolchain and use it across all three rings — in the Docker image, on the Linux VMs, and on Raspberry Pi OS aarch64 — and confirm C-interop with the chosen substrate builds cleanly on each. |
| L2.2 | Docker dev image | ✅ Built | `LinChocolate/Dockerfile` — `swift:6.0-noble` + `libgtk-4-dev` (GTK 4.14.5), builds **aarch64** on Apple Silicon to match the Pi (`SWIFT_TAG` build-arg for the x86-64 variant). Verified: image builds and `swift build` of the GTK4 spike is green (**spike S1**). |
| L2.3 | GUI display bridges | ✅ Mac verified | **Mac/XQuartz (primary):** `LinChocolate/run-linux.sh` auto-enables XQuartz TCP, restarts it if needed, `xhost +`, and dials `DISPLAY=<host-en0-IP>:0` with `GSK_RENDERER=cairo`. **Spike S2 passed** — GTK4 window rendered on the Mac over XQuartz. **WSL (secondary):** WSLg loop still to be documented. |
| L2.4 | Real Foundation | ⏳ Pending | Swift on Linux ships working corelibs Foundation, so the `USE_REAL_FOUNDATION` path (WinChocolate plan, 7.2) likely replaces WinFoundation entirely here; rerun the canary from `FOUNDATION_SHIMS.md` and record the result. |
| L2.5 | Sibling package layout | ⏳ Pending | Stand up LinChocolate as its **own package**, a sibling directory next to WinChocolate, mirroring its target layout (AppKit-shaped API + `Native/Linux` backend + in-memory backend + contract tests). Copy/adapt the Apple API surface from WinChocolate as reference; keep the `NativeControlBackend` seam byte-compatible so Phase L6 can later hoist the neutral parts into a shared core. Do not restructure WinChocolate itself yet. |
| L2.6 | VM & Pi verification setup | ⏳ Pending | Stand up Ring 2 (x86-64 + aarch64 Linux VMs with both an X11 session and a Wayland session) and Ring 3 (a Pi running Bookworm). Write the checklist and cadence for periodic verification passes; wire whatever CI is feasible for the container ring. |

## Phase L3 — Core Shell Port ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L3.1 | Application shell | ⏳ Pending | Run loop, application lifecycle, window creation/close/resize over the chosen substrate; first proven in Ring 1 (XQuartz X11), then Ring 2 Wayland. |
| L3.2 | First control set | ⏳ Pending | Buttons, labels, text fields, and the event bridge — enough to run the demo's Controls page. |
| L3.3 | Contract tests on Linux CI | ⏳ Pending | The existing WinChocolate contract tests (in-memory backend) pass unchanged inside the container; add backend-specific contract coverage as peers land. |

## Phase L4 — Control Parity Pass ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L4.1 | Parity matrix | ⏳ Pending | Extend `CONTROL_PARITY.md` with a Linux column and walk the control matrix. |
| L4.2 | Composed-control reuse | ⏳ Pending | Reuse the composed designs (toolbar, alerts, panels, customization sheet) where the substrate lacks a native peer; keep the Apple-look toolbar exception. |

## Phase L5 — Three-Platform Proof ⏳

| # | Item | Status | Notes |
|---|---|---|---|
| L5.1 | Test apps unmodified | ⏳ Pending | The WinChocolate Phase 11 apps build and run unmodified on macOS, Windows, and Linux; the dual-platform harness (11.6) grows a third target. Verify each app through all three rings before calling it done. |
| L5.2 | Parity gap log | ⏳ Pending | Linux-only gaps (and Wayland-vs-X11 or Pi-only gaps) feed back into this plan the way WinChocolate 11.7 feeds the Windows phases. |

## Phase L6 — Shared-Core Convergence ⏳ (Deferred)

Deferred until WinChocolate's API stabilizes. Sibling-first (Goal 3) means the Apple API is duplicated across the two packages during L1–L5; this phase pays that back by hoisting the platform-neutral parts into one shared core both siblings consume, so the API stops being maintained twice. Do not start until WinChocolate signals API stability.

| # | Item | Status | Notes |
|---|---|---|---|
| L6.1 | Convergence trigger | ⏳ Deferred | Define what "WinChocolate stable enough" means (e.g. Phase 8 modern look at parity, no churn in the `NativeControlBackend` surface for N releases) and confirm before starting. |
| L6.2 | Extract shared core | ⏳ Deferred | Hoist the platform-neutral pieces — AppKit-shaped API, `NativeControlBackend` protocol, in-memory backend, contract tests, composed controls (toolbar/alerts/panels) — into a common core target. |
| L6.3 | Rebase both siblings | ⏳ Deferred | Re-point WinChocolate (Win32 backend) and LinChocolate (Linux backend) at the shared core; delete the duplicated surface. No app-visible API change on either platform. |
| L6.4 | Anti-drift guard | ⏳ Deferred | Ensure the shared contract tests run in all three platforms' CI so the core cannot silently diverge again. |

---

## Maintenance Rules

- Keep this plan separate from `ProjectPlan.md`; LinChocolate items never count toward WinChocolate percentages.
- Until work starts, only revisit this plan when a Windows-side decision would affect the backend boundary — record the consequence here.
- When work starts, adopt the same per-item percentage discipline and milestone-first working method as the WinChocolate plan, and honor the ring rules: no windowing/compositing/perf/packaging item is "done" on a green XQuartz run alone.
- Real-hardware-only findings (Wayland, DPI, keyboard modifiers, Pi GPU/perf) are logged in `NEEDS_HUMAN.md`.
- **Sibling discipline:** while the Apple API is duplicated (L1–L5), any change to the shared-shaped surface should be made compatibly on both siblings, and the `NativeControlBackend` seam kept identical, so Phase L6's extraction stays mechanical. When you feel the pain of syncing by hand, that is the signal WinChocolate may be stable enough to trigger L6 — not a reason to fork the API.

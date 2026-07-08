# LinChocolate — Substrate Decision (Phase L1.1)

**Status:** ✅ Adopted — GTK4, validated on the Ring 1 dev loop (S1/S2/S4). Pi confirmation (S3) is the Phase L8 gate, not a blocker on the decision.
**Date:** 2026-07-07
**Owner decision:** Bobby
**Feeds:** `LinChocolatePlan.md` L1.1 (substrate), and constrains L1.2 (look) and L2.1–L2.5 (toolchain/package). Distribution moved to Phase L5; Pi validation/cleanup to Phase L8.

---

## 1. Recommendation

**Build the LinChocolate backend on GTK 4, driven from Swift through C-interop, with the Cairo renderer as the fallback for the XQuartz dev loop.**

In one line: GTK4 is the only candidate that delivers a *native, modern, theme-following* Linux look (Goal 2) with accessibility, input methods, and dual X11/Wayland support already solved — the parts a hand-rolled backend would spend years reimplementing — while being the toolkit the Raspberry Pi already speaks.

The `NativeControlBackend` protocol is unchanged: GTK4 sits behind it exactly as Win32 sits behind it in WinChocolate. Nothing here touches the AppKit-shaped API surface.

Two sub-decisions are deliberately **left open** and handed to Phase L4 (§5):
1. **libadwaita vs. plain GTK4** — polish-and-opinionated vs. theme-following.
2. **Which Swift binding path** — generated bindings vs. a narrow hand-written module map.

---

## 2. Candidates considered

| Candidate | One-line character | Verdict |
|---|---|---|
| **GTK 4** (+ optional libadwaita) | Modern GNOME-era native toolkit, C/GObject | ✅ **Recommended** |
| **GTK 3** | Mature, lighter, ubiquitous — but a sunsetting look | ⚠️ Fallback only |
| **Custom X11/Wayland + Cairo** | Hand-drawn, à la the Win32 classic backend | ❌ Rejected for Linux |
| Qt | — | 🚫 Ruled out up front (license — plan Hard constraints) |

Non-starters not scored: SDL / FLTK / Dear ImGui (no native look, weak/no accessibility), wxWidgets (wraps GTK anyway — adds a layer, removes nothing).

---

## 3. Criteria & scoring

Criteria come straight from `LinChocolatePlan.md` L1.1 plus the two inherited hard constraints. Score: ● strong · ◐ adequate · ○ weak.

| Criterion (why it matters) | GTK 4 | GTK 3 | Custom Cairo |
|---|:--:|:--:|:--:|
| **Native modern look** (Goal 2 — the whole point of the Linux port) | ● | ◐ | ○ |
| **Theme-following / Pi PIXEL fit** (L1.2) | ● (plain) | ● | ○ |
| **X11 + Wayland coverage** (Pi range needs both) | ● | ● | ○ (own both by hand) |
| **Swift C-interop ergonomics** | ◐ (bindings exist) | ◐ | ● (all C, but you write it all) |
| **Pi-class performance** (aarch64, modest GPU/RAM) | ◐ (GL wants care; Cairo fallback ok) | ● | ● (you control it) |
| **Accessibility** (AT-SPI; the rules doc's ARIA thinking) | ● (built-in) | ● | ○ (reimplement) |
| **Composed-control carryover** from WinChocolate | ○ (use native peers instead) | ○ | ● (GDI→Cairo port) |
| **XQuartz X11 dev loop** (Ring 1) | ◐ (`GSK_RENDERER=cairo`) | ● (Cairo-native) | ● (Xlib/Cairo) |
| **License** (MIT project) | ● (LGPL, dynamic link) | ● | ● (fully clean) |
| **Effort to first usable shell** | ● | ● | ○ (builds a toolkit first) |
| **Longevity of the bet** (2026+) | ● | ○ (frozen/EOL-ward) | ◐ |

The two rows where Custom Cairo "wins" — composed-control carryover and a clean license — are exactly the two that matter *least* here: carryover is a one-time porting convenience, and GTK's LGPL is already fine under dynamic linking. Everything a user actually sees and feels (native look, theme, a11y, Wayland) is where Custom Cairo is weakest.

---

## 4. Rationale

### Why GTK 4
- **It is the native modern look.** Goal 2 says "looks like a modern Linux app," modern-only, no classic fallback. On Linux in 2026 that *is* GTK4 (GNOME's toolkit; libadwaita for the polished HIG look). A hand-rolled renderer can *imitate* it but can't *be* it, and can't follow the user's theme.
- **The hard parts are already solved.** Wayland *and* X11 (via GDK backends), HiDPI, input methods (IME/CJK), drag-and-drop, clipboard, and AT-SPI accessibility ship in the box. These are precisely the items a custom backend underestimates.
- **It's the Pi's own toolkit.** Raspberry Pi OS's desktop and apps are GTK; GTK4 runs on Pi 4/5. We are swimming with the current, not against it.
- **The Swift path is real and endorsed.** Swift.org itself published "Writing GNOME Apps with Swift" (Adwaita for Swift). `rhx/SwiftGtk` (gtk4 branch) is auto-generated from GObject-Introspection and tested against GTK 4.0 → 4.22; `gir2swift` ships a SwiftPM plugin. We are not the first to drive GTK4 from Swift.
- **The XQuartz risk has a known escape hatch.** GTK4 prefers a GL/Vulkan renderer, which is fragile over XQuartz's indirect GL. But GSK's documented ultimate fallback is the **Cairo software renderer** (`GSK_RENDERER=cairo`), which paints fine over plain X11 → XQuartz. Ring 1 uses Cairo; real hardware (Rings 2–3) uses GL/Vulkan. This dovetails with the plan's "green in Ring 1 is necessary, not sufficient" rule.

### Why not GTK 3
GTK3 is lighter, Cairo-native (so friendlier to XQuartz and low-end Pis), and rock-solid. But it is a **sunsetting look**: GNOME and its apps have moved to GTK4/libadwaita, and starting a *new* framework in 2026 on a frozen toolkit spends its whole life looking a step behind — directly against Goal 2. Keep GTK3 as a documented fallback only if a GTK4-on-Pi or GTK4-under-XQuartz blocker appears in the §7 spikes; the Swift bindings (`SwiftGtk`) cover both, so a retreat would be contained.

### Why not Custom X11/Wayland + Cairo
This is the Win32-classic-backend instinct carried to Linux, and it's the wrong instinct here for one blunt reason: **it contradicts Goal 2.** "Native modern look" means matching the desktop the user chose; a bespoke renderer would have to reimplement Adwaita's look, GTK theme parsing, *and* Wayland client plumbing (xdg-shell, client-side decorations, `libinput` seat handling — GNOME ships no server-side decorations), *and* Pango text layout, *and* AT-SPI accessibility. That is a multi-year toolkit project orthogonal to the actual goal (Apple API compatibility). Its one genuine advantage — the WinChocolate composed controls (toolbar/alerts/panels) port GDI→Cairo almost directly — is outweighed many times over. And note: with GTK4 we mostly *don't want* to carry those over — we map to native GTK peers (`GtkHeaderBar`, `AdwMessageDialog`, `GtkPopover`) and get the native look for free. The **Apple-look toolbar** stays the one deliberate hand-drawn exception (inherited from WinChocolate Phase 6), and Cairo-on-GTK4 is available for it.

---

## 5. Deferred to Phase L4 (this decision constrains, doesn't settle)

1. **libadwaita vs. plain GTK4.** libadwaita gives the polished GNOME HIG look but is *opinionated* and resists theming (it hardcodes Adwaita). Plain GTK4 **follows the active system theme** — which is what "look native on the Pi's PIXEL desktop" (L1.2) actually wants. Likely answer: **plain GTK4 as the baseline for theme-following, libadwaita optional** where a GNOME-polished look is desired. Baseline decided in L1.2; final call settled in L4 with a Pi in hand.
2. **Native-peer mapping table.** Which `NS*` control maps to which GTK widget (`NSButton`→`GtkButton`, `NSTextField`→`GtkEntry`/`GtkLabel`, `NSTableView`→`GtkColumnView`, `NSToolbar`→`GtkHeaderBar` except the Apple-look exception, `NSAlert`→`AdwMessageDialog`/`GtkAlertDialog`…). Belongs in the L4.1 parity matrix (new Linux column in `CONTROL_PARITY.md`).

---

## 6. Swift interop path (spike in L2.1)

Three ways to drive GTK4's C/GObject API from Swift, cheapest-to-richest:

1. **Hand-written module map over a narrow C surface.** Mirrors how WinChocolate's Win32 backend uses a hand-rolled User32/Gdi32 FFI instead of importing `WinSDK`. We only need the widgets the backend actually creates — a small surface. Most control; most boilerplate (GObject signals, refcounting, `gpointer user_data` trampolines by hand).
2. **`rhx/SwiftGtk` (gtk4 branch) + `gir2swift`.** Bindings auto-generated from GObject-Introspection, SwiftPM plugin, tracks GTK 4.x closely. Biggest head start; adds a code-gen dependency and a large generated surface.
3. **Adwaita for Swift** (declarative). Great for *writing GNOME apps*, but it's a declarative app framework — an impedance mismatch against our imperative `NativeControlBackend` (create widget → return handle → mutate). Useful as a **reference**, not as the backend's binding layer.

**Lean:** start with (1) a narrow hand-written module map for the first shell (L3.1) — it keeps the seam small and dependency-free, matching the WinChocolate FFI precedent — and evaluate promoting to (2) if the surface grows faster than hand-binding is comfortable. Decide for real in L2.1 after the spike.

---

## 7. Validation spikes

Small, throwaway proofs that de-risk the commitment. **S1, S2, and S4 have passed**, which validates the decision on the dev loop — the substrate is adopted (§Status). **S3 (Pi/Wayland)** remains, and is tracked as the Phase L8 (Pi Cleanup) hardware gate rather than a blocker on the decision.

| Spike | Proves | Ring | Status |
|---|---|---|---|
| **S1 · Hello-GTK4 from Swift in the container** | Swift ↔ GTK4 C-interop builds and opens a window; module-map approach is tolerable | 1 (Mac/Docker) | ✅ **Passed** 2026-07-07 — `swift build` green on GTK 4.14.5 aarch64 (Ubuntu Noble); hand-written module map + `@convention(c)` callback compiled with no fixes. Harness: `LinChocolate/`. |
| **S2 · Same window over XQuartz with `GSK_RENDERER=cairo`** | The Ring 1 dev loop actually shows GTK4 pixels on the Mac | 1 | ✅ **Passed** 2026-07-07 — GTK4 window opened over XQuartz via the Cairo renderer. Required enabling XQuartz TCP (`nolisten_tcp=false` + real restart), `xhost +` (container connects from Docker's NAT IP, not the LAN IP), and `DISPLAY=<host-en0-IP>:0` (`host.docker.internal` resolved IPv6-only and was unreachable). All baked into `run-linux.sh`. |
| **S3 · Same binary on a Pi (Bookworm, Wayland)** | GTK4 builds/runs on aarch64 Pi under labwc/Wayfire at acceptable perf | 3 | ⏳ Pending Pi |
| **S4 · One `NativeControlBackend` method (a button) end-to-end** | The seam is truly backend-swappable: contract test green with the GTK backend | 1 → 2 | ✅ **Passed** 2026-07-07 — 13/13 contract tests green (in-memory backend), including the click-counter driving `NSButton.onAction` through the backend. The same AppKit-shaped demo also renders as a native GTK window (button+label) over XQuartz. Seam proven swappable. |

S2 and S3 together are the crux: they confirm the plan's two-renderer story (Cairo on XQuartz, GL/Vulkan on hardware) holds in practice.

---

## 8. Risks & mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| GTK4 GL renderer flaky/blank over XQuartz | Medium | `GSK_RENDERER=cairo` for Ring 1 (documented fallback); real GL only on Rings 2–3 |
| GObject signal/refcount interop is tedious from Swift | Medium | Narrow hand-written surface first; promote to `SwiftGtk`/`gir2swift` if it grows |
| GTK4 too heavy on the minimum Pi model | Low–Med | L8.2 sets the minimum supported Pi; GTK3 documented fallback if a floor is hit |
| libadwaita's theme-resistance fights Pi PIXEL look | Medium | Baseline on **plain GTK4** (theme-following); libadwaita opt-in — settle in L1.2 |
| Binding code-gen dependency rots | Low | Hand-written map has zero external gen; keep it the default until pain justifies more |

---

## 9. Sources

- [Swift.org — Writing GNOME Apps with Swift (Adwaita for Swift)](https://www.swift.org/blog/adwaita-swift/)
- [rhx/SwiftGtk — GTK 3/4 Swift wrapper (gtk4 branch, GObject-Introspection)](https://github.com/rhx/SwiftGtk)
- [GTK4 — Running and debugging GTK Applications (GSK_RENDERER, renderers)](https://docs.gtk.org/gtk4/running.html)
- [makoni/swift-adwaita — Swift 6 GTK4/libadwaita wrapper](https://github.com/makoni/swift-adwaita)
- [swift-arm64 — Swift for Arm64/aarch64 SBCs incl. Raspberry Pi](https://futurejones.github.io/swift-arm64/)
- [Swift on Raspberry Pi: Building Natively and Cross Compiling (SwiftToolkit.dev)](https://www.swifttoolkit.dev/posts/r-pi)

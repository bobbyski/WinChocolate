# Unified Chocolate — Build Plan

## Summary

WinChocolate (Win32) and LinChocolate (GTK4) are today two separate packages
holding two parallel AppKit-shaped layers. This plan merges them onto **one
shared core** — a single AppKit surface compiled for both platforms, with the
platform differences expressed as compile-time conditionals behind the existing
`NativeControlBackend` seam.

Both must keep running throughout. Windows is the mature side and never moves:
the shared core *is* today's WinChocolate layer, so the Windows build path is
unchanged at every step, and Linux migrates onto it incrementally.

`import WinChocolate` and `import LinChocolate` both keep working (thin façade
targets), so the imports-only promise, the frozen demo's 3-way import switch,
and every downstream consumer (ActiveUI, WinSwiftUI, WinSwiftData) are untouched
by this refactor.

Related plans: `Docs/ProjectPlan.md` (WinChocolate), `Docs/LinChocolatePlan.md`
(Linux), `Docs/LinChocolateControlParity.md` (GTK control map).

## Project Goals

1. **One AppKit layer, two backends.** Every line that is not genuinely Win32 or
   GTK work lives once, in `ChocolateKit`. A `#if` outside the four sanctioned
   seams (§C1–C4) is a bug to be fixed by widening the backend protocol.
2. **No regression on Windows.** Every phase is gated on the Windows build plus
   the full contract suite staying green.
3. **Linux gains the finished behavior.** Linux inherits ~29k lines of completed
   AppKit work (drawn tables, toolbars, sheets, nib loading, accessibility)
   rather than reimplementing it.
4. **The public promise is unchanged.** Product names, import switch, and
   downstream APIs survive the merge intact.

---

## Dashboard

```text
Overall Progress                              ████████████████░░░░░░░░░░   61%  (17 / 28 items)

Phase 0 · Packaging Spike                     ██████████████████████████  100%  ✅ Complete  (~40–70k tokens)
Phase 1 · Shared Core In Place                ██████████████████████████  100%  ✅ Complete  (1.3 + 1.6 closed 08-05)
Phase 2 · Foundation Parity                   ██████████████████████████  100%  ✅ Complete  (~90k tokens actual)
Phase 3 · Linux Bring-Up On Shared Core       ███░░░░░░░░░░░░░░░░░░░░░░░   13%  🔄 In Progress (3.1 done; rest needs Linux)
Phase 4 · Retire The Duplicates               ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending   (~60–120k tokens)
Phase 5 · GTK Parity Backlog                  (rolling intake)  ⏳ Standing (tracked separately, not in Overall)

Estimated total to Phase 4 (one source tree, both platforms running): ~0.9M–1.9M tokens
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; ⏸️ Deferred &nbsp;|&nbsp; 🚫 Blocked

---

## Feasibility evidence (measured 2026-07-26)

The two frameworks were built to the *same architecture*, which is what makes
this a merge rather than a rewrite.

| | WinChocolate | LinChocolate |
|---|---|---|
| Total | **42,891** lines / 142 files | **16,492** lines / 77 files |
| Backend (`Native/`) | 13,547 (Win32) | 6,719 (GTK) |
| AppKit layer (everything else) | **~29,344** | ~9,773 |
| Backend protocol | `NativeControlBackend`, **178** members | same name, **150** members |
| Foundation | `WinFoundation` (own package) | real `Foundation` |
| Platform leaks **outside** `Native/` | **0 files** | **1 file** (`GLibMainActorExecutor`) |
| Backend guard already present | 24/25 files `#if os(Windows)` | `#if canImport(CGTK)` |

Three facts decide the design:

1. **The seam already exists in the same shape** — both declare
   `public protocol NativeControlBackend: AnyObject`, at the same layer, with the
   same ownership split. No abstraction has to be invented.

   ⚠️ **Corrected 2026-07-26 (measured, Phase 1).** An earlier draft of this
   plan claimed Lin's protocol was a strict subset of Win's (“168 ⊂ 189”). That
   was inferred from member *counts* without comparing member *names*, and it is
   **wrong**. Comparing the actual member sets:

   | | count |
   |---|---|
   | Members in **both** | **46** |
   | In the shared core only (GTK must gain) | **132** |
   | In the GTK protocol only (no counterpart in the core) | **104** |

   They are two *different* protocols that share a name and 46 members. The
   designs differ in kind, not just coverage: the core registers callbacks
   (`registerMouseDownAction`, `registerTableEditAction`), while GTK's sets
   closures per widget (`setClickAction`, `setDrawHandler`, `setContentView`).
   The consequence is in §3.2 and Phase 3 — the GTK backend must be **re-fronted
   onto the core's protocol**, not merely widened.

   ✅ **Follow-up, measured 2026-08-05.** That re-fronting turns out to be
   *already done structurally*, and the two measurements do not conflict —
   they are about different objects. The numbers above compare the **LinChocolate
   package's own protocol** with the core's. The GTK backend **copied into
   `ChocolateKit`** (item 1.5) declares `: NativeControlBackend`, which inside
   that module resolves to the *core* protocol. It satisfies 48 of the core's 178
   requirements directly and inherits the rest from defaults; its ~104
   Lin-protocol-only members simply became ordinary extra methods rather than
   protocol requirements. So the re-fronting is a **behavioral** job (fill in the
   130 defaults), not a structural one. See the Phase 3 measurement table.
2. **The seam is honest.** Zero Win32 references leak above `Native/`; exactly
   one GTK reference does. The AppKit layer is genuinely platform-free already.
3. **Win's layer is a superset.** Every shared-name file is larger on the Windows
   side (`NSWindow` 1148 vs 173, `NSTableView` 1114 vs 301). The 60 shared-name
   files are *independent implementations*, not drifted copies — so
   reconciliation is "adopt Win's, delete Lin's", not a three-way merge.

---

## Target architecture

```text
ChocolateKit                    ← the shared core
  |
  |-- Appearance/ Application/ Controls/ Views/ Windows/ Layout/ Menus/ Nib/ …
  |       `-- one AppKit surface, compiled for every platform
  |
  `-- Native/
      |-- NativeControlBackend.swift          ← the seam (shared protocol)
      |-- InMemoryNativeControlBackend.swift  ← shared, headless tests
      |-- Win32/    #if os(Windows)
      `-- GTK/      #if canImport(CGTK)

WinChocolate   ← façade target, Windows only:  @_exported import ChocolateKit
LinChocolate   ← façade target, Linux only:    @_exported import ChocolateKit
```

The façade targets are ~5 lines each. They exist purely so `import WinChocolate`
/ `import LinChocolate` and `canImport(...)` keep resolving.

### The four sanctioned conditionals

| # | Concern | Switch | Where |
|---|---|---|---|
| C1 | Foundation flavor | `#if os(Windows)` → `WinFoundation`, else `Foundation` | `FoundationBridge.swift` |
| C2 | Backend implementation | `#if os(Windows)` / `#if canImport(CGTK)` | `Native/Win32/`, `Native/GTK/` |
| C3 | Backend installation | which backend `NSApplication` installs | one function |
| C4 | Main-thread executor | Win32 pump vs `GLibMainActorExecutor` | one file behind a shared hook |

---

## Phase 0 — Packaging Spike ✅ 100%

Prove the one packaging unknown before moving any code: can a single manifest
carry a GTK `systemLibrary` that only resolves on Linux? Decide here, not later.

| # | File | Status | Notes |
|---|------|--------|-------|
| 0.1 | `Package.swift` | ✅ Done | Single root manifest; `ChocolateKit` target over today's WinChocolate sources |
| 0.2 | `Package.swift` | ✅ Done | `CGTK`/`CGTKCompat` depended on via `.when(platforms: [.linux])` — mechanism already used here for `WinChocolate` |
| 0.3 | — (verification) | ✅ Done | **Gate:** Windows builds + full contract suite green |
| 0.4 | `LinChocolate/run-linux.sh` | ✅ Done | **Settled 2026-07-26: there is no local Linux loop.** WSL does not work under Parallels on this VM, so Linux is verified off-box by the user when a phase is ready. Confirm `run-linux.sh` is the command to hand over, and that the manifest change (0.2) does not break it |

**Exit:** if conditional `systemLibrary` resolution fails on Windows, fall back
to two manifests sharing one source directory — and record that decision here.

---

## Phase 1 — Shared Core In Place ✅ 100%

Move, don't rewrite. `git mv` of 29k lines is nearly free; re-typing any of it is
not. Windows keeps compiling from the same code, at a new path.

| # | File | Status | Notes |
|---|------|--------|-------|
| 1.1 | `Sources/ChocolateKit/**` | ✅ Done | `git mv` from `Sources/WinChocolate/**` — pure move, zero code edits |
| 1.2 | `Sources/WinChocolate/WinChocolate.swift` | ✅ Done | Façade: `@_exported import ChocolateKit`, Windows only |
| 1.3 | `Sources/LinChocolate/LinChocolate.swift` | ✅ Done | Façade: `@_exported import ChocolateKit`. The deferral was about one unverified assumption — whether `canImport(LinChocolate)` would stay false on Windows, since the demo tests it *first* and would otherwise capture the Windows build. **Tested, not assumed:** with the target depended on only under `.when(platforms: [.linux])`, SwiftPM prunes it entirely on Windows — no `LinChocolate.swiftmodule` is produced, so `canImport` is false and the demo still resolves to `WinChocolate` |
| 1.4 | `ChocolateKit/Runtime/FoundationBridge.swift` | ✅ Done | C1 switch: `WinFoundation` on Windows, real `Foundation` elsewhere |
| 1.5 | `ChocolateKit/Native/GTK/**` | ✅ Done | Copy GTK backend in, already `#if canImport(CGTK)` guarded |
| 1.6 | `ChocolateKit/Native/NativeControlBackend.swift` | ✅ Done (already satisfied) | Default protocol extension so a partially-ported backend always compiles. **Measured 2026-08-05: all 178 protocol requirements already carry a default** — 0 are mandatory. The work this item anticipated was already in the file, and the defaults degrade gracefully (return `nil`/ignore) rather than blindly no-op'ing. See the Phase 3 measurement below for what this means |

**Gate:** ✅ **Met on Windows 2026-07-26** — `swift build` clean, full contract
suite passed, demo launches with its usual 642 controls, all through the
`WinChocolate` façade. Linux is unverified by construction (§Verification model).

**Two items were deliberately deferred, with reasons:**

- **1.3 (LinChocolate façade)** — a `LinChocolate` module that is importable on
  Windows would make the shared demo's `#if canImport(LinChocolate)` branch win
  on the *wrong* platform, because that branch is tested first. The façade must
  therefore be Linux-only, which is only meaningful once Linux actually builds.
  Added in Phase 3.
- **1.6 (no-op defaults)** — its purpose is to keep a partially-ported GTK
  backend compiling. That has no effect yet: the GTK backend does not conform to
  the core's protocol *at all* (46 of 178 members), so nothing is unblocked by
  adding defaults now. Meanwhile defaults have a real cost on Windows: they would
  let `Win32NativeControlBackend` silently lose a method without a compile error.
  Moved into Phase 3, where it lands together with the re-fronting it serves.

---

## Phase 2 — Foundation Parity ✅ 100%

The shared core must compile against `WinFoundation` *and* real `Foundation`
from identical sources. This is the largest correctness risk in the plan.

| # | File | Status | Notes |
|---|------|--------|-------|
| 2.1 | `Docs/FoundationParityLedger.md` | ✅ Done | Written. Reconciled / accepted / verified-same / open-for-Phase-3, each with its reason |
| 2.2 | `WinFoundation/**` | ✅ Done | `NSArray` stays an alias — a real class needs `_ObjectiveCBridgeable`, which needs ObjC interop. **Measured: the core never uses it** (0 files; `NSString`/`NSURL` appear in comments only), so the alias is app-surface only. The two demo warnings are noise, not breakage — ledger §Accepted |
| 2.3 | `WinFoundation/**` | ✅ Done | `Locale`/`TimeZone` gained `Hashable` + `Codable` (Foundation's identifier-keyed form); `Data`/`URL` `Codable` landed earlier. `DateFormatter` now inherits `Formatter`; formatters are `open`, as Foundation's are |
| 2.4 | `WinFoundation/**` | ✅ Done | `URL` now survives a round-trip through its own `absoluteString` — the separator asymmetry silently corrupted any persisted URL. `Timer`/`RunLoop`/`DateFormatter`/`JSONEncoder` behavior was settled in Phase 7/8 work and re-verified here |
| 2.5 | `Tests/…/main.swift` | ✅ Done | `testFoundationTypesMatchApplesShapes()` pins every 2.2–2.4 fix; full suite green |

**Gate:** `ChocolateKit` compiles on Linux (real Foundation) and Windows
(WinFoundation) from one source; contract suite green on both. *Windows half is
green. The Linux half is by construction, not by observation* — it cannot be run
here, so it is a Phase 3 entry criterion, and the ledger's §Open list is what to
check first when Linux does build.

**Why this came in ~90k against a 250–500k estimate.** The estimate assumed the
core leaned on the divergent aliases and would need rewriting. Measuring instead
of assuming showed it does not use them at all — `NSArray` 0 files,
`NSString`/`NSURL` in comments only — so Phase 2 collapsed from "rewrite the
core's Foundation usage" to "fix five specific divergences in WinFoundation."
The lesson generalizes to the remaining estimates: **measure the usage before
sizing the work.** Phase 3's range should be treated as unmeasured until the
GTK backend's 132 members are actually diffed against the core protocol.

---

## Phase 3 — Linux Bring-Up On Shared Core 🔄 13%

Bring Linux up on the shared layer in dependency order, deleting each
LinChocolate duplicate as its Windows counterpart takes over.

| # | File | Status | Notes |
|---|------|--------|-------|
| 3.1 | `ChocolateKit/Application/NSApplication.swift` | ✅ Done | C3: `#elseif canImport(CGTK)` selects `GTKNativeControlBackend()`. Until now Linux fell through to the **headless in-memory test backend** — the GTK backend existed and conformed, but nothing selected it, so a Linux app would have launched with no GUI at all |
| 3.2 | `ChocolateKit/Native/GTK/GLibMainActorExecutor.swift` | ⏳ Pending | C4: main-actor executor / run loop behind the shared hook |
| 3.3 | `ChocolateKit/Views/NSView.swift`, `Windows/NSWindow.swift` | ⏳ Pending | Foundation of everything else; GTK backend widened as needed |
| 3.4 | `ChocolateKit/Controls/{NSControl,NSButton,NSTextField}.swift` | ⏳ Pending | First controls running on GTK through the shared layer |
| 3.5 | `ChocolateKit/Controls/**` | ⏳ Pending | Remaining controls, priority order from `LinChocolateControlParity.md` |
| 3.6 | `ChocolateKit/Views/{NSScrollView,NSSplitView,NSClipView}.swift` | ⏳ Pending | Containers + tiling/adjust semantics |
| 3.7 | `ChocolateKit/Nib/**` | ⏳ Pending | Nib/xib loading on the shared core |
| 3.8 | `LinChocolate/Sources/LinChocolateDemo`, `Demo/DemoApplication` | ⏳ Pending | **Gate:** Lin demo *and* the frozen demo run on Linux; contract suite green |

### Phase 3 measured, 2026-08-05 (applying Phase 2's lesson: measure before sizing)

The phase was scoped around a structural fear — "the GTK backend must be
re-fronted onto the core protocol: 132 members." Measuring instead of assuming:

| Question | Answer |
|----------|--------|
| Does the GTK backend conform to the core protocol? | **Yes, already** — `GTKNativeControlBackend: NativeControlBackend`, declared at line 22 |
| Protocol requirements | 178 |
| Requirements with **no** default (mandatory) | **0** — every one is defaulted |
| Requirements GTK implements itself | 48 |
| Requirements falling through to defaults | 130 |
| Core files outside `Native/Win32/` using Win32 types | **0** (three matches were comments) |
| Unguarded Win32 files that would break a Linux compile | **1**, `Win32Tooltips.swift` — now guarded |

**What this changes.** The structural risk is gone: nothing is missing that
would stop the module from *compiling*, and the one file that would have
broken it is fixed. Phase 3 is therefore not "re-front a backend" but **"fill in
130 gracefully-degrading defaults, in priority order"** — the same shape as the
Windows control work, and individually verifiable.

**What it does not change.** This is still static analysis, not a Linux build.
Name-level comparison cannot catch a signature mismatch between a GTK method and
the protocol requirement it means to satisfy — that surfaces only when Linux
compiles. Treat the first Linux build as the real gate, with the Foundation
ledger's §Open list as the second thing to check.

---

## Phase 4 — Retire The Duplicates ⏳ 0%

Deletions are nearly free; the cost here is test consolidation and docs.

| # | File | Status | Notes |
|---|------|--------|-------|
| 4.1 | `LinChocolate/Sources/LinChocolate/{Controls,Views,Windows,Layout,…}` | ⏳ Pending | Delete the parallel AppKit layer (~9.7k lines) |
| 4.2 | `LinChocolate/Sources/LinChocolate/Compat/**` | ⏳ Pending | Delete `AppKitCompat`/`ConcurrencyCompat`/`ControlCompat`/`DemoCompat`/`EnumCompat` (~1.7k lines) — Rule One bans these |
| 4.3 | `Tests/WinChocolateContractTests/main.swift` | ⏳ Pending | Fold `LinChocolate/Tests` into the shared suite |
| 4.4 | `Sources/ChocolateGraphics/**` | ⏳ Pending | Consolidate `WinCoreGraphics` + Lin's `CGImage`/`CGCompat` |
| 4.5 | `Docs/Architecture.md`, `Docs/ProjectPlan.md`, `Docs/LinChocolatePlan.md` | ⏳ Pending | Architecture doc updated for the merged shape; plans cross-linked |

**Gate:** one source tree; both platforms build, run, and pass.

---

## Phase 5 — GTK Parity Backlog ⏳ Standing

Rolling intake, tracked separately (not counted in Overall), exactly like
Phase 14 in `ProjectPlan.md`. Work the no-op list from §1.6 down by priority
using `LinChocolateControlParity.md`; the frozen demo becomes the Linux
acceptance test, as it already is on Windows.

---

## Cost (tokens)

**~0.9M–1.9M tokens** to Phase 4, plus the open-ended Phase 5 backlog.

### Unit costs this estimate is built from

| Operation | Typical cost |
|---|---|
| Reading a 1,000-line Swift file | ~12k tokens (~12 tokens/line) |
| One `Edit` (old + new string) | ~0.3–0.8k |
| One filtered `swift build` result | ~0.2–2k (error-dependent) |
| One contract-suite run | ~0.3k when green, far more when not |
| `git mv` / `rm` of a whole directory | **~0.1k — moves are nearly free** |
| One build→fix→rebuild iteration | ~3–10k |

### Where the tokens go

| Phase | Estimate | Dominant driver |
|---|---|---|
| 0 | 40–70k | manifest edits + build iterations |
| 1 | 120–200k | reading both protocols (1,000 + 697 lines) to diff members; ~21 stubs. Moves are free |
| 2 | 250–500k | **compile-error-driven iteration** against real Foundation |
| 3 | 400k–1M | **iteration**: per control × build × run × fix, plus GTK widening |
| 4 | 60–120k | deletions free; test consolidation is not |

### The planning insight

Cost is dominated by **build–fix iteration cycles**, not by reading or writing
code. Two consequences for sequencing:

- **Prefer mechanical moves to rewrites.** Phase 1 is cheap precisely because it
  moves rather than edits.
- **Cut iteration count, not file count.** Batch related fixes before each build,
  and use the headless in-memory backend (no GTK/Win32 needed) to validate logic
  without a platform build.

---

## Verification model (settled 2026-07-26)

**There is no local Linux loop.** WSL does not work under Parallels on this VM,
so every Linux build and run happens off-box, by the user, when a phase is ready
to hand over. This is a structural constraint, not a Phase 0 unknown, and it
reshapes how the work is done:

| Layer | Verified where | Cost of a cycle |
|---|---|---|
| Windows build + demo | here, continuously | seconds |
| Contract suite (in-memory backend, no GTK/Win32) | here, continuously | seconds |
| **Linux compile** | off-box, batched | a user round-trip |
| **GTK runtime behavior** | off-box, batched | a user round-trip |

**Strategy that follows:**

1. **Make Linux compile-clean by construction, not by iteration.** The no-op
   default extension (1.6) exists precisely so the Linux build cannot fail on a
   missing protocol member. Anything that would only be caught by a Linux
   compiler must instead be caught by review + the shared contract suite.
2. **Push everything provable onto the in-memory backend.** It needs neither GTK
   nor Win32, so layout, geometry, selection, nib decoding, and Foundation
   parity (Phase 2) are all verifiable *here*, on Windows, for both platforms.
3. **Batch the hand-offs.** Aim for one Linux verification per phase, not per
   control — each hand-off should arrive with a single command
   (`LinChocolate/run-linux.sh`) and an explicit list of what to look at.
4. **Expect Phase 3 to widen, not to fail.** Without local iteration, Phase 3's
   estimate is dominated by hand-off latency rather than tokens; the token range
   holds, but wall-clock depends entirely on how often Linux can be run.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Conditional `systemLibrary` won't resolve on Windows | Medium | High — blocks single manifest | Decide in Phase 0; fallback = two manifests over one source dir |
| WinFoundation ≠ Foundation semantics | **High** | High — silent behavior drift | Parity ledger (2.1) + a contract test per fix |
| GTK backend can't satisfy richer AppKit semantics | Medium | Medium — Linux features degrade | No-op defaults (1.6); prioritized backlog; never block the build |
| Linux regressions vs today's LinChocolate | Medium | Medium | Keep the old tree on a branch until Phase 4's gate passes |
| Merge churn breaks Windows | Low | **Critical** | Windows path never changes; every phase gated on the Windows suite |
| Concurrency model mismatch (GLib executor vs Win pump) | Medium | Medium | Isolate as C4 behind one hook; contract-test timer/run-loop behavior on both |
| **No local Linux loop** (WSL fails under Parallels on this VM) | **Certain** | **High** — no tight iterate-on-Linux cycle | Compile-clean by construction (§Verification model); batch Linux runs into few hand-offs; lean on the headless in-memory backend |

---

## Decisions needed before starting

1. **Core module name** — `ChocolateKit` proposed (façades keep the public
   `WinChocolate`/`LinChocolate` names either way).
2. **Repo shape** — single root package (proposed) vs keeping `LinChocolate/` as
   a nested package pointing at shared sources.
3. **Policy change** — the standing rule is *"don't fix LinChocolate; note it in
   DEMO_CHANGES.md."* This plan necessarily edits LinChocolate; that rule must be
   lifted for this work.
4. **Linux verification** — is `run-linux.sh` / `run-wsl.bat` / Docker a working
   loop today? Phases 2–4 are unverifiable without it (Phase 0.4).

---

## Human review

Added to `NEEDS_HUMAN.md`: the GTK backend arrives as a **single 4,789-line
file** (plus `InMemoryNativeControlBackend` at 1,216 and `AppKitCompat` at 832),
well past the 500-line guideline. Splitting it is deferred until after Phase 3
so the file stays diffable against LinChocolate's history during bring-up.

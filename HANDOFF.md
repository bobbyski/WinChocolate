# HANDOFF — Linux work for the AI on the docker instance

**Written 2026-08-05 from the Windows VM.** Everything below is uncommitted work
in this tree, verified on Windows, **never built on Linux**.

Read [§0](#0-read-this-before-you-run-anything) first. It contains the one fact
that decides whether anything you do here is meaningful.

---

## 0. Read this before you run anything

**`LinChocolate/run-linux.sh` does NOT test the merge.** It sets
`-w /work/LinChocolate`, so it builds `LinChocolate/Package.swift` — a manifest
with **zero** references to `ChocolateKit`. It compiles `Sources/LinChocolate`,
the *pre-merge* 77-file AppKit layer. A green run there is a green run of the
old code.

Use the new runner at the repo root, which builds the merged package:

```bash
./run-linux.sh --tests            # headless contract suite (no display needed)
./run-linux.sh                    # WinChocolateDemo — the frozen demo, merged tree
./run-linux.sh RunLoopDemo        # run loop + timers app
./run-linux.sh --shell            # interactive container shell
./run-linux.sh WinChocolateDemo --page 3 --dark    # args pass through
```

It is deliberately **command-compatible** with `LinChocolate/run-linux.sh` —
same flags, same XQuartz handling, same env-var forwarding, same image. The only
material difference is `-w /work` instead of `-w /work/LinChocolate`, so
`swift build` picks up the root `Package.swift`.

Keep the old script. Running both is the point: old = known-good baseline,
new = the merge. A regression is "old passes, new fails".

---

## 1. What changed on Windows (uncommitted)

Windows is **green throughout**: `swift build` clean, full contract suite
passing, demo launching and running.

### The merge (Unified Chocolate plan, `Docs/UnifiedChocolatePlan.md`)

| Area | State |
|---|---|
| `Sources/ChocolateKit/**` | The shared core — 142 files `git mv`d from `Sources/WinChocolate/**`. Win32 and GTK backends both live under `Native/`. |
| `Sources/WinChocolate/WinChocolate.swift` | Windows façade: `@_exported import ChocolateKit` |
| `Sources/LinChocolate/LinChocolate.swift` | **NEW** Linux façade, same one line. Depended on only under `.when(platforms: [.linux])` |
| `Package.swift` | Root manifest carries `CGTK`/`CGTKCompat` (Linux-only), `ChocolateKit`, both façades, demos |
| Phase 0,1,2 | ✅ complete · Phase 3 | 🔄 13% |

**Phase 3.1 landed and matters to you:** `NSApplication.init()` now selects the
backend as Win32 → `#elseif canImport(CGTK)` → **GTK** → in-memory. Before this,
Linux fell through to the *headless test backend*, so a Linux app would have
launched with **no GUI at all**. This has never been executed.

### Foundation parity (Phase 2, `Docs/FoundationParityLedger.md`)

Fixed, each pinned by a contract test: `DateFormatter` now inherits `Formatter`;
`NSNib.instantiate` takes `inout NSArray?` (AppKit's exact signature — this one
**would not have compiled on Linux** before); `URL` survives a round-trip through
its own `absoluteString`; `Locale`/`TimeZone` gained `Hashable`+`Codable`.

Measured: the shared core **never uses** the divergent aliases (`NSArray` 0
files, `NSString`/`NSURL` comments only), so `WinFoundation`-vs-real-`Foundation`
type identity is app-surface only.

### AppKit faithfulness (`Docs/AppKitFaithfulnessIssues.md`, "Round 6")

- `NSPathControl` re-parented `NSTextField` → **`NSControl`** (AppKit's shape).
- Panels are now **owned windows**. This widened the backend protocol with
  `setWindowParent(_:for:)` — **and the GTK backend already implemented it**
  (`gtk_window_set_transient_for`); it just wasn't a protocol member. Your side
  should satisfy this requirement with no new code.
- Title-bar close now ends a modal session in the *core*. Win32 got away without
  it because its modal loop also guards on `IsWindow`; **GTK's does not**, which
  is where the bug was originally reported. Worth an explicit check.

---

## 2. What you need to do, in order

### Step 1 — baseline the OLD tree (5 min, do not skip)

```bash
cd LinChocolate && ./run-linux.sh RealDemo
```

Confirms the machine still works and gives you the before-picture. If this
fails, stop — the problem is environmental, not the merge.

### Step 2 — headless suite on the MERGED tree

```bash
./run-linux.sh --tests
```

**This is the highest-value single command in this document.** It builds
`ChocolateKit` against *real corelibs-foundation* for the first time ever and
runs the contract suite on the in-memory backend — no GTK, no display. It
isolates "does the shared core compile and behave on Linux" from every GTK
question.

Expect compile errors. That is the point. See §3 for what to fix and what to
leave alone.

### Step 3 — the frozen demo on the merged tree

```bash
./run-linux.sh
```

The headline test: `Demo/DemoApplication/main.swift` — the same file Windows
compiles, unmodified — running on Linux through `LinChocolate` → `ChocolateKit`
→ GTK. This is the imports-only promise.

### Step 4 — report back

Write findings into `DEMO_CHANGES.md` (demo-side) or
`Docs/AppKitFaithfulnessIssues.md` (framework-side), and update the Phase 3 table
in `Docs/UnifiedChocolatePlan.md`. Include the actual error text, not summaries.

---

## 3. Rules for fixing what breaks

These are project rules, not preferences. Breaking them costs more than the bug.

1. **Never add a `#if` to the shared core** to paper over a difference. The only
   sanctioned conditionals are the four in `Docs/UnifiedChocolatePlan.md`
   (Foundation flavor, backend implementation, backend installation, main-thread
   executor). A fifth one means the backend protocol needs widening instead.
2. **Never edit `Demo/DemoApplication/**`.** It is the frozen, AppKit-correct
   source of truth — it must compile unmodified against real AppKit on macOS.
   If the demo fails, **the framework is wrong**. The only permitted edit is the
   import switch at the top.
3. **No shims.** If Apple's API doesn't exist, implement it; don't add a
   convenience the demo would then depend on.
4. **Check the GTK backend before writing new code.** It has ~104 members with no
   counterpart in the core protocol. Several are solutions the core can't reach
   because they aren't protocol members — `setWindowParent` was exactly that.
   Lifting one to the seam fixes both platforms at once.
5. **Prefer widening `NativeControlBackend`** (with a graceful default) over
   special-casing. All 178 requirements currently have defaults, so adding one
   cannot break Windows.

### Likely failure points, ranked

1. **`Sources/ChocolateKit/Runtime/FoundationBridge.swift`** — picks
   `WinFoundation` on Windows, real `Foundation` elsewhere. Anything Windows-only
   in `WinFoundation` that the core touches surfaces here.
2. **The ledger's §Open list** (`Docs/FoundationParityLedger.md`) — `@Sendable`
   on `Timer` blocks, `Bundle` resource lookup, `String(contentsOf:)` encodings,
   `ProcessInfo`. These were *identified but not settleable on Windows*.
3. **GTK backend signature mismatches.** It declares conformance to
   `NativeControlBackend`, and name-level analysis says 48 of 178 members match —
   but names aren't signatures. Mismatches appear only when Linux compiles.
4. **`Sources/ChocolateKit/Native/GTK/GLibMainActorExecutor.swift`** — conditional
   C4, main-actor executor, `#if canImport(CGTK)`.

---

## 4. Known-good environment facts

From the Windows-side WSL1 investigation today (different machine, but the
toolchain facts carry):

- Swift **6.3.2**, GTK4 **4.6.9** — this GTK predates
  `G_APPLICATION_DEFAULT_FLAGS`; use `G_APPLICATION_FLAGS_NONE` (or `0`).
- The Dockerfile already sets the right runtime env: `GSK_RENDERER=cairo`,
  `GDK_DISABLE=gl`, `GTK_A11Y=none`, animations off. Software rendering over
  XQuartz needs all of it.
- **Resource staging: copy `Resources/*` wholesale**, never a list of extensions.
  Enumerating `*.bmp`/`*.png` is exactly how `DemoNibPanel.xib` silently stopped
  being staged on Windows — clean build, "nib not found" at runtime. The new
  `run-linux.sh` copies the whole folder.

### If a build appears to hang

Learned the hard way today: **one hung compiler spinning at 97% CPU starves the
box, and every measurement taken afterwards also looks like a hang.** Before
timing anything, assert the process table is clean:

```bash
pgrep -f 'swift-frontend|swiftc |swift-build|swift-package'
```

Must be empty. A defunct `swift-frontend` child with the driver spinning is the
signature. Kill leftovers first; a measurement on a starved machine is worthless.

### What the WSL1 investigation actually established (2026-08-05)

Relevant to you because it tells you which failures are *environmental* and which
would be real. A staged ladder (`LinChocolate/Tools/wsl-stage-tests.sh`,
`wsl-stage4-swift-gtk.sh`, `wsl-direct-target-build.sh`) measured, on Windows/WSL1:

| Test | Result |
|---|---|
| `swiftc` hello world | ✅ ~2s |
| X11 window from C / from **Swift** | ✅ both mapped |
| GTK4 window from C / from **Swift** | ✅ both mapped, ~1s |
| `swift package dump-package` | ✅ <5s (clean machine) |
| **Typecheck all 77 LinChocolate files** | ✅ **exit 0, ≤15s** |
| **Whole-module compile → `libLinChocolate.so` (4.2 MB)** | ✅ **exit 0, ≤10s** |
| `swift build --product LinChocolateDemo` | ❌ **hangs**, zombie `swift-frontend`, 0 objects |

So **the LinChocolate sources are fine** — they compile in ~25s with `swiftc`.
Only SwiftPM's per-file driver hangs, and only under WSL1's process emulation.
The prior "WSL1 is a dead end / Signal 5 / DrvFs locks" conclusion was **wrong**;
it reproduced on the native filesystem, and the real mechanism is that one hung
compiler starves the VM so every later measurement also looks hung.

**Expect none of this in docker** — real Linux, real `fork`/`wait`. If you *do*
see the zombie-frontend signature, `wsl-direct-target-build.sh` is a working
swiftc-direct recipe (module map for `CGTKCompat`, `-wmo`, link `cgtkcompat.o`).

Not established: linking a demo executable against `libLinChocolate.so` on WSL1.
That run was killed at 734s by an unrelated cleanup, so it is **inconclusive** —
neither a pass nor a failure. Don't read it either way.

---

## 5. Open decision that blocks Phase 4

**Decision #2, repo shape.** `LinChocolate/Package.swift` still builds the old
implementation. Until it points at `ChocolateKit` — or is retired for the root
manifest — the old docker path keeps testing pre-merge code.

SwiftPM target paths cannot escape the package root, so the nested manifest can
only reach `ChocolateKit` via `.package(path: "..")` plus a new `LinChocolate`
**product** in the root manifest.

**Do not decide this unilaterally** — it is tracked as plan item 4.0 and is
Bobby's call. The new root `run-linux.sh` sidesteps it entirely for now, which is
why it exists.

---

## 6. Quick reference

| Want | Command |
|---|---|
| Old baseline (pre-merge) | `cd LinChocolate && ./run-linux.sh RealDemo` |
| **Merged core, headless** | `./run-linux.sh --tests` |
| **Merged core, frozen demo** | `./run-linux.sh` |
| Merged, run-loop demo | `./run-linux.sh RunLoopDemo` |
| Shell in the container | `./run-linux.sh --shell` |
| Plan + phase status | `Docs/UnifiedChocolatePlan.md` |
| Foundation divergences | `Docs/FoundationParityLedger.md` |
| Framework bug log | `Docs/AppKitFaithfulnessIssues.md` |
| Demo-side change log | `DEMO_CHANGES.md` |

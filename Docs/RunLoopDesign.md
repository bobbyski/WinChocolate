# RunLoop design (WinFoundation)

**Status: BUILT and verified (2026-07-16).** Approved and implemented as designed
below, with one correction the design got wrong (see *"Both keep working"*). The
**frozen demo is byte-unchanged** and live-verified; a **new RunLoopDemo** exercises
the run loop directly. Files: `WinFoundation/Sources/WinFoundation/RunLoop.swift`,
`Timer.swift`; `Sources/WinChocolate/Native/Win32/Win32RunLoopPump.swift`;
`NSApplication.run()` now drives `RunLoop.main.run()`; `Demo/RunLoopDemo/`. Pinned by
`testWinFoundationRunLoopAndTimer`.

### Correction to the plan below: the two-Timers question

The plan said "keep both Timers." That looked risky because WinChocolate
`@_exported import`s WinFoundation, so a second `Timer` seemed like it would make
the demo's `Timer.scheduledTimer` ambiguous. **A two-module experiment proved it
does not:** a name a module declares *directly* shadows the same name it re-exports.
So the frozen demo's `import WinChocolate` sees `WinChocolate.Timer` (SetTimer-based,
unchanged), while a package importing WinFoundation without WinChocolate (WinCombine)
sees the new `WinFoundation.Timer` — no ambiguity. Both Timers coexist exactly as the
plan intended. `WinFoundation.Timer` is not an `NSObject` subclass (NSObject lives up
in WinChocolate) and nothing depends on that.

### Verified

- Contract suite green, incl. the new headless RunLoop test (timer fire/reschedule,
  one-shot invalidation, invalidated-never-fires, `.common` serviced in `.default`,
  `perform`, Apple's `Mode` raw values).
- **Frozen demo, live:** its "Timer: Ns" label ticks 4→7→10s and the Click button
  responds — WinChocolate.Timer's `WM_TIMER` is still dispatched by the pump, input
  still flows, under the RunLoop-driven `NSApplication.run()`.
- **RunLoopDemo, live:** the self-driving demo (see below) ticks 1→9; at tick 2
  `RunLoop.main.perform` runs its block on the next iteration; at tick 4 a nested
  `RunLoop.main.run(mode:.default, before:+2s)` returns with the timer continuing
  across it (exactly 2 ticks during) — the re-entrancy case working.

The design as originally written follows.

---

Resolves `WinChocolateRequests.md` #7 and the roadmap's Priority-1 item 2. Unblocks
`Timer.publish(every:on:in:)`, `TimelineView`, and the animation clock in WinSwiftUI.

## The problem in one sentence

Foundation's real `RunLoop.main` **is** the main thread's event loop — on macOS
`NSApplication.run()` drives it, and one loop services timers, sources, and window
events together. WinChocolate today has **two half-answers**: a bare Win32
`GetMessage` loop (`Win32NativeControlBackend.runApplication()`) for window
messages, and `Timer` riding `SetTimer`/`WM_TIMER` through the same loop. There is
no `RunLoop` object, and WinFoundation — which sits **below** WinChocolate and has
no message pump — can't grow one naively without either duplicating the pump or
depending upward on WinChocolate (a forbidden cycle).

## The core idea: WinFoundation owns the loop; WinChocolate lends it a pump

```
   WinFoundation (no Win32)              WinChocolate (Win32)
   ┌───────────────────────┐            ┌────────────────────────┐
   │ RunLoop  (pure Swift) │            │ NSApplication.run()    │
   │  · timers per mode    │            │   drives RunLoop.main  │
   │  · input sources      │  installs  │                        │
   │  · run(mode:before:)  │◄───────────│ Win32RunLoopPump :     │
   │  · limitDate(forMode:)│  a pump    │   RunLoopPlatformPump  │
   │  calls the pump ──────┼───────────►│   (MsgWait + PeekMsg)  │
   └───────────────────────┘            └────────────────────────┘
       depends on nothing                 depends on WinFoundation ✔ (already)
```

- **`WinFoundation.RunLoop`** is pure Swift. It keeps, per `RunLoop.Mode`, a sorted
  set of timers (fire date, interval, block) and input sources. It knows *when* the
  next thing is due (`limitDate(forMode:)`) and *how to fire* it. It knows nothing
  about Win32.
- **The seam that breaks the cycle:** WinFoundation defines a protocol
  `RunLoopPlatformPump` — `waitForEvents(until limit: Date?) -> Bool` (block until a
  native event arrives or `limit` passes, servicing platform messages) and `wake()`
  (break the wait early). WinFoundation *calls* it; it does not know it is Win32.
- **WinChocolate installs a concrete pump** at startup:
  `RunLoop.main.installPlatformPump(Win32RunLoopPump())`. Dependency stays
  one-directional — WinChocolate already depends on WinFoundation. On a platform
  with no pump installed (e.g. a headless test), `RunLoop` falls back to a
  wall-clock sleep, so it still fires timers deterministically.

### One loop, both jobs

`RunLoop.run(mode:before:)` does exactly what CFRunLoop does on Win32:

1. `limit = min(before, limitDate(forMode:))` — the next timer's fire date.
2. `pump.waitForEvents(until: limit)` — WinChocolate's pump calls
   `MsgWaitForMultipleObjects(timeout)`, then drains pending messages with
   `PeekMessageW`/`TranslateMessage`/`DispatchMessageW`. **Window messages keep
   flowing here** — this is the same dispatch the old loop did.
3. Fire every timer whose fire date has passed; reschedule repeaters.
4. Repeat until the mode empties or `before` passes.

`NSApplication.run()` becomes `RunLoop.main.run()` (run `.default` forever). Window
messages and Foundation timers are now serviced by **one** loop — AppKit's model.

## Why both keep working (the frozen demo is safe)

The existing `SetTimer`/`WM_TIMER` path is **not removed**. During and after this
change:

- `scheduleNativeTimer` still calls `SetTimer`; `WM_TIMER` is still dispatched in
  step 2's message drain. Every current consumer (the frozen demo, sheets'
  positioning timer, `Win32Dialogs`) is untouched.
- `WinChocolate.Timer` (Runtime) keeps its exact public API and keeps riding
  `scheduleNativeTimer`. **No behavioural change for anything already shipped.**
- The **new** `WinFoundation.Timer` schedules on `RunLoop` and is the Apple-faithful
  one WinSwiftUI/WinCombine target. Two timer mechanisms coexist by design; they use
  separate code paths and cannot double-fire.

So "both keep working" is guaranteed by *addition*, not by rewiring the old path.
Unifying `scheduleNativeTimer` onto `RunLoop` later is optional and explicitly **out
of scope** for this change.

## API surface (Apple-shaped, so RunLoopDemo compiles on the Mac too)

WinFoundation:
- `RunLoop` — `RunLoop.current`, `RunLoop.main`, `perform(_:)`,
  `add(_ timer: Timer, forMode:)`, `run()`, `run(mode:before:) -> Bool`,
  `limitDate(forMode:) -> Date?`.
- `RunLoop.Mode` — `RawRepresentable`, with `.default` and `.common`.
- `Timer` (new, in WinFoundation) — `scheduledTimer(withTimeInterval:repeats:block:)`
  (schedules on `RunLoop.current`), `init(timeInterval:repeats:block:)` +
  `RunLoop.add`, `fire()`, `invalidate()`, `isValid`, `timeInterval`. Mirrors the
  existing `WinChocolate.Timer` shape so porting is trivial.
- **Windows-only, hidden from the Mac build:** `installPlatformPump(_:)` and the
  `RunLoopPlatformPump` protocol live behind `#if os(Windows)` (or in a
  WinChocolate-only extension). The Mac's real Foundation `RunLoop` already works,
  and RunLoopDemo must never reference the seam — only `NSApplication.run()` installs
  it internally.

## RunLoopDemo (new app — the frozen demo is not touched)

A separate single-file app, `Demo/RunLoopDemo/main.swift`, compiled against
WinChocolate/Win32 and real AppKit/Foundation on the Mac. **Rule One (set in
stone): the only conditional is the framework-import switch** — AppKit ↔
WinChocolate, nothing else. That decides the demo's shape: a hand-rolled custom
target/action needs `@objc`/`#selector` on real AppKit, which the Windows Swift
toolchain can't compile — a *second* conditional, which the rule forbids. So the
demo has **no buttons/custom actions**; it drives itself from the repeating
`Timer`'s block (a plain Swift closure — no `@objc`):

- The tick label rises once a second (`Timer.scheduledTimer(withTimeInterval:1,
  repeats:true) { … }`).
- At tick 2, `RunLoop.main.perform { }` updates a label on the next iteration.
- At tick 4, a nested `RunLoop.main.run(mode:.default, before: +2s)` returns after
  its window with the tick count still rising across it (exactly 2 ticks during) —
  the nested-run / re-entrancy proof.
- `Quit` uses the framework's own `terminate:` (a string selector resolving on
  both), so it needs no conditional.

On the Mac this is plain Foundation/AppKit and must build unmodified — the
faithfulness gate for the API shape. It is a two-target (AppKit/WinChocolate)
proof; a LinChocolate branch would be a third import switch Rule One doesn't
allow, so Linux is out of scope for this demo.

## Obstacles / risks (the honest list)

1. **Nested run loops & modal.** `runModal` currently runs its own `GetMessage`
   loop. Under the unified design a modal session is a nested
   `RunLoop.main.run(mode:.modalPanel, before:)`, and `.common` timers must keep
   firing inside it. This is the trickiest correctness area — reentrancy, clean
   exit on `stopModal`, and not starving window messages. Plan: keep `runModal`'s
   existing loop as-is initially (it already works), and only route the *new*
   RunLoop through `run()`. Fold modal onto RunLoop as a later, separately-verified
   step.
2. **Two timer systems during transition.** Mitigated by keeping them on separate
   paths (above). Must add a test that a `SetTimer` timer and a `RunLoop` timer both
   fire and neither is dropped.
3. **The platform-pump seam is Windows-only.** It must be `#if os(Windows)` so the
   Mac build (real Foundation) never sees `installPlatformPump`. RunLoopDemo must not
   reference it. Verified by the Mac cross-check compile.
4. **Thread affinity.** `RunLoop.main` is the main (UI) thread. Cross-thread
   `perform`/`wake()` (PostMessage to break the wait) is designed-for but not
   exercised yet — current code is single-threaded. The seam allows it; we won't
   build the multi-thread path until something needs it.
5. **Headless determinism.** Contract tests have no pump. `RunLoop` must fall back
   to advancing a virtual/wall clock and firing due timers synchronously (reuse the
   `fireDueTimers()` idea from the InMemory backend) so `run(mode:before:)` is
   testable without a message loop.
6. **`NSApplication.run()` observational parity.** Apps that never touch RunLoop must
   see *identical* behaviour. Verify by running the frozen demo unchanged after the
   switch.

## Build order (once approved)

1. WinFoundation: `RunLoop` + `RunLoop.Mode` + `Timer`, pump-less (wall-clock
   fallback) + contract tests (`run(mode:before:)`, repeat/non-repeat, invalidate,
   `limitDate`, nested run).
2. WinFoundation: `RunLoopPlatformPump` protocol + `installPlatformPump`
   (`#if os(Windows)`).
3. WinChocolate: `Win32RunLoopPump` (`MsgWaitForMultipleObjects` + `PeekMessage`
   drain); `NSApplication.run()` drives `RunLoop.main.run()`; install the pump at
   startup. Keep `scheduleNativeTimer`/`runModal` intact.
4. Verify the **frozen demo** runs unchanged (observational parity).
5. New `RunLoopDemo` target; live-verify timers + message flow together; Mac
   cross-check compile.
6. Docs: close #7 in `WinChocolateNeedsForParity.md` / Phase 14; tell WinSwiftUI it
   can spell `Timer.publish(every:on:in:)`.

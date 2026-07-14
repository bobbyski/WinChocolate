# Apple Framework Gap Analysis

**Purpose (dual use).**
1. **Marketing / honesty.** A clear statement of what WinChocolate *does* and *does not* cover, so we can say "your AppKit app runs" without over-promising "all of Apple's SDK runs."
2. **Rev 2 planning.** A prioritized, complexity-estimated backlog of the frameworks worth adding next, with the smartest Windows implementation strategy for each.

**What WinChocolate is today.** A source-compatible reimplementation of **AppKit** (the Mac desktop UI framework) plus the slices of **Foundation** and **CoreGraphics** that AppKit apps lean on:
- **AppKit** — controls, windows, menus, toolbars, tables/outlines/collections, Auto Layout, drawing, documents, pasteboard, drag & drop, appearance/dark mode, accessibility model, and **nib/xib loading**. This is the deep, mature part.
- **WinFoundation** — `URL`, `Data`, `Date`, `UUID`, `IndexSet`/`IndexPath`, `Bundle`, `FileManager`, `UserDefaults`, `NotificationCenter`, `NumberFormatter`/`DateFormatter`, string/data I/O, `NSError`, `NSNumber`. A pragmatic subset, discovery-driven.
- **WinCoreGraphics** — the CoreGraphics *value* types (`CGRect`/`CGPoint`/`CGSize`/`CGAffineTransform`, `CGImage` + BMP/PNG codecs); the drawing-facing `CGContext`/`CGColor`/`CGPath`/`CGGradient` live in the AppKit compat layer (they *are* the AppKit objects, per Apple's own bridging).

Everything below is **not yet present**. This is the honest boundary.

**Legend.** Complexity is the *port* cost, not Apple's original cost. **S** ≈ weeks, **M** ≈ 1–2 months, **L** ≈ a quarter, **XL** ≈ multiple quarters / a team, **XXL** ≈ a project unto itself. "Windows substrate" is the platform tech the port would build on — often the honest realization is *a translation layer over an existing Windows framework, not a from-scratch reimplementation.*

---

## Tier 0 — Foundational gaps *inside* what we already ship

These aren't separate frameworks; they're depth WinChocolate lacks that blocks whole categories of apps. Highest leverage.

| Gap | What it blocks | Complexity | Windows substrate / strategy | Notes |
|---|---|---|---|---|
| **KVC / KVO / reflection runtime** | Cocoa Bindings, automatic `@IBOutlet`/`@IBAction` wiring, `NSPredicate`, much of AppKit's dynamism | **L** | A property registry + a `@dynamicMemberLookup`/macro-based accessor layer; Swift on Windows lacks the ObjC runtime | **The single most unblocking gap.** Nib outlet *records* already parse (Phase 15) — only "set property by name" is missing. Deferred in plan 12.1. |
| **`JSONEncoder`/`JSONDecoder`, `PropertyListEncoder`** | `Codable` interchange, config files, most networking payloads | **S** | Pure Swift; `WinJSON` already parses/writes a plist subset — generalize to full `Codable` coders | No platform dependency. Fast win. |
| **`URLSession` (networking)** | Any app that talks to the internet — the biggest single "why doesn't my app work" | **M** | **WinHTTP** or **libcurl**, wrapped in the URLSession task/delegate shape | High marketing value; medium effort. Async maps to the run loop. |
| **Full `Foundation` value depth** — `Calendar`/`DateComponents`/`TimeZone`, `Locale` depth, `Measurement`, `NSRegularExpression`, `NSAttributedString` (Foundation half), `FileHandle`, `Process`, `OperationQueue` | Date math, i18n, text processing, scripting, background work | **M–L** | Mostly pure Swift; `swift-corelibs-foundation` is a reference (and partially buildable on Windows) | Discovery-driven today (plan 7.4). Could be closed faster by vendoring parts of corelibs-Foundation. |
| **`Dispatch` (GCD) surface** | `DispatchQueue.main.async`, concurrency idioms everywhere | **S** (mostly present) | `swift-corelibs-libdispatch` **ships with the Windows toolchain** | Largely available already via the toolchain; needs verification + a `.main` bound to our run loop. |

---

## Tier 1 — High-value frameworks (Rev 2 candidates)

| Framework | What it does | Complexity | Windows substrate / strategy | Notes |
|---|---|---|---|---|
| **CoreText** | Low-level text layout & glyph shaping (`CTFont`, `CTLine`, `CTFrame`) | **L** | **DirectWrite** (`IDWriteTextLayout`/`IDWriteFontFace`) — a near-1:1 conceptual map | *Do not reimplement shaping.* CoreText → DirectWrite is a **translation layer**: both are "font + text layout + glyph run" models. Pairs with the Win32 rendering modernization (Direct2D/DWrite). |
| **QuartzCore / CoreAnimation (`CALayer`)** | Layer tree, implicit animation, transforms, compositing | **L** | **DirectComposition** (visuals/surfaces) + our transform types | The honest `CALayer` implementation on Windows *is* DirectComposition — a retained GPU compositor with the same visual-tree/animation model. Also the structural fix for the flicker class. |
| **CoreImage** | GPU image filters & processing (`CIFilter`, `CIContext`) | **L** | **Direct2D Effects** (`ID2D1Effect`) or **DirectML** for the heavy ones | Direct2D ships a large built-in effect graph (blur, color, convolution) that maps closely to CoreImage's filter graph. Translation, not reinvention. |
| **AVFoundation / CoreAudio / CoreMedia** | Audio/video playback, capture, editing | **L (playback) → XL (editing)** | **Media Foundation** (playback/capture), **WASAPI/XAudio2** (low-level audio), **Media Foundation Transforms** (editing) | Tiered: `AVAudioPlayer`-style playback is **M** over Media Foundation; full non-linear editing is **XL**. Media Foundation is the mapping target. |
| **WebKit (`WKWebView`)** | Embedded web content | **M** | **WebView2** (Edge/Chromium) hosted in an `NSView` | Unusually cheap for its value: WebView2 is a drop-in HWND-hostable Chromium. `WKWebView` → WebView2 is a thin shim. Strong marketing item. |
| **UserNotifications** | Local/push notifications | **S–M** | Windows **App Notifications** (toast XML) | `UNUserNotificationCenter` → toast API is a clean map for local notifications. |
| **UniformTypeIdentifiers (`UTType`)** | Type/UTI system for files & pasteboard | **S** | A static UTI↔extension↔MIME table + shell type queries | Small, and it strengthens documents/pasteboard/drag correctness. |
| **OSLog / `os`** | Structured logging & signposts | **S** | **ETW** (Event Tracing for Windows) or a file/console sink | Easy; nice-to-have for diagnostics. |
| **Security (Keychain)** | Credential/secret storage | **M** | **Windows Credential Manager** + **DPAPI** | `SecItem*` → Credential Manager is a reasonable map for the common password/token cases. |

---

## Tier 2 — Large frameworks (strategic, own-project scale)

| Framework | What it does | Complexity | Windows substrate / strategy | Notes |
|---|---|---|---|---|
| **SwiftUI** | Declarative, reactive UI | **XXL** | Build a SwiftUI runtime (view graph + diffing + layout) **on top of the WinChocolate AppKit layer** as the render backend | The hardest and highest-prestige target. The reactive/`@State`/`body` machinery is pure Swift; the renderer would drive our AppKit views (like how SwiftUI drives AppKit/UIKit on Apple platforms). **Needs Combine (or Observation) first.** A multi-quarter effort — its own project, not a phase. |
| **Combine / Observation** | Reactive streams, `@Published`, `ObservableObject` | **M–L** | Pure Swift — **no platform dependency** | A prerequisite for a SwiftUI port and valuable on its own. Portable; the main cost is surface area and scheduler integration with the run loop. |
| **Metal** | GPU compute & rendering | **XL** | **A Metal→Direct3D 12 translation layer** | Per the guiding insight: *writing Metal as a DirectX translation layer is dramatically easier than recreating Metal from scratch.* Both are modern explicit low-level GPU APIs (command queues, buffers, pipeline state, shaders); the shader language differs (MSL vs HLSL) and needs a cross-compiler (SPIRV-Cross / DXC path). Prior art exists (e.g. open-source MSL→HLSL efforts). Still **XL**, but a *translation* problem, not a *reinvention*. |
| **CoreData** | Object graph persistence / ORM | **XL** | SQLite-backed store + a managed-object/context/faulting layer | Note the sibling **WinSwiftData** project is exploring the *SwiftData* (successor) surface; CoreData proper is a larger, older API. |
| **SpriteKit / SceneKit** | 2D / 3D game engines | **XL each** | **Direct2D** (SpriteKit-ish) / **Direct3D** (SceneKit) | Game frameworks; only worth it for a games push. SceneKit needs a scene graph + PBR renderer. |
| **PDFKit** | PDF rendering & annotation | **L** | A PDF engine (e.g. PDFium) wrapped in `PDFView`/`PDFDocument` shapes | Rendering is L; annotation/editing pushes to XL. |
| **MapKit** | Maps & geo UI | **L** | Windows **Map control** / a web map (via WebView2) | Viable but niche for desktop; tiles + annotations over the Map control. |
| **CoreML / Vision / NaturalLanguage** | On-device ML & inference | **L–XL** | **Windows ML / DirectML / ONNX Runtime** | `CoreML` model execution → ONNX/DirectML is a real mapping (model-format conversion required). Vision/NL are ML apps atop it. |

---

## Tier 3 — Apple-service frameworks (largely N/A on Windows)

These wrap Apple's cloud/hardware/store services and have **no meaningful Windows equivalent**. Honest marketing position: *out of scope by nature, not by omission.*

| Framework | Why N/A | Possible stance |
|---|---|---|
| **CloudKit** | Apple's iCloud backend | No equivalent; an app would use its own/OneDrive backend. Stub to no-op or error. |
| **StoreKit** | App Store purchases | No Mac App Store on Windows; map to MSIX Store or third-party billing, or stub. |
| **GameKit** | Game Center | No equivalent; stub or map to a chosen service. |
| **HealthKit / HomeKit / CarPlay / PassKit / ClassKit** | Apple hardware/service ecosystems | Not applicable on Windows. Compile-stub for source compatibility only. |
| **AppKit-only-on-Apple-silicon bits, Core Bluetooth, etc.** | Hardware/OS services | Map case-by-case to Windows APIs (e.g. Bluetooth LE) only if a consumer needs it. |

---

## Marketing summary (the one-paragraph version)

> **WinChocolate runs AppKit apps on Windows.** Cocoa desktop UI — controls, windows, menus, toolbars, tables, Auto Layout, drawing, documents, drag & drop, dark mode, and nib/xib loading — plus the Foundation and CoreGraphics your UI needs. **Not yet:** SwiftUI, Metal, CoreAudio/AVFoundation, CoreText, CoreAnimation, CoreData, WebKit, and networking (`URLSession`). Several of those are *translation layers over Windows' own modern stacks* (CoreText→DirectWrite, CoreAnimation→DirectComposition, Metal→Direct3D 12, WebKit→WebView2) rather than ground-up rewrites — which is why they're on the Rev 2 roadmap, not off the table.

## Recommended Rev 2 sequence (by leverage)

1. **KVC/KVO runtime** (Tier 0) — unblocks bindings, auto-outlets, predicates. Force-multiplier.
2. **`URLSession` + `JSONEncoder`/`Decoder`** (Tier 0) — makes real-world apps actually work; huge "it runs!" value.
3. **CoreText → DirectWrite + CoreAnimation → DirectComposition** (Tier 1) — best done *with* the [Win32 rendering modernization](Win32ModernizationAudit.md); together they're the modern rendering/animation foundation.
4. **WebView2-backed WKWebView + UserNotifications** (Tier 1) — cheap, high-visibility wins.
5. **Combine, then SwiftUI** (Tier 2) — the flagship, multi-quarter, own-project effort; everything above is a prerequisite or a renderer for it.

**Cross-reference.** Tiers 1–2 rendering/animation work shares a foundation with `Docs/Win32ModernizationAudit.md` — CoreText/CoreImage/CoreAnimation and the GDI→Direct2D/DWrite/DComp modernization are the *same* investment viewed from the Apple-API side vs the Windows-substrate side. Sequence them together.

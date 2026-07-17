# Win32 Modernization Audit

**Purpose.** WinChocolate's Windows backend is built on the *classic* Win32 API — the drawing and control libraries that have shipped with Windows since the 1990s. That was the right call for reach and simplicity: classic Win32 runs everywhere from Windows 7 to 11 with **zero runtime dependency** (nothing to install, no framework to ship alongside the app). But Windows, like macOS, has newer, faster, GPU-accelerated replacements for most of those old libraries. This document maps every place we use an old API to its modern equivalent, and — in plain English — **what actually gets better** if we switch.

**Written for a reader who knows the Mac, not Windows.** Each technology below is explained from scratch, with the closest Apple equivalent named, so "Direct2D" or "DirectWrite" isn't just jargon.

**Scope note.** Nothing here is a bug. The current backend works, is contract-tested, and matches AppKit's behavior. Modernization is about **rendering quality, smoothness, sharper text, and future-proofing** — not fixing something broken. This is a Rev 2 map, likely a future **Phase 17**.

**Reading the effort sizes.** S ≈ days · M ≈ 1–2 weeks · L ≈ 3–6 weeks · XL ≈ a quarter or more. "Min OS" is the oldest Windows version that supports the modern API — some of them raise the floor above Windows 7.

---

## Part 1 — Plain-English primer: the Windows graphics & UI stack

Windows has accumulated **layers** of UI technology over 30 years, the way macOS went QuickDraw → Quartz/Core Graphics → Core Animation/Metal. Old layers never get removed (for compatibility), so at any time several generations coexist. Here's the map, oldest to newest, with the Mac analogy.

### Drawing (2D graphics — shapes, lines, fills)

- **GDI** ("Graphics Device Interface") — *the 1990s 2D drawing API.* You get a "device context" (a drawing handle for a window) and call `LineTo`, `FillPath`, `TextOut`. It runs on the **CPU**, has **no anti-aliasing** on shapes, and predates transparency (alpha). **Mac analogy: the old QuickDraw.** *This is what WinChocolate draws with today.*
- **GDI+** — *a 2000s wrapper that added anti-aliasing, gradients, and image formats (JPEG/PNG) on top of GDI.* Still mostly CPU. **Mac analogy: early Quartz 2D, but slower.** *We use GDI+ specifically for loading/drawing images and gradients.*
- **Direct2D** — *the modern (2009+) 2D API. GPU-accelerated, fully anti-aliased, real transparency, hardware scaling.* This is what modern Windows apps draw with. **Mac analogy: Core Graphics / Quartz 2D as it exists today (GPU-backed).**
- **DirectWrite** — *the modern text engine that pairs with Direct2D.* Handles fonts, layout, glyph shaping, sub-pixel anti-aliasing, colored emoji, and gives **accurate text measurements.** **Mac analogy: Core Text.**
- **WIC** ("Windows Imaging Component") — *the modern image codec library:* decode/encode PNG, JPEG, HEIF, etc., feeding bitmaps to Direct2D. **Mac analogy: Image I/O.**

> **The big picture:** GDI/GDI+ is to Direct2D/DirectWrite/WIC what **QuickDraw is to Quartz.** We're currently drawing with the QuickDraw-generation tools. Everything visual — sharper text, smooth gradients, correct transparency, HiDPI crispness, GPU speed — improves by moving up a generation.

### Compositing (how windows and layers are assembled on screen)

- **Immediate-mode GDI painting (today's model)** — *every time anything changes, Windows sends the app a "repaint" message and the app redraws that region.* Scrolling and resizing mean lots of repaints; without care you get **flicker** (which is exactly the class of bug we hand-fixed recently). **Mac analogy: pre-Core-Animation `drawRect:` everywhere.**
- **DirectComposition** — *the modern GPU compositor.* Each view becomes a "visual" with its own GPU surface; the OS composites them together on the graphics card. Moving/scrolling/animating doesn't trigger repaints — the compositor just re-arranges surfaces. **Mac analogy: Core Animation / `CALayer`.** *This is the structural cure for flicker and the foundation for smooth animation.*

### Controls (buttons, text fields, lists…)

- **ComCtl32** ("Common Controls") — *the standard Windows control library:* buttons, edit fields, list views, sliders, tooltips. Version 6 (with a "manifest") gives the themed look. **Mac analogy: the standard AppKit controls, except supplied by the OS.** *WinChocolate's controls are real ComCtl32 v6 controls.*
- **WinUI 3 / XAML Islands** — *Microsoft's newest control set ("Fluent design"),* with animations and built-in dark mode. But it requires shipping the Windows App SDK runtime and a hosting bridge. **Mac analogy: think "the SwiftUI-era controls" — modern-looking but a heavier dependency.**
- **Owner-drawn controls** — *you draw the control yourself* (over GDI today, or Direct2D tomorrow) instead of using an OS control. WinChocolate already does this for tables and toolbars. **Mac analogy: a fully custom `NSView` subclass that draws its own appearance.**

### Dialogs, text input, windows, misc

- **ComDlg32 / Shell dialogs** (`GetOpenFileName`, `SHBrowseForFolder`) — *the old file-open/save and folder-pick dialogs* (Windows XP era). **Mac analogy: an old `NSOpenPanel` look.**
- **IFileDialog** — *the modern (Vista+) file dialogs* with the current Explorer look and a places sidebar. **Mac analogy: today's `NSOpenPanel`/`NSSavePanel`.**
- **DWM** ("Desktop Window Manager") — *the compositor that draws window frames/title bars* and exposes the "dark title bar" toggle. Documented and current. **Mac analogy: the window server's title-bar chrome.**
- **uxtheme** — *the control-theming engine.* Some dark-mode behavior is only reachable through **undocumented** entry points here (numbered, not named — "ordinals"), which Microsoft can change between Windows builds.
- **TSF** ("Text Services Framework") — *the modern text-input plumbing* for IMEs (Chinese/Japanese/Korean typing), handwriting, and speech. **Mac analogy: the input-method system behind `NSTextInputClient`.**
- **Media Foundation / WASAPI / XAudio2** — *the modern audio/video stack.* **Mac analogy: AVFoundation / Core Audio.**
- **OLE** — *the decades-old but still-current drag-and-drop and clipboard COM API.* Still the right desktop choice; not legacy in the bad sense.

With that vocabulary, the rest of the document says *what we use, what the modern option is, and what improves.*

---

## Part 2 — The three big levers (start here)

Ranked by improvement-per-effort.

### Lever 1 — Modernize drawing: GDI/GDI+ → Direct2D + DirectWrite + WIC  *(effort: XL)*

**What we do now.** All custom drawing — the framework-drawn tables, toolbars, gradients, the alert panels, every `NSView.draw(_:)` — goes through GDI (shapes/text) and GDI+ (images). CPU-bound, limited anti-aliasing, and text is drawn with the old `TextOut`.

**What it is.** Direct2D is the GPU 2D engine; DirectWrite is its text engine; WIC is its image loader. Together they're the modern Windows equivalent of **Quartz + Core Text + Image I/O**.

**What concretely improves:**
- **Sharper text**, especially at small sizes and on HiDPI screens — sub-pixel anti-aliasing and proper glyph shaping (kerning, ligatures). Today's `TextOut` text looks slightly coarser than a Mac's.
- **Correct transparency** everywhere — overlapping semi-transparent things composite properly; today alpha is awkward under GDI.
- **HiDPI for free** — Direct2D works in resolution-independent units, so the manual "multiply everything by the scale factor" plumbing we wrote for DPI largely disappears, and everything is crisp at 150%/200%.
- **Speed** — drawing moves to the GPU, so complex pages (like the gradient stress page) paint far faster.
- **Real radial gradients, better scaling** — today we fake radial gradients by drawing rings.

**Why it's the keystone.** It hides behind our existing `NativeDrawingContext` seam, so the framework/demo/tests don't change — and it unlocks Levers 2 and 3.

### Lever 2 — Kill flicker structurally: manual double-buffering → DirectComposition  *(effort: L–XL)*

**What we do now.** Views are separate OS windows; scrolling moves them and repaints; we manually double-buffer and hand-tuned the scroll path to stop flicker. It works, but it's "immediate-mode" — every change is a repaint.

**What it is.** DirectComposition is the **GPU window compositor** — the direct analog of **Core Animation** on the Mac. Each view becomes a persistent GPU surface; the OS assembles them.

**What concretely improves:**
- **Flicker becomes impossible by design** — the compositor re-arranges existing surfaces instead of repainting, so scrolling and resizing are glass-smooth. This turns the flicker work from ongoing whack-a-mole into "solved."
- **Free, smooth animations** — fades, slides, transforms run on the GPU off the main thread, exactly like Core Animation. Today any animation is a manual timer-driven repaint.
- **It's the honest way to implement `CALayer`** on Windows — see the companion `AppleFrameworkGap.md`: if we ever add Core Animation, this is its foundation.

### Lever 3 — Modernize dialogs and dark mode  *(effort: M for dialogs, L for dark)*

**What we do now.** File open/save/folder use the **Windows-XP-era** ComDlg32/Shell dialogs, and we carry a low-level "window hook" just to reposition them. Dark mode leans on **undocumented** uxtheme entry points that Microsoft can break.

**What it is / improves:**
- **IFileDialog** (the modern file dialog): today's Explorer look, a "places" sidebar, better keyboard/search — and it lets us **delete the fragile positioning hook**. **Mac analogy: the difference between a 2005-era and today's `NSOpenPanel`.**
- **A durable dark strategy** (owner-drawing controls, the direction we're already heading, or XAML theming): removes reliance on undocumented APIs, so dark mode won't silently break on a future Windows update.

---

## Part 3 — Full inventory (by subsystem)

Each row: *what we use now* → *modern replacement* → *min OS* → *effort* → *what improves.*

### 3.1 Drawing (GDI & GDI+)

*What we use now: GDI for paths/text (`FillPath`, `StrokePath`, `TextOut`, `CreateFont`), GDI+ for images and gradients, a GDI "world transform" to scale for HiDPI.*

| We use now | Modern replacement | Min OS | Effort | What improves (plain English) |
|---|---|---|---|---|
| GDI shape fill/stroke | **Direct2D** geometry | 7 | L | GPU speed, true anti-aliasing, real transparency, proper dashed/rounded strokes |
| GDI `TextOut` + `CreateFont` | **DirectWrite** | 7 | L | Noticeably sharper text, correct kerning/ligatures, colored emoji, accurate text sizing (fixes a HiDPI text-scaling quirk we work around) |
| GDI+ image decode | **WIC** | 7 | M | More formats (HEIF/AVIF/WebP), HDR, faster loading |
| GDI+ image draw / `StretchBlt` | **Direct2D** `DrawBitmap` | 7 | S* | Correct transparency, high-quality scaling, GPU |
| GDI+ linear gradient | **Direct2D** gradients (native radial too) | 7 | S* | Native radial gradients (we fake them with rings today), smoother color blends |
| GDI world-transform for DPI | **Direct2D resolution-independent units** | 7 | — | HiDPI becomes automatic; the manual scale plumbing goes away |
| Manual memory-DC double-buffer | **Direct2D is buffered by design** | 7 | — | The hand-rolled back-buffer disappears |

\* *"S" once Direct2D itself is in — these ride on Lever 1.*

### 3.2 Compositing & flicker

*What we use now: separate child windows, immediate-mode repaint, manual double-buffering, the hand-tuned scroll path.*

| We use now | Modern replacement | Min OS | Effort | What improves |
|---|---|---|---|---|
| Manual back-buffers / `WS_EX_COMPOSITED` | **DirectComposition** (GPU compositor) | 8 | L | Flicker impossible by design; glass-smooth scroll/resize |
| Timer-driven repaint animations | **DirectComposition animations** | 8 | M | GPU, off-main-thread animation — like Core Animation |
| `SetTimer`/`WM_TIMER` coalescing pump | **`DispatcherQueueTimer`** | 10 | S | Frame-aligned callbacks, less jitter |

### 3.3 Native controls (ComCtl32 v6)

*What we use now: real OS controls (buttons, edits, lists, sliders, tooltips) themed by ComCtl32 v6. Tables and toolbars are already owner-drawn by us.*

| We use now | Modern replacement | Min OS | Effort | What improves / trade-off |
|---|---|---|---|---|
| ComCtl32 v6 controls | **WinUI 3 / XAML Islands** | 10 1809+ | XL | True "Fluent" look + animations + built-in dark — **but** ships a heavy runtime and needs a hosting bridge; loses the "no dependencies" property |
| ComCtl32 v6 controls | **Owner-draw over Direct2D** (finish the drawn path) | 7 | XL | Total control of appearance, matches our already-drawn tables/toolbars, no new dependency — but we reimplement control behavior |

**The strategic fork.** Three coherent long-term stances: **(a)** keep ComCtl32 (cheapest, most compatible, least "modern-looking"); **(b)** WinUI/XAML Islands (most modern-looking, heaviest, highest OS requirement); **(c)** owner-draw everything on Direct2D (most control, no dependencies, matches where the framework is already going). Our trajectory — drawn tables, drawn toolbars, drawn dark chrome — points at **(c)**.

### 3.4 Dialogs & shell

| We use now | Modern replacement | Min OS | Effort | What improves |
|---|---|---|---|---|
| `GetOpenFileName`/`GetSaveFileName` (XP-era) | **IFileOpenDialog / IFileSaveDialog** | Vista | M | Modern Explorer UX; deletes our repositioning hook |
| `SHBrowseForFolder` (old folder picker) | IFileDialog in folder mode | Vista | S | Same modern dialog, folder mode |
| `MessageBox` for alerts | **TaskDialog**, or keep composing our own panel | Vista | S–M | Richer content; note our composed panel already handles dark better than any native box |

### 3.5 Text input & IME

| We use now | Modern replacement | Min OS | Effort | What improves |
|---|---|---|---|---|
| Edit-control text + implicit IMM32 | **Text Services Framework (TSF)** | 7 | L | First-class Chinese/Japanese/Korean typing, handwriting, speech — **on our own drawn text** (native edit fields already get basic IME free) |

### 3.6 Smaller items — mostly fine as-is

| Area | We use now | Modern option | Verdict |
|---|---|---|---|
| HiDPI awareness | Per-monitor-v2 (`SetProcessDpiAwarenessContext`) | — | **Already modern.** No change. |
| Drag & drop | OLE (`IDataObject`/`IDropTarget`) + drag-image helper | WinRT `DataPackage` | OLE *is* the current desktop API. **Keep.** |
| Clipboard | Classic clipboard API | WinRT `DataPackage` | Classic is current for desktop. **Keep** unless we go WinUI. |
| Dark title bar | DWM immersive-dark-mode attribute | — | **Documented and current.** Keep. |
| Settings storage | JSON file (our `UserDefaults` shim) | Registry / `ApplicationData` | Portable and deliberate. **Keep.** |
| Printing | GDI `StartDoc`/`StartPage` | **Direct2D print / XPS** | Modernize *with* Lever 1, not before. |
| Accessibility export | (planned) UI Automation providers | — | UIA already *is* the modern path (tracked in plan 10.2). |

---

## Part 4 — Suggested phasing (if this becomes Phase 17)

Every step hides behind an existing seam, so the framework, demo, and tests never change:

1. **17.1 — Direct2D + DirectWrite drawing** (behind `NativeDrawingContext`). The keystone; unlocks the rest. **XL.**
2. **17.2 — WIC image decode** (behind the image path). **M.**
3. **17.3 — IFileDialog** (behind the file-dialog backend method); delete the repositioning hook. **M.**
4. **17.4 — DirectComposition compositing**; retire manual double-buffering and the flicker workarounds. **L–XL.**
5. **17.5 — Durable dark mode** (owner-draw or XAML) to drop the undocumented uxtheme entry points. **L.**
6. **17.6 — Native-control strategy decision** (keep ComCtl6 / WinUI Islands / owner-draw-on-D2D) — a *decision* first, then execution. **XL if owner-draw.**

**One caveat — the OS floor.** Direct2D/DirectWrite/WIC work on Windows 7; DirectComposition needs Windows 8; WinUI/XAML Islands need Windows 10 1809+. Decide the minimum supported Windows version first — it determines which rungs are reachable. (Today, on classic Win32, we support Windows 7+.)

**See also.** `AppleFrameworkGap.md` — the Apple-framework side of this. Several missing Apple frameworks (Core Text, Core Animation, Core Image) are literally "put an Apple-shaped API on top of the Windows modern stack in this document" (Core Text→DirectWrite, Core Animation→DirectComposition), so the two efforts share a foundation and should be sequenced together.

# Win32 Modernization Audit

**Purpose.** WinChocolate's Windows backend was built on the *classic* Win32 API surface (GDI, GDI+, ComCtl32, ComDlg32, undocumented uxtheme dark-mode ordinals). That was the right call for reach and simplicity — classic Win32 runs everywhere from Windows 7 to 11 with no runtime dependency. But several of those choices now have **modern replacements** that would give hardware-accelerated rendering, crisp HiDPI text, flicker-free compositing, and first-class dark mode.

This document inventories every place we lean on a legacy API where a modern alternative exists, with the payoff and the cost of switching. It is written to seed a **"Modernization" phase** (likely Phase 17). It is *not* a to-do list — classic Win32 is a legitimate, shipping target — it's a map of the upgrade path and what each rung buys.

**Scope note.** Nothing here is a bug. The current backend works, is contract-tested, and matches AppKit semantics. Modernization is about *rendering quality, smoothness, and future-proofing*, not correctness.

**How to read the tables.** Effort is a T-shirt size (S ≈ days, M ≈ 1–2 weeks, L ≈ 3–6 weeks, XL ≈ a quarter+). "Min OS" is the Windows version the modern API requires; several force a floor above Windows 7.

---

## Executive summary — the three big levers

Ranked by impact-per-effort:

1. **Rendering: GDI / GDI+ → Direct2D + DirectWrite + WIC.** This is the single highest-value change. It replaces every `draw(_:)` path (paths, text, images, gradients) with the GPU-accelerated stack. Payoff: sub-pixel-accurate anti-aliased text, correct alpha compositing, HiDPI crispness *for free* (device-independent pixels), and it is the foundation for #2. Cost: **XL** — it touches the whole `Win32DrawingContext` + image decode + text metrics, and demands a per-window render-target lifecycle. Best done behind the existing `NativeDrawingContext` protocol so the framework code above it never changes.

2. **Compositing / flicker: WS_EX_COMPOSITED & GDI double-buffer → DirectComposition (or Windows.UI.Composition).** The scroll/resize flicker we fixed by hand (copy-bits `SetWindowPos`, per-view double-buffering) is *definitionally* solved by a retained-mode compositor: each view becomes a composition visual with its own surface, and the OS composites them on the GPU with no repaint storms. Payoff: buttery scrolling, free animations, no flicker class at all. Cost: **L–XL**, and it pairs naturally with #1 (D2D renders into DComp surfaces).

3. **Dialogs: ComDlg32 / undocumented dark ordinals → IFileDialog + a real dark strategy.** `GetOpenFileNameW`/`GetSaveFileNameW`/`SHBrowseForFolderW` are the Windows-XP-era dialogs; we even carry a **CBT window hook** to reposition them. `IFileOpenDialog`/`IFileSaveDialog` are the modern COM dialogs (Vista+): better UX, native folder picking, no hook hack. Separately, our dark mode rides **undocumented uxtheme ordinals** (`SetPreferredAppMode` #135, `FlushMenuThemes` #136) plus `SetWindowTheme`-with-empty-theme tricks that Microsoft can break; a durable dark story means owner-drawing (the direction we're already going) or XAML theming. Cost: **M** for IFileDialog, **L** for the dark-mode rework.

---

## 1. Rendering — GDI & GDI+

**Today.** `Win32DrawingContext` replays paths with the GDI path API (`BeginPath`/`MoveToEx`/`LineTo`/`PolyBezierTo`/`FillPath`/`StrokePath`), draws text with `TextOutW` + `CreateFontW`, blits images with GDI+ (`GdipDrawImageRectRectI`, `StretchBlt`), and does gradients via `GdipCreateLineBrushFromRectWithAngle`. HiDPI is handled with a GDI world transform (`SetWorldTransform`). Custom views double-buffer through a memory DC + `BitBlt`.

| Legacy API | Modern alternative | Min OS | Effort | Payoff |
|---|---|---|---|---|
| GDI path fill/stroke (`FillPath`/`StrokePath`) | **Direct2D** `ID2D1RenderTarget` geometry | 7 (D2D 1.0) / 8 (1.1) | L | GPU raster, real anti-aliasing, per-primitive alpha, dashes/joins |
| `TextOutW` + `CreateFontW` + `GetTextExtentPoint32` | **DirectWrite** (`IDWriteTextLayout`, `IDWriteTextFormat`) | 7 | L | Sub-pixel AA, proper glyph shaping/kerning, colored fonts, accurate metrics; fixes the world-transform text-scaling quirk |
| GDI+ image decode (`GdipCreateBitmapFromFile`) | **WIC** (`IWICImagingFactory`) | 7 | M | Modern codecs (HEIF/AVIF/WebP w/ codecs), HDR, streaming, GPU-friendly |
| GDI+ blit (`GdipDrawImageRectRectI`, `StretchBlt`) | **Direct2D** `DrawBitmap` | 7 | S (once D2D lands) | Correct premultiplied alpha, high-quality scaling, GPU |
| GDI+ linear gradient | **Direct2D** gradient brushes (linear + radial native) | 7 | S | Native radial (we rasterize rings today), color interpolation |
| GDI world transform for DPI (`SetWorldTransform`) | **D2D device-independent pixels** (set DPI on the render target) | 7 | — | DPI scaling becomes automatic; the manual factor threading goes away |
| Memory-DC double-buffer | **D2D is retained/buffered by design** | 7 | — | Double-buffering is inherent; the manual back-buffer disappears |

**Boundary insight.** All of this lives *below* the `NativeDrawingContext` protocol. A `Direct2DDrawingContext` can be added alongside `Win32DrawingContext` and selected at runtime (or by OS floor), so the framework, the demo, and the entire contract suite compile unchanged. This is the same clean seam that let us add the in-memory recording backend.

---

## 2. Compositing & flicker

**Today.** Child windows are real HWNDs; scrolling moves the document view with `SetWindowPos` (copy-bits), resizing repaints; custom views double-buffer manually. We hand-tuned the flicker (see the scroll fix) but the *architecture* is immediate-mode repaint.

| Legacy approach | Modern alternative | Min OS | Effort | Payoff |
|---|---|---|---|---|
| `WS_EX_COMPOSITED` / manual back-buffers | **DirectComposition** (`IDCompositionDevice`, visuals + surfaces) | 8 | L | GPU compositor: per-visual surfaces, no repaint on move, zero flicker |
| Hand-rolled animations (timers + invalidation) | **DirectComposition animations** / `Windows.UI.Composition` | 8 / 10 | M | Independent (off-thread) GPU animations — matches Core Animation's model |
| `SetTimer`/`WM_TIMER` coalescing pump | **`DispatcherQueueTimer`** / composition clock | 10 | S | Frame-aligned callbacks, no message-queue jitter |

**Why this matters for the project's identity.** AppKit is layer-backed (Core Animation). WinChocolate approximates that with HWNDs + GDI. DirectComposition is the *structural* match to Core Animation — it's how you'd honestly implement `CALayer` on Windows (see the companion framework-gap doc). Adopting it turns the flicker work from "whack-a-mole" into "solved by construction."

---

## 3. Native controls (ComCtl32 v6)

**Today.** Buttons, edits, list views, combo boxes, sliders, progress bars, tooltips (`tooltips_class32`), and the toolbar's bordered items are **real ComCtl32 v6 controls**, themed via the activation context we set at startup. Dark mode rides undocumented uxtheme ordinals.

| Legacy approach | Modern alternative | Min OS | Effort | Payoff / trade-off |
|---|---|---|---|---|
| ComCtl32 v6 controls | **WinUI 3 / XAML Islands** (Fluent controls) | 10 1809+ | XL | True Fluent look, animations, built-in dark mode — **but** a heavy WinAppSDK runtime dependency and a hosting bridge; loses the "runs everywhere, no deps" property |
| ComCtl32 v6 controls | **Fully owner-drawn controls over Direct2D** | 7 | XL | Total visual control, matches our framework-drawn direction (tables/toolbars already do this), no new deps — but we reimplement control behavior |
| Undocumented dark ordinals (`SetPreferredAppMode`) | Owner-draw dark, or XAML theming | — | L | Removes reliance on APIs Microsoft can (and does) change between builds |

**Strategic fork.** There are three coherent long-term stances: **(a)** keep ComCtl32 v6 (cheapest, most compatible, least "modern"); **(b)** go WinUI/XAML Islands (most modern-looking, heaviest, highest OS floor); **(c)** owner-draw everything over Direct2D (most control, matches the already-drawn tables/toolbars, no deps). The framework's trajectory (drawn tables, drawn toolbars, drawn dark chrome) points at **(c)** — a modernization phase could unify the half-drawn/half-native split by finishing the drawn path on D2D.

---

## 4. Dialogs & shell

**Today.** File open/save use `GetOpenFileNameW`/`GetSaveFileNameW` (ComDlg32); folder pick uses `SHBrowseForFolderW`; a **CBT `SetWindowsHookExW` hook** repositions dialogs sheet-style. Alerts use `MessageBoxW` (light-only — dark alerts now compose our own panel).

| Legacy API | Modern alternative | Min OS | Effort | Payoff |
|---|---|---|---|---|
| `GetOpenFileNameW`/`GetSaveFileNameW` | **`IFileOpenDialog`/`IFileSaveDialog`** (COM) | Vista | M | Modern Explorer UX, places sidebar, no hook; native positioning events replace the CBT hook |
| `SHBrowseForFolderW` | `IFileOpenDialog` with `FOS_PICKFOLDERS` | Vista | S | Same modern dialog, folder mode |
| CBT hook for dialog positioning | `IFileDialogEvents::OnFolderChange` / owner window | Vista | — | Deletes a fragile thread-local hook |
| `MessageBoxW` | **`TaskDialogIndirect`** (or keep composing) | Vista | S–M | Rich content, command links, verification checkbox — though still no true dark; our composed dark panel is arguably the better answer |

---

## 5. Text input & IME

**Today.** Editable text is a ComCtl edit/rich-edit control; the framework-drawn table floats an edit overlay for in-place editing.

| Legacy approach | Modern alternative | Min OS | Effort | Payoff |
|---|---|---|---|---|
| Edit-control-backed text + implicit IMM32 | **Text Services Framework (TSF, `ITextStoreACP`)** | 7 | L | First-class IME/handwriting/speech input for CJK and beyond, on framework-drawn text |
| Rich-edit for attributed text | **DirectWrite layout + custom editing** | 7 | XL | Full control over attributed text rendering (pairs with #1) |

**Note.** IME on the *framework-drawn* text path (the drawn-table cell editor, any future drawn `NSTextView`) is the real gap — native edit controls already get IMM32 for free. TSF is the modern, correct answer if drawn text editing grows.

---

## 6. Smaller items (mostly fine as-is)

| Area | Today | Modern option | Verdict |
|---|---|---|---|
| Per-monitor DPI | `SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2)` | — | **Already modern.** No change needed. |
| Drag & drop | OLE `IDataObject`/`IDropTarget`/`IDropSource`, `IDragSourceHelper` | WinRT `DataPackage` | OLE *is* the current desktop API; WinRT only if going full WinUI. **Keep.** |
| Clipboard | `OpenClipboard`/`SetClipboardData` | WinRT `Clipboard`/`DataPackage` | Classic API is current for Win32. **Keep** unless WinUI. |
| Dark title bar | DWM `DwmSetWindowAttribute(USE_IMMERSIVE_DARK_MODE)` | — | **Documented and current.** Keep. |
| Accessibility export | (planned) MSAA/UIA | **UI Automation providers** | The modern path *is* UIA — see plan 10.2's tracked native depth. |
| Settings persistence | JSON file (`UserDefaults` shim) | Registry / `ApplicationData` | JSON file is deliberate and portable. **Keep.** |
| Printing | GDI `StartDocW`/`StartPage` | **Direct2D print** / `IPrintDocumentPackageTarget` / XPS | Modernize *with* #1 (D2D), not before. |
| Timers | `SetTimer` (WM_TIMER) | `DispatcherQueueTimer` | Minor; only matters with a compositor. |

---

## Suggested phasing (if this becomes Phase 17)

A modernization phase should be **opt-in and seam-preserving** — every step hides behind an existing protocol boundary so the framework/demo/tests never change:

1. **17.1 — Direct2D + DirectWrite drawing context** (behind `NativeDrawingContext`). The keystone; unlocks the rest. **XL.**
2. **17.2 — WIC image decode** (behind the image path). **M.**
3. **17.3 — IFileDialog** (behind the file-dialog backend method); delete the CBT hook. **M.**
4. **17.4 — DirectComposition compositing** (per-view surfaces); retire manual double-buffering and the flicker workarounds. **L–XL.**
5. **17.5 — Dark-mode durability** (owner-draw or XAML) to drop the undocumented uxtheme ordinals. **L.**
6. **17.6 — Native-control strategy decision** (keep ComCtl6 / WinUI Islands / owner-draw-on-D2D) — a *decision*, then execution. **XL if (c).**

**Compatibility floor caveat.** D2D/DWrite/WIC are Windows-7-safe; DirectComposition needs Windows 8; WinUI/XAML Islands need Windows 10 1809+. A modernization phase should decide the OS floor first — it gates which rungs are reachable.

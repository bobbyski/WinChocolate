# WinChocolate — Build Plan

## Summary

WinChocolate is an AppKit-shaped Swift framework for Windows. Apple AppKit API compatibility is the project's primary goal: apps are built with the Apple API and look like Windows apps. The near-term focus is a dependable classic Win32 backend with enough Cocoa/AppKit compatibility to port small apps, while preserving a path toward modern Windows visuals, richer layout, and deeper Foundation parity.

This plan is the high-level project tracker. `CONTROL_PARITY.md` remains the detailed control-by-control map, and `Architecture.md` remains the design overview.

## Project Goals

1. **PRIMARY GOAL — Apple AppKit API compatibility.** WinChocolate exists so that almost all Mac AppKit programs build and run on Windows by swapping `import AppKit` for `import WinChocolate`. Application code is written against the Apple API — AppKit names, types, delegates, and behavior — while the controls render as native Windows controls. For most controls the app should *look* like a Windows app but be *built* with the Apple API. When any design decision conflicts with this goal, Apple API compatibility wins. (Deliberate exception: toolbars keep the Apple look and feel — see Phase 6.)
2. **Selectable presentation.** Applications should eventually be able to select either the current classic Win32 look or the more modern Windows look through one switch, with no other application code changes. The classic look stays fully supported; the modern look becomes the default later in the plan once Phase 8 reaches parity.
3. **Real native backing.** AppKit-shaped API in front, honest Windows implementation behind a narrow backend boundary, kept testable through the in-memory backend and contract tests.

---

## Dashboard

```text
Overall Progress                           ████████████████████░░░░░░░░░░░░   62%  (current estimate)

Phase 1 · Package, Core Names, App Shell   ██████████████████████████  100%  ✅ Complete
Phase 2 · Classic Win32 Backend            ████████████████████████░░   94%  🔄 In Progress
Phase 3 · AppKit Surface Expansion         ██████████████████████░░░░   84%  🔄 In Progress
Phase 4 · Demo Harness                     █████████████████████████░   98%  🔄 In Progress
Phase 5 · Tables, Lists, Collections       ██████████░░░░░░░░░░░░░░░░   39%  🔄 In Progress
Phase 6 · Toolbar API Parity               ████████░░░░░░░░░░░░░░░░░░   30%  🔄 In Progress
Phase 7 · WinFoundation Bridge             ███████████░░░░░░░░░░░░░░░   44%  🔄 In Progress
Phase 8 · Modern Windows Appearance        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase 9 · Auto Layout                      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase 10 · Focus, Accessibility, Polish    ███░░░░░░░░░░░░░░░░░░░░░░░   10%  ⏳ Pending
Phase 11 · Cross-Platform Test Apps        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; ⏸️ Deferred &nbsp;|&nbsp; 🚫 Blocked

Item tally: 8 ✅ of 55 tracked items. Percentages are effort estimates, not raw item counts — most items are open-ended surfaces that stay 🔄 while they deepen. (Overall dipped from 65% when Phase 11 added new scope.)

---

## Active Next

| Priority | Area | Task | Status | Notes |
|---:|---|---|---|---|
| 1 | Demo and controls | Keep moving through the next control surface after parking toolbar work. | 🔄 In Progress | Toolbar follow-up is tracked below, but not the active lane. Latest surface: `NSSavePanel`/`NSOpenPanel`. |
| 2 | Contracts | Add focused tests whenever a framework behavior becomes real, especially for controls that demos depend on. | 🔄 In Progress | Recent examples: save/open panels, toolbar custom views, resize propagation. |
| 3 | Documentation | Keep `CONTROL_PARITY.md` and this plan synchronized when a surface moves from placeholder to working. | 🔄 In Progress | Update progress estimates after meaningful feature batches. |

---

## Phase 1 — Package, Core Names, App Shell ✅ 100%

Initial project shape and runnable application shell.

| # | Item | Status | Notes |
|---|---|---|---|
| 1.1 | SwiftPM package | ✅ Done | `WinChocolate`, `WinFoundation`, demo, and contract tests exist. |
| 1.2 | AppKit-shaped core names | ✅ Done | `NSApplication`, `NSWindow`, `NSView`, responders, controls, menus. |
| 1.3 | Native app shell | ✅ Done | Message loop, windows list, key/main window tracking, Quit command. |
| 1.4 | Architecture docs | ✅ Done | `Docs/Architecture.md` and related tracking docs exist. |

---

## Phase 2 — Classic Win32 Backend 🔄 94%

Keep the classic backend real, testable, and available as a stable presentation option. Even after the modern appearance lands, the classic Win32 look remains a selectable presentation.

| # | Item | Status | Notes |
|---|---|---|---|
| 2.1 | Window and child HWND creation | ✅ Done | Top-level windows, child controls, cleanup. |
| 2.2 | Native message dispatch | ✅ Done | Commands, text changes, mouse, keyboard, window close, resize. |
| 2.3 | Core control peers | 🔄 In Progress | Many controls are native-backed; some are provisional or composed. |
| 2.4 | Toolbar backend | 🔄 In Progress | Classic `ToolbarWindow32`, flexible space, custom view slot support. |
| 2.5 | Visual polish | ⏳ Pending | Classic look is acceptable for now; modern appearance is separate. |

---

## Phase 3 — AppKit Surface Expansion 🔄 84%

Broaden source-compatible AppKit-style APIs while keeping mechanics hidden behind the framework.

| # | Item | Status | Notes |
|---|---|---|---|
| 3.1 | Common controls | 🔄 In Progress | Buttons, text, popup/combo, sliders, steppers, date picker, color well, etc. |
| 3.2 | Windows, panels, popovers, alerts | 🔄 In Progress | First slices exist; `NSSavePanel`/`NSOpenPanel` now run native comdlg32/shell dialogs with modal-response, file-type, multi-select, and folder-choose support. Richer chrome/dialog behavior remains. |
| 3.3 | View composition | 🔄 In Progress | Scroll/clip/split/visual-effect slices exist. |
| 3.4 | Source compatibility gaps | ⏳ Pending | Continue filling AppKit names as demo and ports need them. |

---

## Phase 4 — Demo Harness 🔄 98%

Use the demo as a visual smoke test and workflow exerciser.

| # | Item | Status | Notes |
|---|---|---|---|
| 4.1 | Main demo window | ✅ Done | Exercises core controls and state updates. |
| 4.2 | Page selector | ✅ Done | Moved to toolbar as a custom toolbar item. |
| 4.3 | Table/media/value pages | 🔄 In Progress | Good coverage, but should keep evolving with new controls. |
| 4.4 | Visual QA | 🔄 In Progress | Manual screenshots remain useful for layout and toolbar work. |

---

## Phase 5 — Tables, Lists, Collections 🔄 39%

Move table-like controls from first slices toward practical AppKit behavior.

| # | Item | Status | Notes |
|---|---|---|---|
| 5.1 | `NSTableView` | 🔄 In Progress | Columns, rows, selection, sorting, actions exist; editing/reuse/accessibility remain. |
| 5.2 | `NSOutlineView` | 🔄 In Progress | Flattening over table backend exists; disclosure UI and tree-table rendering remain. |
| 5.3 | `NSBrowser` | 🔄 In Progress | First composed column browser slice exists. |
| 5.4 | `NSCollectionView` | 🔄 In Progress | First fixed item-grid slice exists; layout engines and reuse remain. |

---

## Phase 6 — Toolbar API Parity 🔄 30%

Define and implement the AppKit toolbar contract before making more Windows rendering decisions. The source-of-truth API definition is `Docs/AppKitToolbarAPI.md`.

Design note: toolbars are the rare exception to the "look like Windows" rule — WinChocolate toolbars should keep the **Apple look and UI feel**, including the customization experience, and should eventually support several Apple looks (for example the older metallic style and the modern unified style). Current compromise: the customization panel mirrors the toolbar in a strip inside the panel instead of supporting drags into the real window toolbar; item 6.13 tracks switching to the real Apple behavior. The mirrored-strip panel now follows Apple's sheet layout (`NSToolbarCustomizationPanel`) with working drag insert/reorder/remove/default-restore and live toolbar updates.

| # | Item | Status | Notes |
|---|---|---|---|
| 6.1 | AppKit toolbar API inventory | 🔄 In Progress | Document the Apple-defined `NSToolbar`, `NSToolbarItem`, delegate, validation, customization, and autosave contract before further implementation work. |
| 6.2 | `NSWindow.toolbar` contract | ⏳ Pending | A window has an optional toolbar object; attaching, replacing, showing, hiding, and removing it should follow AppKit semantics independent of renderer. |
| 6.3 | `NSToolbar` model contract | ⏳ Pending | Cover `identifier`, visible item ordering, delegate ownership, selected item identifier, display mode, size mode, customization flags, visibility, and autosave name. |
| 6.4 | `NSToolbarItem` model contract | ⏳ Pending | Cover identifier, label, palette label, tool tip, tag, image, view, target/action, menu form representation, enabled/selected state, visibility priority, min/max size, and validation. |
| 6.5 | Delegate and item creation contract | ⏳ Pending | Mirror AppKit delegate responsibilities for allowed/default/selectable identifiers and item creation by identifier. |
| 6.6 | Standard item identifiers | ⏳ Pending | Define behavior for separator, space, flexible space, show-colors, show-fonts, print, customize toolbar, and any version-appropriate standard identifiers WinChocolate chooses to expose. |
| 6.7 | Customization contract | 🔄 In Progress | Apple-style sheet layout with drag insert/reorder/remove, default-set restore, duplicate rules for structural items, and display-mode popup now work through `NSToolbarCustomizationPanel`. Remaining: palette filtering rules, selectable-item behavior, richer labels. |
| 6.8 | Autosave and restoration contract | ⏳ Pending | Define `autosavesConfiguration`, configuration identifiers, persistence shape, reset behavior, and migration/versioning expectations. |
| 6.9 | Overflow and item visibility contract | ⏳ Pending | Define what happens when the toolbar is too narrow, including flexible space, overflow menu behavior, visibility priority, and custom view constraints. |
| 6.10 | Toolbar rendering implementation | ⏸️ Deferred | Choose the Windows renderer only after the API contract is settled. Current composed renderer is provisional. |
| 6.11 | Customization visual polish | ⏸️ Deferred | Make customization dialog match AppKit behavior and appearance after mechanics and API are aligned. |
| 6.12 | SF Symbols strategy | ⏸️ Deferred | Define legal/technical mapping from SF-symbol names to Windows-native or bundled assets. |
| 6.13 | Apple drag-to-real-toolbar customization | ⏳ Pending | Attempt to replace the mirrored-strip compromise with Apple's real behavior: drag items directly between the customization palette and the live window toolbar, with the sheet attached under the toolbar. |

---

## Phase 7 — WinFoundation Bridge 🔄 44%

Bridge enough Foundation-shaped API to keep WinChocolate source-compatible while the local Windows Swift toolchain cannot import real Foundation.

| # | Item | Status | Notes |
|---|---|---|---|
| 7.1 | `URL`, `Data`, `Date`, `IndexSet`, `IndexPath`, `UUID`, `Bundle` | 🔄 In Progress | First useful slices exist with contracts. |
| 7.2 | Real Foundation canary | 🔄 In Progress | `USE_REAL_FOUNDATION` path remains the eventual target. |
| 7.3 | Resource and file behavior | 🔄 In Progress | Needed by image loading, panels, documents. |
| 7.4 | Broader Foundation compatibility | ⏳ Pending | Add only when AppKit/API needs justify it. |

---

## Phase 8 — Modern Windows Appearance ⏳ 0%

Add a modern Windows presentation while keeping the classic backend available.

Goal: one appearance switch selects either the current classic Win32 look or the modern Windows look, with no other application code changes. The modern look becomes the WinChocolate default once it reaches parity, and the classic look remains selectable indefinitely.

| # | Item | Status | Notes |
|---|---|---|---|
| 8.1 | Appearance strategy | ⏳ Pending | Decide modern backend versus themed wrappers versus hybrid. |
| 8.2 | Backend/appearance selection API | ⏳ Pending | Public switch to select classic Win32 or modern presentation; app code should not change when switching presentation style. |
| 8.3 | Modern control visuals | ⏳ Pending | Fluent/WinUI-like look is future work. |
| 8.4 | Modern look becomes the default | ⏳ Pending | After modern visuals reach control parity, new apps default to the modern look with classic still selectable. |

---

## Phase 9 — Auto Layout ⏳ 0%

Add AppKit-shaped layout APIs after the core frame-based control surface is stable.

| # | Item | Status | Notes |
|---|---|---|---|
| 9.1 | Constraint model | ⏳ Pending | `NSLayoutConstraint`, anchors, priorities. |
| 9.2 | Intrinsic sizes | ⏳ Pending | Needed for controls, toolbar items, and forms. |
| 9.3 | Migration path from frames | ⏳ Pending | Demos can stay frame-based until constraints are real. |

---

## Phase 10 — Focus, Accessibility, Polish ⏳ 10%

Turn first slices into a framework that feels deliberate.

| # | Item | Status | Notes |
|---|---|---|---|
| 10.1 | Focus and key loop audit | ⏳ Pending | Dedicated pass for first responder, Tab behavior, and focus indicators. |
| 10.2 | Accessibility | ⏳ Pending | Native names, roles, keyboard behavior, assistive tech expectations. |
| 10.3 | Public API docs | 🔄 In Progress | Keep public types and members documented. |
| 10.4 | Large-file review | ⏳ Pending | Use `NEEDS_HUMAN.md` for files/classes that grow beyond maintainable size. |

---

## Phase 11 — Cross-Platform Test Apps ⏳ 0%

Prove the primary goal with real applications. Each app is written once against the Apple API and must **compile and run unmodified on native macOS and on Windows**, differing only in conditional framework inclusion:

```swift
#if canImport(AppKit)
import AppKit
#else
import WinChocolate
#endif
```

These apps are consumers, not framework extensions: any helper an app needs to behave correctly is a design signal that the capability belongs in WinChocolate (and any Mac-only API it needs is a parity gap to fill). Each app deliberately stresses a different API surface.

| # | Item | Status | Notes |
|---|---|---|---|
| 11.1 | Conditional import pattern | ⏳ Pending | Settle the single `#if canImport(AppKit)` inclusion idiom (and Foundation/WinFoundation equivalent) so app sources stay byte-identical on both platforms. No other `#if os(...)` blocks allowed in app code. |
| 11.2 | Notes app | ⏳ Pending | List-plus-editor layout: `NSTableView` or source list, `NSTextView` editing, search field, toolbar, save/open panels, document persistence through the Foundation bridge. |
| 11.3 | Contact manager app | ⏳ Pending | Form-heavy CRUD: table with sorting/selection, text fields, popups, date picker, image well for contact photos, master-detail split view. |
| 11.4 | Minesweeper app | ⏳ Pending | Custom-view game: custom drawing, mouse hit-testing (left/right click), timers, menus, alerts for win/lose, window sizing for grid presets. |
| 11.5 | Text editor app | ⏳ Pending | Document workflow: `NSTextView` at depth, open/save panels with file types, dirty-state tracking, fonts, find/replace, multiple windows. |
| 11.6 | Dual-platform build harness | ⏳ Pending | SwiftPM/Xcode targets and scripts so each app builds and launches from one source tree on macOS and Windows; a check script proves "unmodified" stays true. |
| 11.7 | Parity gap log | ⏳ Pending | Record every place an app would have needed platform-specific code; feed each gap back into Phases 3-10 as concrete work items. |

---

## Maintenance Rules

- Update this dashboard after meaningful feature batches, not every tiny edit.
- Keep `CONTROL_PARITY.md` as the detailed control matrix.
- Add tests for behavior that becomes framework contract rather than demo-only wiring.
- Keep toolbar follow-up deferred until the project intentionally returns to that phase.

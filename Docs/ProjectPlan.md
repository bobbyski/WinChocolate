# WinChocolate Build Plan

## Summary

WinChocolate is an AppKit-shaped Swift framework for Windows. The near-term goal is a dependable classic Win32 backend with enough Cocoa/AppKit compatibility to port small apps, while preserving a path toward modern Windows visuals, richer layout, and deeper Foundation parity.

This plan is the high-level project tracker. `CONTROL_PARITY.md` remains the detailed control-by-control map, and `Architecture.md` remains the design overview.

## Dashboard

```text
Overall Progress  ####################------------  64%   (current estimate)

Phase 1 - Package, Core Names, App Shell      ############################## 100%  Done
Phase 2 - Classic Win32 Backend               ############################--  94%  In Progress
Phase 3 - AppKit Surface Expansion            ########################------  82%  In Progress
Phase 4 - Demo Harness                        #############################-  98%  In Progress
Phase 5 - Tables, Lists, Collections          ############------------------  39%  In Progress
Phase 6 - Toolbar API Parity                  ######------------------------  20%  In Progress
Phase 7 - WinFoundation Bridge                #############-----------------  44%  In Progress
Phase 8 - Modern Windows Appearance           ------------------------------   0%  Pending
Phase 9 - Auto Layout                         ------------------------------   0%  Pending
Phase 10 - Focus, Accessibility, Polish       ###---------------------------  10%  Pending
```

Status key: `Done`, `In Progress`, `Deferred`, `Pending`, `Blocked`

## Active Next

| Priority | Area | Task | Status | Notes |
|---:|---|---|---|---|
| 1 | Demo and controls | Keep moving through the next control surface after parking toolbar work. | In Progress | Toolbar follow-up is tracked below, but not the active lane. |
| 2 | Contracts | Add focused tests whenever a framework behavior becomes real, especially for controls that demos depend on. | In Progress | Recent examples: toolbar custom views, resize propagation. |
| 3 | Documentation | Keep `CONTROL_PARITY.md` and this plan synchronized when a surface moves from placeholder to working. | In Progress | Update progress estimates after meaningful feature batches. |

## Phase 1 - Package, Core Names, App Shell - 100%

Initial project shape and runnable application shell.

| # | Item | Status | Notes |
|---|---|---|---|
| 1.1 | SwiftPM package | Done | `WinChocolate`, `WinFoundation`, demo, and contract tests exist. |
| 1.2 | AppKit-shaped core names | Done | `NSApplication`, `NSWindow`, `NSView`, responders, controls, menus. |
| 1.3 | Native app shell | Done | Message loop, windows list, key/main window tracking, Quit command. |
| 1.4 | Architecture docs | Done | `Docs/Architecture.md` and related tracking docs exist. |

## Phase 2 - Classic Win32 Backend - 94%

Keep the classic backend real, testable, and available as a stable presentation option.

| # | Item | Status | Notes |
|---|---|---|---|
| 2.1 | Window and child HWND creation | Done | Top-level windows, child controls, cleanup. |
| 2.2 | Native message dispatch | Done | Commands, text changes, mouse, keyboard, window close, resize. |
| 2.3 | Core control peers | In Progress | Many controls are native-backed; some are provisional or composed. |
| 2.4 | Toolbar backend | In Progress | Classic `ToolbarWindow32`, flexible space, custom view slot support. |
| 2.5 | Visual polish | Pending | Classic look is acceptable for now; modern appearance is separate. |

## Phase 3 - AppKit Surface Expansion - 82%

Broaden source-compatible AppKit-style APIs while keeping mechanics hidden behind the framework.

| # | Item | Status | Notes |
|---|---|---|---|
| 3.1 | Common controls | In Progress | Buttons, text, popup/combo, sliders, steppers, date picker, color well, etc. |
| 3.2 | Windows, panels, popovers, alerts | In Progress | First slices exist; richer chrome/dialog behavior remains. |
| 3.3 | View composition | In Progress | Scroll/clip/split/visual-effect slices exist. |
| 3.4 | Source compatibility gaps | Pending | Continue filling AppKit names as demo and ports need them. |

## Phase 4 - Demo Harness - 98%

Use the demo as a visual smoke test and workflow exerciser.

| # | Item | Status | Notes |
|---|---|---|---|
| 4.1 | Main demo window | Done | Exercises core controls and state updates. |
| 4.2 | Page selector | Done | Moved to toolbar as a custom toolbar item. |
| 4.3 | Table/media/value pages | In Progress | Good coverage, but should keep evolving with new controls. |
| 4.4 | Visual QA | In Progress | Manual screenshots remain useful for layout and toolbar work. |

## Phase 5 - Tables, Lists, Collections - 39%

Move table-like controls from first slices toward practical AppKit behavior.

| # | Item | Status | Notes |
|---|---|---|---|
| 5.1 | `NSTableView` | In Progress | Columns, rows, selection, sorting, actions exist; editing/reuse/accessibility remain. |
| 5.2 | `NSOutlineView` | In Progress | Flattening over table backend exists; disclosure UI and tree-table rendering remain. |
| 5.3 | `NSBrowser` | In Progress | First composed column browser slice exists. |
| 5.4 | `NSCollectionView` | In Progress | First fixed item-grid slice exists; layout engines and reuse remain. |

## Phase 6 - Toolbar API Parity - 20%

Define and implement the AppKit toolbar contract before making more Windows rendering decisions. The source-of-truth API definition is `Docs/AppKitToolbarAPI.md`.

| # | Item | Status | Notes |
|---|---|---|---|
| 6.1 | AppKit toolbar API inventory | In Progress | Document the Apple-defined `NSToolbar`, `NSToolbarItem`, delegate, validation, customization, and autosave contract before further implementation work. |
| 6.2 | `NSWindow.toolbar` contract | Pending | A window has an optional toolbar object; attaching, replacing, showing, hiding, and removing it should follow AppKit semantics independent of renderer. |
| 6.3 | `NSToolbar` model contract | Pending | Cover `identifier`, visible item ordering, delegate ownership, selected item identifier, display mode, size mode, customization flags, visibility, and autosave name. |
| 6.4 | `NSToolbarItem` model contract | Pending | Cover identifier, label, palette label, tool tip, tag, image, view, target/action, menu form representation, enabled/selected state, visibility priority, min/max size, and validation. |
| 6.5 | Delegate and item creation contract | Pending | Mirror AppKit delegate responsibilities for allowed/default/selectable identifiers and item creation by identifier. |
| 6.6 | Standard item identifiers | Pending | Define behavior for separator, space, flexible space, show-colors, show-fonts, print, customize toolbar, and any version-appropriate standard identifiers WinChocolate chooses to expose. |
| 6.7 | Customization contract | Pending | Define AppKit-style palette behavior, drag/reorder/add/remove, default set restoration, allowed item filtering, duplicate rules, and user-visible labels. |
| 6.8 | Autosave and restoration contract | Pending | Define `autosavesConfiguration`, configuration identifiers, persistence shape, reset behavior, and migration/versioning expectations. |
| 6.9 | Overflow and item visibility contract | Pending | Define what happens when the toolbar is too narrow, including flexible space, overflow menu behavior, visibility priority, and custom view constraints. |
| 6.10 | Toolbar rendering implementation | Deferred | Choose the Windows renderer only after the API contract is settled. Current composed renderer is provisional. |
| 6.11 | Customization visual polish | Deferred | Make customization dialog match AppKit behavior and appearance after mechanics and API are aligned. |
| 6.12 | SF Symbols strategy | Deferred | Define legal/technical mapping from SF-symbol names to Windows-native or bundled assets. |

## Phase 7 - WinFoundation Bridge - 44%

Bridge enough Foundation-shaped API to keep WinChocolate source-compatible while the local Windows Swift toolchain cannot import real Foundation.

| # | Item | Status | Notes |
|---|---|---|---|
| 7.1 | `URL`, `Data`, `Date`, `IndexSet`, `IndexPath`, `UUID`, `Bundle` | In Progress | First useful slices exist with contracts. |
| 7.2 | Real Foundation canary | In Progress | `USE_REAL_FOUNDATION` path remains the eventual target. |
| 7.3 | Resource and file behavior | In Progress | Needed by image loading, panels, documents. |
| 7.4 | Broader Foundation compatibility | Pending | Add only when AppKit/API needs justify it. |

## Phase 8 - Modern Windows Appearance - 0%

Add a modern Windows presentation while keeping the classic backend available.

| # | Item | Status | Notes |
|---|---|---|---|
| 8.1 | Appearance strategy | Pending | Decide modern backend versus themed wrappers versus hybrid. |
| 8.2 | Backend/appearance selection API | Pending | App code should not change when switching presentation style. |
| 8.3 | Modern control visuals | Pending | Fluent/WinUI-like look is future work. |

## Phase 9 - Auto Layout - 0%

Add AppKit-shaped layout APIs after the core frame-based control surface is stable.

| # | Item | Status | Notes |
|---|---|---|---|
| 9.1 | Constraint model | Pending | `NSLayoutConstraint`, anchors, priorities. |
| 9.2 | Intrinsic sizes | Pending | Needed for controls, toolbar items, and forms. |
| 9.3 | Migration path from frames | Pending | Demos can stay frame-based until constraints are real. |

## Phase 10 - Focus, Accessibility, Polish - 10%

Turn first slices into a framework that feels deliberate.

| # | Item | Status | Notes |
|---|---|---|---|
| 10.1 | Focus and key loop audit | Pending | Dedicated pass for first responder, Tab behavior, and focus indicators. |
| 10.2 | Accessibility | Pending | Native names, roles, keyboard behavior, assistive tech expectations. |
| 10.3 | Public API docs | In Progress | Keep public types and members documented. |
| 10.4 | Large-file review | Pending | Use `NEEDS_HUMAN.md` for files/classes that grow beyond maintainable size. |

## Maintenance Rules

- Update this dashboard after meaningful feature batches, not every tiny edit.
- Keep `CONTROL_PARITY.md` as the detailed control matrix.
- Add tests for behavior that becomes framework contract rather than demo-only wiring.
- Keep toolbar follow-up deferred until the project intentionally returns to that phase.

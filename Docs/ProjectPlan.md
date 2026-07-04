# WinChocolate — Build Plan

## Summary

WinChocolate is an AppKit-shaped Swift framework for Windows. Apple AppKit API compatibility is the project's primary goal: apps are built with the Apple API and look like Windows apps. The near-term focus is a dependable classic Win32 backend with enough Cocoa/AppKit compatibility to port small apps, while preserving a path toward modern Windows visuals, richer layout, and deeper Foundation parity. A Linux sibling, **LinChocolate**, follows once Windows is going — same Apple API in, native Linux look out; it has its own plan in `Docs/LinChocolatePlan.md`.

This plan is the high-level project tracker. `CONTROL_PARITY.md` remains the detailed control-by-control map, and `Architecture.md` remains the design overview.

## Project Goals

1. **PRIMARY GOAL — Apple AppKit API compatibility.** WinChocolate exists so that almost all Mac AppKit programs build and run on Windows by swapping `import AppKit` for `import WinChocolate`. Application code is written against the Apple API — AppKit names, types, delegates, and behavior — while the controls render as native Windows controls. For most controls the app should *look* like a Windows app but be *built* with the Apple API. When any design decision conflicts with this goal, Apple API compatibility wins. (Deliberate exception: toolbars keep the Apple look and feel — see Phase 6.)
2. **Selectable presentation.** Applications should eventually be able to select either the current classic Win32 look or the more modern Windows look through one switch, with no other application code changes. The classic look stays fully supported; the modern look becomes the default later in the plan once Phase 8 reaches parity.
3. **Real native backing.** AppKit-shaped API in front, honest Windows implementation behind a narrow backend boundary, kept testable through the in-memory backend and contract tests.

---

## Dashboard

```text
Overall Progress                           ██████████████░░░░░░░░░░░░░░░░░   44%  (per-item estimate)

Phase 1 · Package, Core Names, App Shell   ██████████████████████████  100%  ✅ Complete
Phase 2 · Classic Win32 Backend            ██████████████████████████  100%  ✅ Complete
Phase 3 · AppKit Surface Expansion         █████████████████░░░░░░░░░   67%  🔄 In Progress
Phase 4 · Demo Harness                     █████████████████████░░░░░   80%  🔄 In Progress
Phase 5 · Tables, Lists, Collections       █████░░░░░░░░░░░░░░░░░░░░░   21%  🔄 In Progress
Phase 6 · Toolbar API Parity               ██████████░░░░░░░░░░░░░░░░   37%  🔄 In Progress
Phase 7 · WinFoundation Bridge             ██████░░░░░░░░░░░░░░░░░░░░   24%  🔄 In Progress
Phase 8 · Modern Windows Appearance        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase 9 · Auto Layout                      ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase 10 · Focus, Accessibility, Polish    ███████░░░░░░░░░░░░░░░░░░░   27%  🔄 In Progress
Phase 11 · Cross-Platform Test Apps        ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; ⏸️ Deferred &nbsp;|&nbsp; 🚫 Blocked

**How percentages are computed:** each item carries a completion estimate (✅ = 100%, 🔄 = the `~NN%` shown in its notes, ⏳/⏸️ = 0%); a phase is the average of its items, and Overall is the average across all 89 tracked items (17 ✅). LinChocolate (the Linux port) has its own plan in `Docs/LinChocolatePlan.md` and does not count here. Recomputed 2026-07-01 after enumerating the missing AppKit surfaces — Overall dropped from 64% because tracked scope grew from 55 to 79 items, not because work regressed. 2026-07-02: added 10.7 (per-monitor DPI awareness), growing scope to 80 items; later that day 3.8 moved 70%→90% (floating panels + live apply). 2026-07-03: 3.3 closed (wheel scrolling + magnification) and 3.11 closed (rich text attributes over the rich-edit peer); then, after clarifying that broad AppKit coverage — not the Phase 11 apps — is the target, items 3.16-3.23 and 9.5 were added, and later the same day 3.24 (symbol images, absorbing 6.12) — scope 80→89, dropping Phase 3 from 88% to 55% and Overall from 46% to 41% on scope growth alone. LinChocolate was briefly a Phase 12 here before moving to its own plan. Since then 3.17 (pasteboard), 3.16 (text system objects, ~80%), and 3.20 (font traits) landed, lifting Phase 3 to 66% and Overall to 44%. 2026-07-03 (later): a common-control depth pass advanced 3.1 (slider ticks/vertical, text alignment/placeholder, combo visible-items/completion, button key equivalents, segmented keyboard, level-indicator thresholds) and 3.2 (popover outside-click dismiss/chrome/delegate, window size limits) from 80% to 88% each — Phase 3 to 67%.

---

## Working method — milestones

Each phase is a milestone, and work always drives toward completing the **current** milestone before advancing. A milestone is never left blocked by a later one: if a current-phase item depends on an item scheduled for a future phase, that future item is **pulled into the current phase and done now**, then renumbered here with percentages recomputed. (Already applied: `Timer` and `FileManager` were pulled from Phase 7 into Phase 3 to unblock `NSDocument` autosave/close — see 3.14 and 3.15.)

**Scope comes from the AppKit surface itself, not from the test apps.** The goal is that most AppKit programs build and run (at least their UI); the Phase 11 apps only demonstrate that. When any work reveals a missing AppKit capability, it is added here as a first-class item in the phase it belongs to — never deferred "until a test app needs it."

---

## Active Next

| Priority | Area | Task | Status | Notes |
|---:|---|---|---|---|
| 1 | Demo and controls | Keep moving through the next control surface. | 🔄 In Progress | Latest surface: rich text attributes closed out 3.11 (rich-edit peer, per-range font/color, selection-scoped `changeFont`). The milestone now includes the newly enumerated AppKit surfaces 3.16-3.24. Latest surface: a common-control depth pass on 3.1/3.2 (slider ticks/vertical, text alignment, combo visible-items, button key equivalents, segmented keyboard, level-indicator thresholds, popover dismiss, window size limits — both to ~88%). Suggested order for the rest: font traits (3.20), screens/window state (3.19), hover tracking (3.21), drag and drop (3.18), symbol images (3.24, design questions first), printing (3.22) — alongside panel/alert chrome depth (3.2/3.7/3.8), progress/image leftovers (3.12/3.13), and open-ended 3.1/3.4. |
| 2 | Contracts | Add focused tests whenever a framework behavior becomes real, especially for controls that demos depend on. | 🔄 In Progress | Recent examples: save/open panels, toolbar customization, resize propagation. |
| 3 | Documentation | Keep `CONTROL_PARITY.md` and this plan synchronized when a surface moves from placeholder to working. | 🔄 In Progress | Update item estimates after meaningful feature batches and recompute phase percentages. |

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

## Phase 2 — Classic Win32 Backend ✅ 100%

Keep the classic backend real, testable, and available as a stable presentation option. Even after the modern appearance lands, the classic Win32 look remains a selectable presentation. Deeper AppKit behavior on top of these peers continues in Phases 3, 5, and 6.

| # | Item | Status | Notes |
|---|---|---|---|
| 2.1 | Window and child HWND creation | ✅ Done | Top-level windows, child controls, cleanup. AppKit `contentRect` semantics honored via `AdjustWindowRectEx`. |
| 2.2 | Native message dispatch | ✅ Done | Commands, text changes, mouse, keyboard, window close, resize; subclassed controls own their mouse capture. |
| 2.3 | Core control peers | ✅ Done | Every control with a classic Win32 counterpart uses it natively (slider is `msctls_trackbar32`, stepper is `msctls_updown32`); remaining composed controls (segmented, color well, path control) are composed by design. |
| 2.4 | Toolbar backend | ✅ Done | The composed `NSToolbarView` renderer is the classic toolbar; the native `ToolbarWindow32` path was retired (see `Docs/ToolbarArchitecture.md`). |
| 2.5 | Visual polish | ✅ Done | Standard Segoe UI control font, chrome-matched toolbar with hairline, transparent-background fixes, separator styles. Modern appearance remains Phase 8. |

---

## Phase 3 — AppKit Surface Expansion 🔄 84%

Broaden source-compatible AppKit-style APIs while keeping mechanics hidden behind the framework. Items 3.5, 3.6, 3.9, 3.11, 3.14, and 3.15 are prerequisites for the Phase 11 cross-platform apps (3.14/3.15 were pulled forward from Phase 7 under the milestone rule above). Items 3.16-3.24 (added 2026-07-03) enumerate the broader AppKit surfaces most real applications rely on — text system objects, pasteboard, drag and drop, screens/window state, font traits, hover tracking, printing, symbol images — because the goal is running most AppKit UIs, not just the Phase 11 proofs.

| # | Item | Status | Notes |
|---|---|---|---|
| 3.1 | Common controls | 🔄 In Progress | ~88% — buttons, text, popup/combo, sliders, steppers, date picker, color well, etc. exist with value/action bridges. **Landed 2026-07-03:** `NSSlider` tick marks (`numberOfTickMarks`/`allowsTickMarkValuesOnly`/`closestTickMarkValue`, `TBS_AUTOTICKS`+`TBM_SETTICFREQ`) and vertical orientation (`TBS_VERT`); `NSTextField.alignment` (`ES_CENTER`/`ES_RIGHT`, verified) and `placeholderString` (`EM_SETCUEBANNER` — call is correct but the cue only renders once comctl32 v6 visual styles are enabled, tied to 8.x/10.7); `NSComboBox.numberOfVisibleItems` (dropdown height) and `completes` (tested `completedString(forPrefix:)` + commit-time fill; live as-you-type suffix selection over the native combo edit stays future work); `NSButton.keyEquivalent` dispatch (Return/Escape route to default/cancel buttons through the key window's view chain, skipping multiline text views, verified); `NSSegmentedControl` arrow-key selection (skips disabled segments); `NSLevelIndicator.warningValue`/`criticalValue` bar recoloring (`PBM_SETBARCOLOR`, amber/red, verified). **Remaining behavioral depth:** **NSButton** — `bezelStyle`, `image`/`imagePosition`/`alternateTitle`, `sound`. **NSTextField** — `NSFormatter`/`formatter`, `NSTextFieldDelegate.controlTextDidChange`/`DidEndEditing`, `bezelStyle`/`isBezeled`, `maximumNumberOfLines`. **NSSecureTextField** — deeper secure paste/autofill. **NSComboBox** — live autocompletion suffix selection, `hasVerticalScroller`, `NSComboBoxDataSource`. **NSSearchField** — search chrome: cancel button, recents dropdown UI, magnifier icon (behaviors already work). **NSTokenField** — visual token chips, completion, delegate. **NSPopUpButton** — pull-down menu mode, `selectedTag`, per-item images, `autoenablesItems`. **NSSlider** — `altIncrementValue`, `tickMarkPosition`. **NSStepper** — `autorepeat` native wiring. **NSSegmentedControl** — visual styles, per-segment `image`/`menu`. **NSLevelIndicator** — `isEditable`, discrete/rating/relevancy styles, tick marks. **NSDatePicker** — `datePickerStyle` (clock-and-calendar `SysMonthCal32`), `datePickerElements`, delegate. **NSScroller** — knob/arrow parts, overlay style. **NSPathControl** — breadcrumb click/selection. **NSImageView** — template/symbol images (ties to 3.24), `isEditable`/drag. **NSColorWell** — `NSColorWell.Style`. Detailed per-control status stays in `CONTROL_PARITY.md`. |
| 3.2 | Windows, panels, popovers, alerts | 🔄 In Progress | ~80% — save/open panels over comdlg32/shell, modal sessions, and sheets (`NSWindow.beginSheet`/`endSheet`, app-modal positioned under the title area as the classic compromise). `NSSavePanel`/`NSOpenPanel.beginSheetModal(for:)` pins the OS file dialog under the parent's title area via a thread-local CBT hook plus a brief timer pin — keeps the modern Explorer style, which an OFN template hook would downgrade. `NSAlert.beginSheetModal` presents a chromeless (borderless) composed panel attached under the title area; borderless top-level windows now map to `WS_POPUP\|WS_BORDER`. **Landed 2026-07-03:** `NSPopover` outside-click dismiss for `.transient`/`.semitransient` (a `WH_MOUSE` thread hook, verified via contract test), a solid background chrome, and `NSPopoverDelegate` (`popoverWillShow`/`DidShow`/`WillClose`/`DidClose`); `NSWindow.contentMinSize`/`contentMaxSize`/`minSize`/`maxSize` enforced through `WM_GETMINMAXINFO`. **Remaining by area:** **NSPopover** — arrow/beak drawing, `preferredEdge` flip-when-clipped, `animates` slide/fade. **Sheets** — window-modal slide-down animation (currently app-modal, positioned not animated), parent-window dimming, multiple-sheet queueing, `NSWindow.sheetParent`/`attachedSheet`. **NSAlert** — help button (`showsHelp`/`NSAlertDelegate`), custom `icon` image, suppression-state persistence (needs `UserDefaults`, 7.7). **NSWindow** — `styleMask` `.fullSizeContentView`/`.unifiedTitleAndToolbar`, `isMovableByWindowBackground`, `standardWindowButton(_:)`, `collectionBehavior`, `titlebarAppearsTransparent`, `isRestorable`/state restoration. **NSPanel** — enforce the already-modeled `becomesKeyOnlyIfNeeded`/`worksWhenModal` (stored but not gated), `NSOpenPanel`/`NSSavePanel` accessory views, `styleMask` `.nonactivatingPanel`, `.hudWindow` styling. Detailed status stays in `CONTROL_PARITY.md`. |
| 3.3 | View composition | ✅ Done | Scroll/clip/split/visual-effect compose. Split dividers track mouse drags (clamped, classic center line, resize cursor, `NSSplitViewDelegate`). Scrolling: `enclosingScrollView`, `scrollToVisible(_:)`, and mouse-wheel content scrolling (`scrollWheel` with `lineScroll` distances, Shift-for-horizontal, `WM_MOUSEHWHEEL`; the wheel walks up to the nearest scrolling ancestor when over a native child). Magnification: `magnification`/`setMagnification(_:centeredAt:)`/`magnify(toFit:)` scale custom-drawn document views through a backend content scale (GDI world transform), with anchored zoom and scaled scrollbar geometry. Known limits, tracked ahead: no zoom gestures (Phase 8), native child controls don't scale, and event locations stay in window coordinates under magnification. |
| 3.4 | Source compatibility gaps | 🔄 In Progress | ~20% — continue filling AppKit names as demo and ports need them; ongoing by nature. |
| 3.5 | Custom drawing | ✅ Done | `NSView.draw(_:)` with `NSGraphicsContext.current`, `NSBezierPath`, `NSColor` set/fill/stroke, `NSRectFill`/`NSFrameRect`, `needsDisplay`, `String.draw(at:withAttributes:)`, `NSImage.draw(in:)` via GDI+/StretchBlt, real text metrics via GetTextExtentPoint32W. `NSGradient` (rect and path fills at any angle over a GDI+ rect-with-angle line brush) plus clipping: `NSBezierPath.addClip()`, `NSRectClip`, `NSGraphicsContext.saveGraphicsState`/`restoreGraphicsState` over SaveDC/SelectClipPath/RestoreDC. |
| 3.6 | Event and responder depth | ✅ Done | Right/middle mouse, double-click `clickCount`, scroll wheel under the cursor, `NSCursor` (set/push/pop over WM_SETCURSOR), and menu key equivalents through the wndproc. Cursor rects: `addCursorRect`/`resetCursorRects`/`discardCursorRects` + `NSWindow.invalidateCursorRects(for:)`, resolved per hover position in WM_SETCURSOR (split-view dividers and the demo canvas use them). Key equivalents dispatch AppKit-style: key window's view chain (`performKeyEquivalent`) first, then the main menu. |
| 3.7 | `NSAlert` custom dialog | 🔄 In Progress | ~95% — composed modal panel with custom buttons, suppression checkbox, style icon badge, `accessoryView`, and `beginSheetModal(for:)`; panels size to measured message text. Plain alerts keep the native message box. |
| 3.8 | Standard panels | 🔄 In Progress | ~92% — `NSColorPanel`/`NSFontPanel` are composed floating utility panels (topmost tool windows that hide on app deactivate, hide-not-destroy on close) with live apply: color changes flow to the active color well and `changeColor(_:)`; font selections update `NSFontManager` and send `changeFont(_:)` down the key/main window's responder chain (`convert(_:)` returns the pick; `NSTextView` adopts it). Installed families come from `EnumFontFamiliesExW`. Supporting surface: `NSWindow.level`/`orderFront`/`orderOut`/`canBecomeKey`/`canBecomeMain`, working `NSPanel.isFloatingPanel`/`hidesOnDeactivate`, `.utilityWindow` style. The font panel now offers Regular/Bold/Italic/Bold Italic typefaces (3.20). Missing: HSB/alpha color modes. |
| 3.9 | `NSDocument` architecture | ✅ Done | `NSDocument` (read/write/data overrides, dirty tracking, save/saveAs through `NSSavePanel`), `NSDocumentController` (documents, recents, `openDocument`/`newDocument`, `winDocumentClass` hook), and `NSWindowController` (showWindow/close, `*`-prefixed dirty title sync, make/add/show). `NSWindowDelegate.windowShouldClose` vetoes a title-bar close (WM_CLOSE consults the framework); the controller runs the AppKit Save/Cancel/Don't-Save sheet on close. Autosave-in-place for opted-in classes on a 30s `Timer`. Quit now waits for the last window, so closing a document window leaves the app running. Missing: document types from metadata. |
| 3.10 | Menu depth | ✅ Done | Context menus, Ctrl-mapped key equivalents with right-aligned accelerator text ("Ctrl+Z"), check-state marks, and live validation: `NSMenuItemValidation`/`autoenablesItems`/`NSMenu.update()` run on WM_INITMENUPOPUP, which now rebuilds the native items wholesale — added/removed/retitled items (dynamic "Undo Typing" titles, recent-file lists) always display current state. |
| 3.11 | `NSTextView` depth | ✅ Done | `selectedRange`/`NSRange`, `insertText(_:replacementRange:)`, `scrollRangeToVisible`, `NSTextViewDelegate.textDidChange`, read-only sync, fonts. Undo: `NSUndoManager`, `NSWindow.undoManager`, `allowsUndo` with word-granular typing coalescing, Edit-menu Cmd+Z/Cmd+Shift+Z. Find/replace: `NSTextFinder.Action` tags + `performTextFinderAction(_:)` and a composed app-modal Find panel. Rich text: `isRichText` realizes a rich-edit peer (`RICHEDIT50W` with `EM_SETCHARFORMAT`), `setFont(_:range:)`/`setTextColor(_:range:)` format ranges, and `changeFont(_:)` converts the selection in rich views. Attribute storage/enumeration and RTF persistence continue as 3.16. |
| 3.12 | Progress indicator completion | 🔄 In Progress | ~80% — `isIndeterminate`, `.spinning` style, and `startAnimation`/`stopAnimation` animate via a native-timer sweep (the classic theme lacks marquee support). Missing: a true spinner visual in the modern appearance. |
| 3.13 | `NSImage` formats | 🔄 In Progress | ~80% — PNG/JPEG/GIF/ICO decode via the GDI+ flat API (BMP keeps the fast LoadImageW path) for both `NSImageView` and `NSImage.draw(in:)`; ICO verified through the demo's generated icon. Missing: template images, per-path bitmap caching. |
| 3.14 | `Timer` and run-loop scheduling | ✅ Done | *(Pulled forward from 7.6 to unblock 3.9 autosave.)* `Timer.scheduledTimer(withTimeInterval:repeats:block:)` over a backend run-loop timer (`SetTimer` thread timers dispatched by every message loop, including modal sessions). The scheduling retains the timer until `invalidate()`, matching Foundation's run-loop ownership; one-shot timers self-invalidate after firing. Selector-based scheduling remains future work. |
| 3.15 | `FileManager` | ✅ Done | *(Pulled forward from 7.5 to unblock 3.9 document persistence.)* `FileManager.default` with existence checks (`isDirectory` via an `ObjCBool` shim), sorted directory listing (path and URL forms), `createDirectory` with intermediates, recursive remove/copy, move, `temporaryDirectory`, and `urls(for:in:)` known folders (Documents/Desktop/AppData/caches over `SHGetFolderPathW`). Attribute dictionaries, enumerators, and delegates remain future work. |
| 3.16 | Rich text system objects | 🔄 In Progress | ~80% — `NSAttributedString` stores per-range attribute runs with `attributes(at:effectiveRange:)`, `attribute(_:at:effectiveRange:)`, `enumerateAttributes`/`enumerateAttribute` (with `.reverse`), and `attributedSubstring(from:)`. `NSMutableAttributedString` edits text and runs (`replaceCharacters` with attribute inheritance, `setAttributes`/`addAttribute(s)`/`removeAttribute`, `append`/`insert`/`deleteCharacters`, `beginEditing`/`endEditing` batching). New keys: `.backgroundColor`, `.underlineStyle`, `.strikethroughStyle` (+ `NSUnderlineStyle`); underline/strikethrough apply natively via the extended rich-edit format. `NSTextStorage` syncs into `NSTextView` (storage edits update text and runs on the native peer; native typing syncs plain text back). RTF **writing** works — `rtf(from:documentAttributes:)` with font/color tables and unicode escapes, staged on the pasteboard by rich-view copies and verified against the system clipboard. Remaining: RTF reading, paragraph styles/alignment, and the layout-manager pipeline. |
| 3.17 | `NSPasteboard` | 🔄 In Progress | ~90% — `NSPasteboard.general` runs over the Windows clipboard: typed string read/write (`CF_UNICODETEXT`), `.rtf` and `.png` data over registered clipboard formats ("Rich Text Format"/"PNG"), staged multi-representation writes (one logical copy offers text+RTF+PNG together), `types`, `changeCount` via the system clipboard sequence number (tracks other apps' changes), `clearContents`, and old-style `declareTypes(_:owner:)`. `copy(_:)`/`cut(_:)`/`paste(_:)` responder-chain actions with `NSTextView` implementations (plus `selectAll`), verified interoperating with native controls and external apps. Remaining: object-level readers/writers (`NSPasteboardItem`, `writeObjects`/`readObjects`) and the `.fileURL` type (pairs with drag and drop, 3.18). |
| 3.18 | Drag and drop | ⏳ Pending | View-level `NSDraggingSource`/`NSDraggingDestination`, `registerForDraggedTypes(_:)`, dragging pasteboard items over OLE drag and drop, and file drops from Explorer. Table row drag (5.8) builds on this. |
| 3.19 | Screens and window state depth | ⏳ Pending | `NSScreen` with real monitor frames and `visibleFrame` (today `center()` assumes a fake 1024×768 desktop); `miniaturize`/`deminiaturize`/`zoom`/`orderBack`/`isVisible`; `setFrameAutosaveName` (needs `UserDefaults`, 7.7); window move/resize delegate callbacks and notifications (needs 7.8). |
| 3.20 | Font traits and descriptors | ✅ Done | `NSFont` carries an `italic` trait and the full nine-step `Weight` scale (ultraLight-black, raw values = Windows `LOGFONT` weights), with `withItalic`/`withWeight`/`withSize` and `isBold`. Italic and weight thread through every path: control fonts (`CreateFontW`), custom drawing and text measurement (`drawText`/`measureText` now carry weight+italic), rich-text formatting (`CFE_ITALIC`), the RTF writer (`\i`), and the `ChooseFontW` round-trip. `NSFontDescriptor` with symbolic bold/italic traits (`fontDescriptor`, `NSFont(descriptor:size:)`, `withSymbolicTraits`). `NSFontManager.convert(_:toHaveTrait:)`/`traits(of:)`/`weight(of:)`. The font panel typeface list is Regular/Bold/Italic/Bold Italic. Remaining depth (oblique vs italic distinction, per-family available faces) folds into later polish. |
| 3.21 | Hover tracking | ⏳ Pending | `NSTrackingArea`, `mouseEntered(with:)`/`mouseExited(with:)`, and `updateTrackingAreas()` over `WM_MOUSEMOVE`/`TrackMouseEvent`; feeds the hover polish in 10.6. |
| 3.22 | Printing basics | ⏳ Pending | First `NSPrintOperation`/`NSPrintInfo`/`NSPrintPanel` slice: the native print dialog plus rendering custom-drawn views into a printer device context. Most document apps expose Print; the UI contract matters more than fidelity at first. |
| 3.23 | Cocoa bindings | ⏸️ Deferred | `bind(_:to:withKeyPath:options:)`, `NSObjectController`/`NSArrayController`. Needs KVO-like infrastructure that Swift on Windows lacks; many older nib-based apps use bindings, but nib loading itself is out of scope, so programmatic-UI apps rarely need them. Revisit after Phase 9. |
| 3.24 | System symbol images | ⏳ Pending | An SF Symbols equivalent: `NSImage(systemSymbolName:accessibilityDescription:)` resolves Apple's symbol **names** to WinChocolate's **own original glyph set** — drawn from scratch, never traced or copied from Apple's SF Symbols, so the artwork is copyright-clean while call sites stay source-compatible. Start with a subset covering the common toolbar/menu icons (document, folder, gear, magnifyingglass, plus, minus, trash, pencil, play/pause, arrow.\*, chevron.\*); unknown names return a labeled placeholder so apps never break. Open design questions to settle first: glyph authoring format (path-based drawing vs bundled bitmaps), size/weight variants, template-image tinting (ties into 3.13), and the authoring pipeline. Absorbs the name-mapping half of 6.12; also the seed of a cross-platform asset set LinChocolate (`Docs/LinChocolatePlan.md`) will reuse. |

---

## Phase 4 — Demo Harness 🔄 78%

Use the demo as a visual smoke test and workflow exerciser.

| # | Item | Status | Notes |
|---|---|---|---|
| 4.1 | Main demo window | ✅ Done | Exercises core controls and state updates. |
| 4.2 | Page selector | ✅ Done | Moved to toolbar as a custom toolbar item. |
| 4.3 | Table/media/value pages | 🔄 In Progress | ~70% — good coverage, but should keep evolving with new controls. |
| 4.4 | Visual QA | 🔄 In Progress | ~70% — manual screenshots remain useful for layout and toolbar work. |
| 4.5 | Coverage for new surfaces | 🔄 In Progress | ~65% — save/open panels, toolbar customization, and the Drawing page (canvas + paths gallery, View menu entries) are wired; the paths gallery now lives in a magnifiable scroll view with zoom buttons (wheel scrolling + 3.3 magnification). Keep adding coverage as 3.7-3.13 surfaces land. |

---

## Phase 5 — Tables, Lists, Collections 🔄 21%

Move table-like controls from first slices toward practical AppKit behavior.

| # | Item | Status | Notes |
|---|---|---|---|
| 5.1 | `NSTableView` | 🔄 In Progress | ~45% — columns, rows, selection, sorting, actions exist; data-source reload depth and accessibility remain. |
| 5.2 | `NSOutlineView` | 🔄 In Progress | ~35% — flattening over table backend exists; disclosure triangles and tree-table rendering remain. |
| 5.3 | `NSBrowser` | 🔄 In Progress | ~30% — first composed column browser slice exists. |
| 5.4 | `NSCollectionView` | 🔄 In Progress | ~25% — first fixed item-grid slice exists; layout engines and reuse remain. |
| 5.5 | Cell and row view hosting | ⏳ Pending | Real `NSTableCellView`/`NSTableRowView` hosting so custom views render inside cells. |
| 5.6 | In-place editing | ⏳ Pending | Editable cells with begin/commit/cancel semantics matching AppKit. |
| 5.7 | Header and sorting depth | 🔄 In Progress | ~30% — header clicks and sort descriptors exist; `NSTableHeaderView` customization and indicators remain. |
| 5.8 | Selection and drag depth | ⏳ Pending | Multiple selection, extended-selection keyboard behavior, row drag & drop. |

---

## Phase 6 — Toolbar API Parity 🔄 34%

Define and implement the AppKit toolbar contract before making more Windows rendering decisions. The source-of-truth API definition is `Docs/AppKitToolbarAPI.md`.

Design note: toolbars are the rare exception to the "look like Windows" rule — WinChocolate toolbars should keep the **Apple look and UI feel**, including the customization experience, and should eventually support several Apple looks (for example the older metallic style and the modern unified style). Current compromise: the customization panel mirrors the toolbar in a strip inside the panel instead of supporting drags into the real window toolbar; item 6.13 tracks switching to the real Apple behavior. The mirrored-strip panel now follows Apple's sheet layout (`NSToolbarCustomizationPanel`) with working drag insert/reorder/remove/default-restore and live toolbar updates.

| # | Item | Status | Notes |
|---|---|---|---|
| 6.1 | AppKit toolbar API inventory | 🔄 In Progress | ~50% — document the Apple-defined `NSToolbar`, `NSToolbarItem`, delegate, validation, customization, and autosave contract before further implementation work. |
| 6.2 | `NSWindow.toolbar` contract | 🔄 In Progress | ~60% — attach, replace, show/hide, and content-layout reservation work; sheet attachment and full-screen behavior remain. |
| 6.3 | `NSToolbar` model contract | 🔄 In Progress | ~50% — identifier, visible ordering, delegate ownership, display/size modes, visibility, separator styles exist; selected item identifier and autosave name remain. |
| 6.4 | `NSToolbarItem` model contract | 🔄 In Progress | ~50% — identifier, label, palette label, tooltip, image, view, target/action, enabled, min/max size exist; tag, menu form representation, visibility priority behavior, validation remain. |
| 6.5 | Delegate and item creation contract | 🔄 In Progress | ~60% — allowed/default identifiers and item creation by identifier work; selectable identifiers remain. |
| 6.6 | Standard item identifiers | 🔄 In Progress | ~40% — separator, space, flexible space work with style-aware rendering; show-colors, show-fonts, print, customize-toolbar identifiers remain. |
| 6.7 | Customization contract | 🔄 In Progress | ~60% — Apple-style sheet with drag insert/reorder/remove, default-set restore, duplicate rules, and display-mode popup work; palette filtering rules and richer labels remain. |
| 6.8 | Autosave and restoration contract | ⏳ Pending | `autosavesConfiguration`, configuration identifiers, persistence shape (depends on `UserDefaults`, item 7.7), reset behavior. |
| 6.9 | Overflow and item visibility contract | ⏳ Pending | Behavior when the toolbar is too narrow: flexible space, overflow menu, visibility priority, custom view constraints. |
| 6.10 | Toolbar rendering implementation | 🔄 In Progress | ~40% — composed renderer works (chrome background, separators, composite items, custom views); final renderer choice deferred until the API contract is settled. |
| 6.11 | Customization visual polish | 🔄 In Progress | ~30% — layout matches Apple's sheet; drag previews, drop-position indicators, and final visual matching remain. |
| 6.12 | SF Symbols strategy | ➡️ Moved to 3.24 | Symbol-name compatibility over an original, copyright-clean glyph set now lives in 3.24; toolbars keep consuming named images through it. Counted under Phase 3. |
| 6.13 | Apple drag-to-real-toolbar customization | ⏳ Pending | Attempt to replace the mirrored-strip compromise with Apple's real behavior: drag items directly between the customization palette and the live window toolbar, with the sheet attached under the toolbar. |

---

## Phase 7 — WinFoundation Bridge 🔄 24%

Bridge enough Foundation-shaped API to keep WinChocolate source-compatible while the local Windows Swift toolchain cannot import real Foundation. `FileManager` and `Timer` were pulled forward into Phase 3 (3.15, 3.14) as milestone blockers; `UserDefaults` (7.7) is still a prerequisite for toolbar autosave (6.8).

| # | Item | Status | Notes |
|---|---|---|---|
| 7.1 | `URL`, `Data`, `Date`, `IndexSet`, `IndexPath`, `UUID`, `Bundle` | 🔄 In Progress | ~55% — first useful slices exist with contracts. |
| 7.2 | Real Foundation canary | 🔄 In Progress | ~30% — `USE_REAL_FOUNDATION` path remains the eventual target; rerun the canary in `FOUNDATION_SHIMS.md` on new toolchains. |
| 7.3 | Resource and file behavior | 🔄 In Progress | ~40% — needed by image loading, panels, documents. |
| 7.4 | Broader Foundation compatibility | ⏳ Pending | Add only when AppKit/API needs justify it. |
| 7.5 | `FileManager` | ➡️ Moved to 3.15 | Pulled into Phase 3 as a milestone blocker for `NSDocument` (3.9); done. Counted under Phase 3. |
| 7.6 | `Timer` and run-loop scheduling | ➡️ Moved to 3.14 | Pulled into Phase 3 as a milestone blocker for `NSDocument` autosave (3.9); done. Counted under Phase 3. |
| 7.7 | `UserDefaults` | ⏳ Pending | Persistent defaults (registry or plist-style file). Required by toolbar autosave (6.8). |
| 7.8 | `NotificationCenter` | ⏳ Pending | Post/observe with object filtering; several AppKit notifications already have names waiting for a real center. |
| 7.9 | String and data I/O | 🔄 In Progress | ~40% — `Data` read/write exists; `String(contentsOf:)`/`write(to:)` and encodings remain. |

---

## Phase 8 — Modern Windows Appearance ⏳ 0%

Add a modern Windows presentation while keeping the classic backend available.

Goal: one appearance switch selects either the current classic Win32 look or the modern Windows look, with no other application code changes. The modern look becomes the WinChocolate default once it reaches parity, and the classic look remains selectable indefinitely.

| # | Item | Status | Notes |
|---|---|---|---|
| 8.1 | Appearance strategy | ⏳ Pending | Decide modern backend versus themed wrappers (comctl32 v6 manifest + visual styles) versus hybrid. |
| 8.2 | Backend/appearance selection API | ⏳ Pending | Public switch to select classic Win32 or modern presentation; app code should not change when switching presentation style. |
| 8.3 | Modern control visuals | ⏳ Pending | Fluent/WinUI-like look is future work. |
| 8.4 | Modern look becomes the default | ⏳ Pending | After modern visuals reach control parity, new apps default to the modern look with classic still selectable. |
| 8.5 | `NSAppearance` and dark mode | ⏳ Pending | Map `NSAppearance` names onto Windows light/dark themes; dynamic system colors respond to theme changes. |

---

## Phase 9 — Auto Layout ⏳ 0%

Add AppKit-shaped layout APIs after the core frame-based control surface is stable.

| # | Item | Status | Notes |
|---|---|---|---|
| 9.1 | Constraint model | ⏳ Pending | `NSLayoutConstraint`, anchors, priorities. |
| 9.2 | Intrinsic sizes | ⏳ Pending | Needed for controls, toolbar items, and forms. |
| 9.3 | Migration path from frames | ⏳ Pending | Demos can stay frame-based until constraints are real. |
| 9.4 | `NSStackView` | ⏳ Pending | Stack-based layout container; commonly the first layout API real ports reach for. |
| 9.5 | `NSGridView` | ⏳ Pending | Row/column form layout container; the standard AppKit answer for label-and-field forms. |

---

## Phase 10 — Focus, Accessibility, Polish 🔄 27%

Turn first slices into a framework that feels deliberate.

| # | Item | Status | Notes |
|---|---|---|---|
| 10.1 | Focus and key loop audit | 🔄 In Progress | ~30% — Tab routing and first-responder tracking exist; a dedicated pass for focus indicators and edge cases remains. |
| 10.2 | Accessibility | ⏳ Pending | Native names, roles, keyboard behavior, assistive tech (UIA) expectations. |
| 10.3 | Public API docs | 🔄 In Progress | ~70% — keep public types and members documented. |
| 10.4 | Large-file review | 🔄 In Progress | ~50% — the Win32 backend is split into 14 focused files under `Native/Win32/`; `NSToolbar.swift` (~1,050 lines) and the demo main (~1,900 lines) remain on the `NEEDS_HUMAN.md` list. |
| 10.5 | Native tooltips | ⏳ Pending | `NSView.toolTip` flows through the backend, but a `tooltips_class32` host is needed so users actually see tooltip bubbles. |
| 10.6 | Cursor and hover polish | 🔄 In Progress | ~40% — cursor rects landed (3.6) with per-region WM_SETCURSOR resolution; remaining: I-beam defaults over text controls, hover states. |
| 10.7 | Per-monitor DPI awareness | ⏳ Pending | The process currently runs DPI-virtualized: Windows bitmap-scales the UI when the display scale is not 100%, so text and controls render soft. Declare per-monitor-v2 awareness (manifest or `SetProcessDpiAwarenessContext`), scale logical points to device pixels in the backend (window/control frames, fonts, `GetWindowRect`-derived math like sheet positioning), and handle `WM_DPICHANGED` for monitor moves. Point-based AppKit coordinates stay unchanged at the public API. |

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

These apps **prove** the primary goal; they do not bound it — coverage work targets the AppKit surface most applications use (see the scoping rule under Working method), and framework items are never scoped down to just what these apps happen to touch. The apps are consumers, not framework extensions: any helper an app needs to behave correctly is a design signal that the capability belongs in WinChocolate (and any Mac-only API it needs is a parity gap to fill). Each app deliberately stresses a different API surface. Known prerequisites: custom drawing (3.5), event depth (3.6), `NSDocument` (3.9), `NSTextView` depth (3.11), `Timer` (3.14), `FileManager` (3.15).

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
- When items are added or their `~NN%` estimates change, recompute the phase and overall percentages with the per-item formula above.
- Keep `CONTROL_PARITY.md` as the detailed control matrix.
- Add tests for behavior that becomes framework contract rather than demo-only wiring.
- Keep toolbar follow-up focused on the contract items (6.x) rather than ad-hoc rendering changes.

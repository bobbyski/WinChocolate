# Control Parity

This document tracks AppKit control coverage for WinChocolate. The project goal is Mac-first API compatibility: application code should keep AppKit/Cocoa names and behavior, while WinChocolate chooses the closest native Windows implementation behind the backend boundary.

## The Rule (set in stone)

> **We are implementing the Apple API, not creating something similar.**

Apple's implementation is the specification. The demo builds against real AppKit on macOS, and **that build is the ground truth**. Any difference between a backend and the macOS build is a backend bug, full stop — the Apple side is never "wrong" and is never adjusted to match a backend.

This rule is not negotiable. It decomposes into four obligations:

1. **Exact API.** Same class names, properties, enum cases, **defaults**, and behavior. If `NSDatePicker.datePickerStyle` defaults to `.textFieldAndStepper` on AppKit, it defaults to `.textFieldAndStepper` everywhere. Getting a *default* wrong is as much a bug as getting a call wrong.
2. **Never substitute or combine controls for the user.** The framework does not get to decide the app wanted a simpler control. If the app asks for a date picker with a stepper, it gets a date picker with a stepper. Application code composes controls; the framework never composes them on the app's behalf.
3. **No native equivalent ⇒ build a compound custom control.** When a platform has no native counterpart, implement the Apple control as a **custom control composed of the primitives that do exist** (text field + stepper + label, …). It must expose the **exact Apple API** and behave the same; the compound is an internal detail and must never leak into the public API. This is usually *easier* and more reliable than forcing the platform's nearest complex control to impersonate the Apple one.
4. **Native look is fine; substituted behavior is not.** It may look like a Windows or Linux app. It must still *be* the Apple control: same API, same semantics, same composition.

**Verification.** `Demo/ViewInfo` dumps every view, every property set on it, and its actions from the demo source. Run it against the source the macOS app builds and compare control-by-control — a missing property, a wrong default, or an unimplemented style becomes obvious. See `Demo/ViewInfo/README.md`.

**Worked example — `NSDatePicker` (the case that established this rule).** The demo never sets `datePickerStyle`, so AppKit uses the default `.textFieldAndStepper`: a date field, a time field (because `datePickerElements = [.yearMonthDay, .hourMinuteSecond]`), and a stepper. A backend that renders a bare text field has silently substituted the `.textField` style — a real Apple style, but not the one asked for. The fix is never to redefine the demo; it is to honor the default and build `.textFieldAndStepper` as a compound of a text field plus a stepper.

Status values:

- `Done`: Implemented in the named backend.
- `Partial`: A useful first slice exists, but important AppKit behavior is missing.
- `Planned`: In scope, not implemented yet.
- `Out of scope`: Not planned unless a future AppKit compatibility need appears.
- `N/A`: No equivalent backend target.

References used for this map:

- Apple Developer Documentation: AppKit / `NSControl` and related AppKit views.
- Microsoft Learn: Win32 common controls / standard Windows controls.
- Microsoft Learn: Windows app controls and patterns for modern WinUI-style controls.

## AppKit Controls

| AppKit API | Classic Win32 counterpart | Modern Windows counterpart | Notes | Win32 complete | Modern complete |
|---|---|---|---|---:|---:|
| `NSApplication` | Message loop, accelerator/menu dispatch | `Application` / dispatcher loop | App lifecycle, not a visual control, but central to control behavior. | Partial | Planned |
| `NSWindow` | Top-level `HWND` | `Window` / `AppWindow` | Key/main/title/frame behavior, content size limits (`contentMinSize`/`contentMaxSize`/`minSize`/`maxSize` via `WM_GETMINMAXINFO`), z-order levels, `isMovableByWindowBackground` (drag by empty content), `titleVisibility` (blanks the caption text), `standardWindowButton(_:)` proxies, and the `fullSizeContentView`/`titlebarAppearsTransparent` surface. Reflecting standard-button `isHidden` onto the native caption, transparent-titlebar drawing, and state restoration are future work. | Partial | Planned |
| `NSView` | Custom child `HWND` | `FrameworkElement` / `Panel` equivalent | Custom hosting view exists; drawing/layout is still early. | Partial | Planned |
| `NSControl` | Base child-window/action pattern | `Control` | Base action/enabled/object-value surface exists. | Partial | Planned |
| `NSButton` push button | `BUTTON` with push style | `Button` | Momentary push behavior, `keyEquivalent` dispatch (Return/Escape fire default/cancel buttons), `image`/`imagePosition` (`BM_SETIMAGE`+`BS_BITMAP`), `alternateTitle` (shown in the on state), a click `sound` (via the `NSSound` shim over `PlaySoundW`), and `bezelStyle` (square styles render flat via `BS_FLAT`; fully themed bezels are Phase 8). | Done | Planned |
| `NSButton` checkbox/switch | `BUTTON` with checkbox style | `CheckBox` / `ToggleSwitch` | Switch-style state is implemented. | Done | Planned |
| `NSButton` radio | `BUTTON` with radio style | `RadioButton` | Sibling exclusivity is handled in Swift. | Done | Planned |
| `NSPopUpButton` | `COMBOBOX` dropdown-list | `ComboBox` | Item and selection APIs, per-item tags, a retained `pullsDown` flag, `autoenablesItems` + per-item enabled model, and a per-item image model (`setImage(_:forItemAt:)`/`itemImage(at:)`). Rendering those icons / graying rows inside the native dropdown is owner-draw (Phase 8). | Done | Planned |
| `NSComboBox` | `COMBOBOX` editable/dropdown | `ComboBox` / `AutoSuggestBox` | Editable text, items, action/text-change bridge, `numberOfVisibleItems` (dropdown height), `completes` (commit-time completion via `completedString(forPrefix:)`), a `NSComboBoxDataSource`/`usesDataSource`/`reloadData()` path, and `hasVerticalScroller`; live as-you-type completion over the native combo caret is future work. | Partial | Planned |
| `NSTextField` label | `STATIC` | `TextBlock` | Static text, color/font syncing, and `alignment` exist. | Done | Planned |
| `NSTextField` editable | `EDIT` (single- or multi-line) | `TextBox` | Editing, change notifications, `alignment` (`ES_CENTER`/`ES_RIGHT`), `placeholderString` (`EM_SETCUEBANNER`; cue renders once comctl32 v6 visual styles are enabled), `NSTextFieldDelegate` begin/change/end editing over focus events, the `isBezeled`/`bezelStyle`/`usesSingleLineMode`/`maximumNumberOfLines` surface, in-field multi-line (`usesSingleLineMode=false` realizes an `ES_MULTILINE` scrolling edit), and a working `formatter` (`objectValue` renders through the `NumberFormatter` shim; editing end parses text back into `objectValue`, reverting invalid input). Bezel visuals are appearance-phase work. | Done | Planned |
| `NSSecureTextField` | `EDIT` with password style | `PasswordBox` | Basic password-style native edit peer exists; deeper secure paste/autofill/privacy behavior is future work. | Partial | Planned |
| `NSSearchField` | `EDIT` plus search/cancel adornments | `AutoSuggestBox` / `TextBox` with buttons | Editable search text, immediate action dispatch, and `sendsSearchStringImmediately`/`sendsWholeSearchString`/`recentSearches` behaviors work; the visual chrome (magnifier icon, cancel button, recents dropdown) is tracked as plan item 10.8. | Partial | Planned |
| `NSTokenField` | Framework-drawn chips / composed edit | Tokenizing text box pattern | Token model + `setTokens`/tokenizing + completion hook. The rounded style draws tokens as framework-drawn rounded chips on a view peer; a `.plain` style keeps the native editable text peer. Inline chip *editing* (the type-and-tokenize hybrid) is a later text-engine feature. | Done | Planned |
| `NSTextView` | Multiline `EDIT`, or `RICHEDIT50W` when rich | `TextBox` multiline / `RichEditBox` | Multiline editing plus `selectedRange`, `insertText(_:replacementRange:)`, `scrollRangeToVisible`, delegate `textDidChange`, read-only sync, fonts, word-coalescing undo, and find/replace. Rich text (`isRichText`) formats ranges via `EM_SETCHARFORMAT` (font, color, underline, strikethrough): `setFont(_:range:)`, `setTextColor(_:range:)`, selection-scoped `changeFont(_:)`, and a synced `textStorage` whose attribute runs apply to the peer; rich copies stage RTF on the pasteboard. RTF reading and paragraph styles are future work. | Partial | Planned |
| `NSImageView` | `STATIC` bitmap/icon or custom paint | `Image` | BMP/PNG/JPEG/GIF/ICO file loading (GDI+ for non-BMP) with image/name model and scaling/alignment/frame-style state. Template images render via a GDI+ color matrix: `isTemplate` + `contentTintColor` bake a tinted bitmap into the peer, and `NSImage.draw(in:)` tints with the current fill color (alpha-preserving). Custom drawing blits a bounded per-path decoded-bitmap cache. True custom scaling and data-backed (`IStream`) decode are future work. | Done | Planned |
| `NSColorWell` | Custom button/color swatch plus color dialog | `ColorPicker` | Clickable swatch presents the shared floating color panel; panel picks flow back into the active well live; `colorWellStyle`/`isBordered` are configurable; the `.expanded` style drops down a swatch palette (custom-draw swatches in a transient popover + "Show Colors…"). | Done | Planned |
| `NSSlider` | `msctls_trackbar32` | `Slider` | Native trackbar peer with value/range/action, tick marks (`numberOfTickMarks`/`allowsTickMarkValuesOnly`/`closestTickMarkValue`), vertical orientation, a stored `altIncrementValue`, and `tickMarkPosition` (native `TBS_TOP`/`TBS_LEFT`). | Done | Planned |
| `NSStepper` | `msctls_updown32` | `NumberBox` with spin buttons | Native up-down peer with value/range/increment/action and native wrap-at-ends (`UDS_WRAP`). | Done | Planned |
| `NSProgressIndicator` bar | `msctls_progress32` | `ProgressBar` | Determinate bar exists. | Done | Planned |
| `NSProgressIndicator` spinning | Framework-drawn spinner | `ProgressRing` | A `.spinning` indicator realizes a view peer drawing twelve dots swept clockwise by a run-loop timer (leading dot opaque, fading tail), with `isDisplayedWhenStopped`; `startAnimation`/`stopAnimation` drive the sweep. The modern themed ring is the appearance phase. | Done | Planned |
| `NSLevelIndicator` | Progress bar / framework-drawn meter | Rating/value indicator pattern | Continuous capacity uses a native progress peer with `warningValue`/`criticalValue` recoloring (`PBM_SETBARCOLOR`) and `isEditable` click/drag-to-set. Rating/discrete/relevancy styles are framework-drawn on a view peer (stars / filled squares / graduated bars), editable by clicking an item. | Done | Planned |
| `NSDatePicker` | `SysDateTimePick32` / `SysMonthCal32` | `DatePicker`, `TimePicker`, `CalendarDatePicker` | Date value/min/max/action plus `datePickerElements` filtering; the native picker and `stringValue` both format through the user's locale (`DateFormatter`/`Locale` over `GetDateFormatEx`/`GetLocaleInfoEx`), so a US machine shows US dates without hand-rolled math. The clock-and-calendar style (`datePickerStyle == .clockAndCalendar`) uses a `SysMonthCal32` peer with selection-change notifications wired to the action. A cell delegate (`validateProposedDateValue`, needs `NSDatePickerCell`) is future work. | Partial | Planned |
| `NSPathControl` | Breadcrumb/custom toolbar/edit composition | Breadcrumb bar pattern | URL/path display as clickable breadcrumb segments (per-component buttons composed in a container peer) with cumulative file URLs; clicking a segment records the cell (`clickedPathComponentCell`) and fires the action. Borderless breadcrumb visuals are appearance-phase work. | Done | Planned |
| `NSSegmentedControl` | Composed `BUTTON` peers/custom owner draw | `Segmented` style via `RadioButtons`/custom | Composed segment state/action, arrow-key selection (skips disabled segments), per-segment `image`/`tag`, and per-segment `menu` (a menu segment pops its menu). Unified drawing and visual styles are appearance-phase work. | Done | Planned |
| `NSMatrix` | Group of child controls | ItemsControl/custom panel | Deprecated AppKit API; first composed button-grid slice exists for old ports. | Partial | Planned |
| `NSForm` | Group of labels/edit controls | Form layout pattern | Deprecated AppKit API; first composed label/edit-row slice exists. | Partial | Planned |
| `NSBox` | `BUTTON` group-box style | `GroupBox` | Basic title/frame peer exists. | Done | Planned |
| `NSScrollView` | Custom child `HWND` with scrollbars | `ScrollViewer` | Owns an `NSClipView` content view and document-view host; native scrollbar events update the clip origin, the mouse wheel scrolls content (configurable `lineScroll`, Shift-for-horizontal, horizontal wheel, nearest-scrolling-ancestor routing), and magnification scales custom-drawn documents via a GDI world transform with anchored zoom. | Partial | Planned |
| `NSScroller` | `SCROLLBAR` | `ScrollBar` | Standalone normalized value/knob-proportion slice plus `hitPart` reporting the real gesture (line/page/knob, mapped from the scroll notification code). Overlay behavior and custom knob/arrow styling are future work. | Partial | Planned |
| `NSTableView` | `SysListView32` report mode | `ListView` / `DataGrid` pattern | Columns, rows, single + **multiple selection** (as an index set), keyboard navigation, header-click **sorting with native arrow indicators**, first-column **in-place editing** (`LVS_EDITLABELS`), and **partial `reloadData(forRowIndexes:columnIndexes:)`**. Remaining depth (view-based cells, row drag, accessibility) needs a framework-drawn table. | Partial | Planned |
| `NSTableColumn` | List-view column/header metadata | Grid/list column metadata | Swift-side column model exists. | Partial | Planned |
| `NSTableCellView` | List-view subitem/custom view | Data template cell | Placeholder API exists; no real cell-view hosting. | Partial | Planned |
| `NSTableRowView` | List-view row/custom draw | Item container | Placeholder API exists; no custom row rendering. | Partial | Planned |
| `NSOutlineView` | `SysTreeView32` or custom tree/list hybrid | `TreeView` / `TreeView` plus columns | First AppKit-shaped flattening slice exists over the table backend; disclosure UI and native tree-table rendering are future work. | Partial | Planned |
| `NSBrowser` | Multi-column list/tree composition | Multi-pane navigation pattern | First AppKit-shaped composed column browser slice exists over table/scroll-view columns. | Partial | Planned |
| `NSCollectionView` | `SysListView32` icon mode or custom item grid | `GridView` / `ItemsRepeater` | First composed item-grid slice exists with data source, item objects, selection, and fixed layout; reuse/layout engines are future work. | Partial | Planned |
| `NSRuleEditor` | Custom composed rows | Custom composed control | No native Windows peer. | Planned | Planned |
| `NSPredicateEditor` | Custom composed rows | Custom composed control | No native Windows peer. | Planned | Planned |
| `NSScrubber` | Custom horizontal item strip | Custom item strip | Touch Bar-era AppKit control; low priority. | Planned | Planned |
| `NSTabView` | `SysTabControl32` | `TabView` | Basic item labels and selection bridge exist; hosted per-tab content is future work. | Partial | Planned |
| `NSSplitView` | Custom child-window splitter | `GridSplitter` / `SplitView` pattern | Basic pane arrangement and programmatic divider positioning exist; drag tracking and delegate callbacks are future work. | Partial | Planned |
| `NSToolbar` | Composed `NSToolbarView` renderer (native `ToolbarWindow32` retired) | `CommandBar` / `AppBar` | AppKit-compatible toolbar/item model rendered by the composed `NSToolbarView` docked through `NSWindow.toolbar`; Apple-style customization sheet (`NSToolbarCustomizationPanel`) with drag insert/reorder/remove/default-restore, display modes, separator styles, and delegate identifiers. Overflow, autosave, and drag-to-the-real-toolbar customization remain future work (plan 6.13). | Partial | Planned |
| `NSStatusBar` / `NSStatusItem` | Shell notification icon / tray menu | App notification area integration | Not a normal child control; likely later app-shell work. | Planned | Planned |
| `NSMenu` | `HMENU` | `MenuBar` / `MenuFlyout` | Menu bar, submenus, separators, check-state marks, context menus (`popUp` via `TrackPopupMenu`), and Ctrl-mapped key equivalents (`performKeyEquivalent`); `validateMenuItem` and live updates remain. | Partial | Planned |
| `NSMenuItem` | `MENUITEMINFO` / command ID | Menu item | Basic item/action/submenu/separator state exists. | Partial | Planned |
| `NSPopover` | Popup window/custom transient `HWND` | `TeachingTip` / `Flyout` | Transient popover over a menu-less borderless `NSPanel` with a solid background, `NSPopoverDelegate`, outside-click dismiss for `.transient`/`.semitransient` (a `WH_MOUSE` thread hook), `animates` fade (`AnimateWindow` `AW_BLEND`), and `preferredEdge` flip-when-clipped (via `GetSystemMetrics` screen bounds). A macOS-style beak is intentionally omitted for the Windows flyout look. | Done | Planned |
| `NSAlert` | `MessageBoxW` + composed modal panel | `ContentDialog` | Custom button titles, suppression checkbox, style icon badge, custom `icon`, a help button (`showsHelp`/`NSAlertDelegate`), and `accessoryView` run in a composed modal panel over `NSApplication.runModal`; plain alerts keep `MessageBoxW`. `buttons` vends the real `NSButton` objects with AppKit response `tag`s and default Return/Escape key equivalents; `NSAlert(error:)` builds an alert from any `Error`; buttonless composed alerts synthesize a default OK. Suppression persistence (→ 7.7) and sheet animation (→ 10.9) remain. | Done | Planned |
| `NSPanel` | Tool/top-level `HWND` variants | Secondary window/dialog | Panel flags work against the backend: `isFloatingPanel` maps to a topmost tool window via `NSWindow.level`, `hidesOnDeactivate` hides on `WM_ACTIVATEAPP`, `becomesKeyOnlyIfNeeded` gates `canBecomeKey`, `.utilityWindow` styles compact chrome, `.nonactivatingPanel` maps to `WS_EX_NOACTIVATE`, and panels never become main. `worksWhenModal` enforcement and `.hudWindow` styling are tracked in 10.9 / Phase 8. | Done | Planned |
| `NSSavePanel` | `GetSaveFileNameW` classic dialog | `FileSavePicker` / file dialog | First modal slice exists over the classic comdlg32 save dialog: title, name field, allowed-file-type filter, initial directory, overwrite prompt, and `url` result. Sheet presentation, accessory views, and `allowedContentTypes` are future work. | Partial | Planned |
| `NSOpenPanel` | `GetOpenFileNameW` / `SHBrowseForFolderW` | `FileOpenPicker` / file dialog | First modal slice exists with multi-select and directory choosing (folder browser when `canChooseDirectories` without files). Mixed file+directory choosing in one dialog and accessory views are future work. | Partial | Planned |
| `NSFontPanel` | Composed floating tool window | Custom font picker | Floating utility panel with installed-family list (`EnumFontFamiliesExW`), a Regular/Bold/Italic/Bold Italic typeface popup, size combo, and live preview; selections apply live through `NSFontManager.convert(_:)` and `changeFont(_:)` on the responder chain, and closing hides the shared panel. Per-family available faces are future work. | Partial | Planned |
| `NSColorPanel` | Composed floating tool window | `ColorPicker` dialog | Floating utility panel with preset swatches, an RGB/HSB `mode` switch, component sliders, an opt-in `showsAlpha` opacity slider, and live preview; changes flow live into the active color well and `changeColor(_:)` on the responder chain, and closing hides the shared panel. Non-slider Apple picker modes (wheel/crayon/list) and `accessoryView`/`setPickerMask` are documented boundaries. | Done | Planned |
| `NSRulerView` | Custom drawing | Custom drawing | Text/document companion view; no direct Windows peer. | Planned | Planned |
| `NSClipView` | Child clipping `HWND`/viewport | `ScrollViewer` viewport | Viewport/document host with bounds origin, magnification-aware clamping, and visible-rect state in document coordinates. | Partial | Planned |
| `NSVisualEffectView` | DWM/acrylic/custom composition | Acrylic/Mica/Backdrop | First material/blending/state API slice exists with a classic fallback background; true acrylic/Mica rendering is future modern-backend work. | Partial | Planned |

## Windows Controls With No Direct AppKit Counterpart

These are out of scope unless they become useful as an implementation detail behind an AppKit-shaped API.

| Windows control/pattern | Classic Win32 class/API | Modern Windows counterpart | Closest AppKit concept | Notes | Win32 complete | Modern complete |
|---|---|---|---|---|---:|---:|
| Header control | `SysHeader32` | Grid/list header | `NSTableHeaderView` / table internals | Useful internally for `NSTableView`, not public as a separate AppKit control. | Partial | Planned |
| Rebar | `ReBarWindow32` | App bar/command surface | `NSToolbar` internals | Windows-specific toolbar docking band. | Out of scope | Out of scope |
| Status bar | `msctls_statusbar32` | `InfoBar` / custom footer | No standard AppKit status bar control | AppKit apps usually compose their own bottom status area. | Out of scope | Out of scope |
| Tooltip control | `tooltips_class32` | `ToolTip` | `NSToolTip`/view tooltip APIs | Should appear as tooltip API, not as public control. | Planned | Planned |
| Trackbar tick buddy controls | `msctls_trackbar32` buddies | `Slider` labels | `NSSlider` accessory labels | Implementation detail only. | Out of scope | Out of scope |
| Up-down buddy control | `msctls_updown32` | `NumberBox` spin buttons | `NSStepper` | Used by the classic `NSStepper` backend, not exposed as a public AppKit name. | Done | Planned |
| Hot key control | `msctls_hotkey32` | Keyboard accelerator capture pattern | Custom key-equivalent recorder | No standard AppKit control name; may become a custom helper later. | Out of scope | Out of scope |
| IP address control | `SysIPAddress32` | TextBox with mask/custom | No direct AppKit control | Domain-specific Windows control. | Out of scope | Out of scope |
| Month calendar standalone | `SysMonthCal32` | `CalendarView` | `NSDatePicker` calendar style | Could implement date picker internals. | Planned | Planned |
| Link control | `SysLink` | `HyperlinkButton` | `NSTextField` attributed link / custom button | AppKit handles links through text/attributed strings more than a separate control. | Out of scope | Out of scope |
| Pager control | `SysPager` | Scroll/overflow pattern | Toolbar overflow/scrolling internals | Windows-specific container. | Out of scope | Out of scope |
| Animate control | `SysAnimate32` | Animated image/progress visuals | `NSImageView` animation or progress | Legacy AVI animation control. | Out of scope | Out of scope |
| ComboBoxEx | `ComboBoxEx32` | `ComboBox` with icons/templates | `NSComboBox` plus image cells | Implementation option only. | Out of scope | Out of scope |
| Property sheet | `PropertySheet` API | Settings/card navigation | `NSTabView`/panels | Dialog pattern, not an AppKit control. | Out of scope | Out of scope |
| Task dialog | `TaskDialogIndirect` | `ContentDialog` | `NSAlert` custom dialog | Useful future alert backend but not public AppKit API. | Planned | Planned |
| Command link button | `BUTTON` command-link style | Button with rich content | Custom `NSButton` style | Windows-specific visual style. | Out of scope | Out of scope |
| Split button | `BUTTON` split-button style | `DropDownButton` / `SplitButton` | `NSPopUpButton` or toolbar menu item | Not a direct AppKit base control. | Out of scope | Out of scope |
| NavigationView | N/A classic | `NavigationView` | Sidebar/source list pattern | AppKit equivalent is usually outline/sidebar composition. | Out of scope | Out of scope |
| InfoBar | N/A classic | `InfoBar` | Custom banner view | No single AppKit counterpart. | Out of scope | Out of scope |
| TeachingTip | N/A classic | `TeachingTip` | `NSPopover` | Could inform popover implementation but not public API. | Out of scope | Out of scope |
| Rating control | N/A classic | `RatingControl` | `NSLevelIndicator` style | Could back a level indicator style. | Planned | Planned |

## Deferred Follow-Up Tasks

- Toolbar customization cleanup: return to `NSToolbar` after the next control work pass and finish the remaining polish around the customization dialog, including final visual matching, drag/drop edge cases, overflow, autosave, and parity with AppKit's customization sheet.
- SF Symbols compatibility: define the Windows-side strategy for `NSImage(systemSymbolName:)` and SF-symbol-style names, including allowed licensing boundaries, symbol-name-to-Windows-icon mappings, and any bundled replacement asset set needed for names that do not map to common-control or Windows-native icons.
- Native tooltip popups: `NSView.toolTip` now flows through the backend API, but the Win32 backend still needs a `tooltips_class32` host so users actually see tooltip bubbles.

## Parity Gap Sweep (ViewInfo)

Produced by running `ViewInfo` over the demo and checking every property the demo
sets against the framework. The demo is an Apple app, so anything it touches is,
by the Rule above, a requirement. Re-run with:

    cd Demo/ViewInfo && swift run ViewInfo ../DemoApplication/main.swift ../DemoApplication/DemoConveniences.swift

### P1 — API the demo uses that does not exist

The demo sets these; the framework never declares them. Same severity as the
`NSDatePicker` stepper: Apple code that will not port.

- `NSBrowser.columnResizingType` — demo sets `.userColumnResizing` (main.swift:4062). Needs the `NSBrowser.ColumnResizingType` enum (`.noColumnResizing`, `.autoColumnResizing`, `.userColumnResizing`) with AppKit's `.autoColumnResizing` default.
- `NSBrowser.minColumnWidth` — demo sets `170` (main.swift:4066). AppKit's default is `100`, which is what truncates "Application" to "Applicat…" in the demo.
- `NSForm.setBezeled(_:)` — demo calls `form.setBezeled(false)` (main.swift:2487). Applies to every cell.
- `NSForm.setBordered(_:)` — demo calls `form.setBordered(true)` (main.swift:2488).

### P2 — declared but inert (set it, nothing happens)

The `NSDatePicker` defect class: the API accepts the value and silently drops it.

- `NSVisualEffectView.blendingMode` — stored, and its `didSet` calls `updateFallbackBackground()`, but that method never reads `blendingMode`, so `.withinWindow` and `.behindWindow` are identical. Either honor it or document the fallback as a known limit.
- `NSScrollView.allowsMagnification` — stored, never read; gesture magnification is unimplemented. Already documented in-source as pending, so this is a known gap rather than a silent one.

### P3 — style frozen at peer-creation time

These pick the *peer type* from a style property inside `createNativePeer`, and
peers are realized on `addSubview` (`NSView.swift:647`). Setting the style after
that point works in AppKit but is ignored here. The demo happens to set them
before `addSubview`, so it renders correctly today — this is latent, not live.

- `NSLevelIndicator.levelIndicatorStyle` — no observer; chooses plain-view-with-custom-drawing vs. native progress bar at creation.
- `NSProgressIndicator.style` — same shape; already documents the divergence in-source.

Fix shape for both: recreate the peer on style change, or realize the superset
peer and switch rendering.

### Verified NOT gaps

- `NSLevelIndicator` `.rating` **is** implemented — `draw(_:)` renders a real five-pointed `starPath`. The stars missing from the screenshot are therefore a runtime problem (the framework-drawn plain-view peer not painting), not absent code, and need on-device Windows debugging rather than new API.
- The `on…`-style closures the demo uses (`onSelectionChanged`, `onTextChanged`, `onDoubleAction`, …) are demo-side conveniences declared in `DemoConveniences.swift`, not AppKit API. Not framework gaps.

## Special Mismatch Notes

- Some AppKit APIs are controls in daily use even when they are technically views, panels, menus, or application-shell objects. They are included here because Cocoa apps commonly treat them as part of the UI control surface.
- Classic Win32 has many controls with visible similarities to AppKit controls, but AppKit behavior should win when there is a conflict.
- Modern Windows support is intentionally tracked separately. The current codebase only has the classic Win32 backend, so every modern entry is currently `Planned`, `Out of scope`, or `N/A`.
- Several AppKit controls require composition rather than one native peer: `NSSearchField`, `NSTokenField`, `NSPathControl`, `NSRuleEditor`, `NSPredicateEditor`, `NSBrowser`, and richer `NSTableView` behavior.
- Deprecated AppKit controls such as `NSMatrix` and `NSForm` are low priority, but documenting them matters because old Cocoa code may still contain them.

# Control Parity

This document tracks AppKit control coverage for WinChocolate. The project goal is Mac-first API compatibility: application code should keep AppKit/Cocoa names and behavior, while WinChocolate chooses the closest native Windows implementation behind the backend boundary.

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
| `NSWindow` | Top-level `HWND` | `Window` / `AppWindow` | Basic key/main/title/frame behavior exists. | Partial | Planned |
| `NSView` | Custom child `HWND` | `FrameworkElement` / `Panel` equivalent | Custom hosting view exists; drawing/layout is still early. | Partial | Planned |
| `NSControl` | Base child-window/action pattern | `Control` | Base action/enabled/object-value surface exists. | Partial | Planned |
| `NSButton` push button | `BUTTON` with push style | `Button` | Momentary push behavior exists. | Done | Planned |
| `NSButton` checkbox/switch | `BUTTON` with checkbox style | `CheckBox` / `ToggleSwitch` | Switch-style state is implemented. | Done | Planned |
| `NSButton` radio | `BUTTON` with radio style | `RadioButton` | Sibling exclusivity is handled in Swift. | Done | Planned |
| `NSPopUpButton` | `COMBOBOX` dropdown-list | `ComboBox` | Item and selection APIs exist. | Done | Planned |
| `NSComboBox` | `COMBOBOX` editable/dropdown | `ComboBox` / `AutoSuggestBox` | Basic editable text, items, and action/text-change bridge exist; data source/completion behavior is future work. | Partial | Planned |
| `NSTextField` label | `STATIC` | `TextBlock` | Static text and color/font syncing exist. | Done | Planned |
| `NSTextField` editable | Single-line `EDIT` | `TextBox` | Editing and change notifications exist. | Done | Planned |
| `NSSecureTextField` | `EDIT` with password style | `PasswordBox` | Basic password-style native edit peer exists; deeper secure paste/autofill/privacy behavior is future work. | Partial | Planned |
| `NSSearchField` | `EDIT` plus search/cancel adornments | `AutoSuggestBox` / `TextBox` with buttons | Basic editable search text and immediate action dispatch exist; adornments/recent-search UI are future work. | Partial | Planned |
| `NSTokenField` | Owner-drawn/composed edit/list | Tokenizing text box pattern | First tokenizing text-field slice exists over an editable text peer; visual token chips and completion UI are future work. | Partial | Planned |
| `NSTextView` | Multiline `EDIT` or RichEdit | `TextBox` multiline / `RichEditBox` | Basic multiline edit exists; rich text and selection APIs are missing. | Partial | Planned |
| `NSImageView` | `STATIC` bitmap/icon or custom paint | `Image` | File-backed BMP loading plus image/name model and scaling/alignment/frame-style state exists; richer formats and true custom scaling are future work. | Partial | Planned |
| `NSColorWell` | Custom button/color swatch plus color dialog | `ColorPicker` | Basic clickable swatch and color state exist; shared color panel is future work. | Partial | Planned |
| `NSSlider` | `SCROLLBAR` first slice, later trackbar/custom | `Slider` | Value/range/action works; current classic peer is visually rough. | Partial | Planned |
| `NSStepper` | `SCROLLBAR` first slice, later `msctls_updown32` or custom | `NumberBox` with spin buttons | Value/range/increment/action works; current classic peer is provisional. | Partial | Planned |
| `NSProgressIndicator` bar | `msctls_progress32` | `ProgressBar` | Determinate bar exists. | Done | Planned |
| `NSProgressIndicator` spinning | Custom animation | `ProgressRing` | Spinning/indeterminate behavior not implemented. | Planned | Planned |
| `NSLevelIndicator` | Progress bar/custom owner-drawn meter | Rating/value indicator pattern | Basic value/range state exists over a progress-style peer; discrete/rating visuals are future work. | Partial | Planned |
| `NSDatePicker` | `SysDateTimePick32` / `SysMonthCal32` | `DatePicker`, `TimePicker`, `CalendarDatePicker` | First date-value/min/max/action slice exists over the classic date-time picker; calendar/time styles are future work. | Partial | Planned |
| `NSPathControl` | Breadcrumb/custom toolbar/edit composition | Breadcrumb bar pattern | First URL/path display slice exists over a text peer with component-cell metadata; true breadcrumb interaction is future work. | Partial | Planned |
| `NSSegmentedControl` | Composed `BUTTON` peers/custom owner draw | `Segmented` style via `RadioButtons`/custom | First composed segment state/action slice exists; unified drawing and keyboard behavior are future work. | Partial | Planned |
| `NSMatrix` | Group of child controls | ItemsControl/custom panel | Deprecated AppKit API; first composed button-grid slice exists for old ports. | Partial | Planned |
| `NSForm` | Group of labels/edit controls | Form layout pattern | Deprecated AppKit API; first composed label/edit-row slice exists. | Partial | Planned |
| `NSBox` | `BUTTON` group-box style | `GroupBox` | Basic title/frame peer exists. | Done | Planned |
| `NSScrollView` | Custom child `HWND` with scrollbars | `ScrollViewer` | Owns an `NSClipView` content view and document-view host; native scrollbar events now update the clip origin. | Partial | Planned |
| `NSScroller` | `SCROLLBAR` | `ScrollBar` | Standalone normalized value/knob-proportion slice exists; detailed parts, overlay behavior, and custom styling are future work. | Partial | Planned |
| `NSTableView` | `SysListView32` report mode | `ListView` / `DataGrid` pattern | Columns, rows, selection, sorting slice exists; editing/reuse/accessibility incomplete. | Partial | Planned |
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
| `NSToolbar` | `ToolbarWindow32` / rebar | `CommandBar` / `AppBar` | First AppKit-compatible toolbar/item model exists with a classic `ToolbarWindow32` renderer docked through `NSWindow.toolbar`; `NSToolbarItem.image`, `NSImage(systemSymbolName:)` name capture, flexible-space descriptors, delegate allowed/default identifiers, visible item replacement, and a starter customization palette exist. Drag reordering, overflow, autosave, and the full AppKit customization sheet remain future work. | Partial | Planned |
| `NSStatusBar` / `NSStatusItem` | Shell notification icon / tray menu | App notification area integration | Not a normal child control; likely later app-shell work. | Planned | Planned |
| `NSMenu` | `HMENU` | `MenuBar` / `MenuFlyout` | Menu model and Quit dispatch exist. | Partial | Planned |
| `NSMenuItem` | `MENUITEMINFO` / command ID | Menu item | Basic item/action/submenu/separator state exists. | Partial | Planned |
| `NSPopover` | Popup window/custom transient `HWND` | `TeachingTip` / `Flyout` | First transient popover API slice exists over a menu-less borderless `NSPanel`; arrow/chrome/outside-click behavior is future work. | Partial | Planned |
| `NSAlert` | `MessageBoxW`, later custom dialog | `ContentDialog` | Basic modal alert exists; custom buttons need custom dialog. | Partial | Planned |
| `NSPanel` | Tool/top-level `HWND` variants | Secondary window/dialog | First subclass slice exists with common panel flags and top-level window backend behavior; true tool-window styling is future work. | Partial | Planned |
| `NSSavePanel` | Common Item Dialog save | `FileSavePicker` / file dialog | Not a child control; important AppKit surface. | Planned | Planned |
| `NSOpenPanel` | Common Item Dialog open | `FileOpenPicker` / file dialog | Not a child control; important AppKit surface. | Planned | Planned |
| `NSFontPanel` | Common font dialog/custom | Custom font picker | Classic font dialog exists, but AppKit panel model differs. | Planned | Planned |
| `NSColorPanel` | ChooseColor dialog/custom | `ColorPicker` dialog | Needs shared color-panel behavior. | Planned | Planned |
| `NSRulerView` | Custom drawing | Custom drawing | Text/document companion view; no direct Windows peer. | Planned | Planned |
| `NSClipView` | Child clipping `HWND`/viewport | `ScrollViewer` viewport | First viewport/document-host slice exists with bounds origin and visible-rect state. | Partial | Planned |
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

## Special Mismatch Notes

- Some AppKit APIs are controls in daily use even when they are technically views, panels, menus, or application-shell objects. They are included here because Cocoa apps commonly treat them as part of the UI control surface.
- Classic Win32 has many controls with visible similarities to AppKit controls, but AppKit behavior should win when there is a conflict.
- Modern Windows support is intentionally tracked separately. The current codebase only has the classic Win32 backend, so every modern entry is currently `Planned`, `Out of scope`, or `N/A`.
- Several AppKit controls require composition rather than one native peer: `NSSearchField`, `NSTokenField`, `NSPathControl`, `NSRuleEditor`, `NSPredicateEditor`, `NSBrowser`, and richer `NSTableView` behavior.
- Deprecated AppKit controls such as `NSMatrix` and `NSForm` are low priority, but documenting them matters because old Cocoa code may still contain them.

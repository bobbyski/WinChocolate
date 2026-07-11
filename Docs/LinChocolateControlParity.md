# LinChocolate — Control Parity (Linux / GTK4)

The Linux column of the control map (Phase L4.2). Each AppKit-shaped type maps to
a native GTK4 peer behind `NativeControlBackend`; the classic-look composed
controls that WinChocolate hand-draws are mostly replaced by native GTK peers
here (Goal 2 — native modern look).

**Status:** ✅ implemented · 🔄 partial · ⏳ planned

| AppKit type | GTK4 peer | Status | Notes |
|---|---|---|---|
| `NSApplication` | `GMainLoop` | ✅ | Plain main loop (not `GtkApplication`) so create-then-run matches AppKit. |
| `NSWindow` | `GtkWindow` | ✅ | Content view set via `gtk_window_set_child`; close → terminate. |
| `NSView` | `GtkFixed` | ✅ | Absolute child placement; explicit size + expand (avoids XQuartz 0×0 collapse). |
| `NSButton` (push) | `GtkButton` | ✅ | `clicked` → `onAction`. |
| `NSButton` (checkbox) | `GtkCheckButton` | ✅ | `toggled` → `isOn` / `onAction`. |
| `NSButton` (radio) | `GtkCheckButton` grouped | ✅ | `NSButton.group([...])` chains via `gtk_check_button_set_group`; mutually exclusive. |
| `NSTextField` (label) | `GtkLabel` | ✅ | `init(labelWithString:)`. |
| `NSTextField` (editable) | `GtkEntry` | ✅ | `init(string:)`; `changed` → `stringValue` / `onTextChange`. |
| `NSSecureTextField` | `GtkPasswordEntry` | ✅ | Masked entry (GtkEditable); `changed` → `stringValue`. |
| `NSSearchField` | `GtkSearchEntry` | ✅ | GtkEditable; `changed` → `stringValue`. |
| `NSComboBox` | `GtkComboBoxText` (w/ entry) | ✅ | Editable; child `GtkEntry` carries the text. Deprecated GTK peer — no non-deprecated editable combo in GTK4 short of a composite. |
| `NSSlider` | `GtkScale` (horizontal) | ✅ | `value-changed` → `doubleValue` / `onValueChange`. |
| `NSProgressIndicator` | `GtkProgressBar` | ✅ | Determinate; `doubleValue` → fraction over `[min,max]`. |
| `NSPopUpButton` | `GtkDropDown` | ✅ | `notify::selected` → `indexOfSelectedItem` / `onSelectionChange`. |
| `NSStepper` | `GtkSpinButton` | ✅ | Numeric up/down; `value-changed` → `doubleValue` / `onValueChange`. |
| `NSLevelIndicator` | `GtkLevelBar` | ✅ | Determinate gauge over `[min,max]`. |
| `NSTextView` | `GtkTextView` | ✅ | Multiline, buffer-backed; buffer `changed` → `string` / `onTextChange`. |
| `NSDatePicker` | `GtkCalendar` | ✅ | Graphical calendar style; `day-selected` → `dateValue` / `onDateChange` via `GDateTime` ↔ `Date` (unix epoch). |
| `NSColorWell` | `GtkColorButton` | ✅ | Swatch + native chooser; `color-set` → `color` / `onColorChange` via `GdkRGBA` ↔ `NSColor`. Deprecated GTK peer (like `GtkComboBoxText`) — the non-deprecated `GtkColorDialogButton` is async-only. **Chooser is deliberately non-modal**: a modal chooser grabs all input, and when the dialog fails to map over XQuartz the app looks hung and can't be closed (hit in practice; verified fixed by scripted click-through with the dialog open). |
| `NSTokenField` | composed: chip `GtkButton`s + `GtkEntry` in a `GtkBox` | ✅ | No GTK peer. Enter commits the entry text as a token; clicking a chip removes it; `objectValue` both ways + `onTokensChange`. |
| `NSSegmentedControl` | linked `GtkToggleButton`s in a `GtkBox` | ✅ | Composed control (GTK's segmented idiom, "linked" CSS class); per-segment `toggled` → `selectedSegment` / `onAction`. |
| `NSMenu` / `NSMenuItem` | `GtkPopoverMenuBar` + `GMenu`/`GSimpleAction` | ✅ | `NSApp.mainMenu` installs an in-window menu bar on every window; separators become GMenu sections; item actions are window-scoped GActions ("win.mN"). |
| `NSTabView` / `NSTabViewItem` | `GtkNotebook` | ✅ | Tabbed pages; `switch-page` → `indexOfSelectedTab` / `onSelectionChange`; programmatic `selectTabViewItem(at:)`. |
| `NSBox` | `GtkFrame` | ✅ | Titled group box; `contentView` via kind-routed `setContentView`. |
| `NSScrollView` | `GtkScrolledWindow` | ✅ | `documentView` scrolls when larger than the frame; native overlay scrollbars. |
| `NSSplitView` | `GtkPaned` | ✅ | Two panes (`addArrangedSubview`), draggable divider, `setPosition`. AppKit `vertical` = GTK horizontal orientation. |
| `NSTableView` / `NSTableColumn` | `GtkColumnView` (in a scroller) | ✅ | AppKit-shaped `NSTableViewDataSource` (row count + `objectValueFor:row:`); GtkStringList model carries only the row count — cell text pulled from the Swift provider in each column's factory `bind`. Single selection via `GtkSingleSelection` → `selectedRow`/`onSelectionChange`; `reloadData()` re-splices the model. |
| `NSOpenPanel` / `NSSavePanel` | `GtkFileDialog` (async → nested loop) | ✅ | AppKit's blocking `runModal()` over GTK4's async-only dialog: the `GAsyncReadyCallback` quits a nested `GMainLoop`; cancel ⇒ nil ⇒ `NSModalResponseCancel`. `directoryURL`, `nameFieldStringValue`, `url`/`urls`. |
| `NSAlert` | composed modal `GtkWindow` + nested `GMainLoop` | ✅ | AppKit's blocking `runModal()`: GTK4 removed blocking dialogs and its dialog constructors are C-variadic (uncallable from Swift), so the alert is composed — modal transient window, headline ("title-4"), buttons right-aligned with the first (default) rightmost, response = `NSAlertFirstButtonReturn + index`. |
| `NSImage` / `NSImageView` | `GtkPicture` | ✅ | File-backed image slice; `gtk_picture_set_filename`, aspect-fit scaling. |
| `NSView.draw(_:)` / `NSBezierPath` / `NSGraphicsContext` | `GtkOverlay` { `GtkDrawingArea` + `GtkFixed` } + Cairo | ✅ | Every plain `NSView` is an overlay: drawing area underneath (Cairo, flipped to AppKit bottom-left via `cairo_translate/scale`), child-hosting fixed on top. Subclass `NSView`, override `draw(_:)`, use `NSBezierPath` (rect/oval/move/line/curve/close, fill/stroke) and `NSColor.setFill()/setStroke()`; `needsDisplay = true` queues a redraw. |
| `NSAttributedString` (+`.foregroundColor`/`.font` keys) | Pango markup (`gtk_label_set_markup`) | ✅ | Foundation's attributed classes (as on macOS) + AppKit's keys added by LinChocolate; `NSTextField.attributedStringValue` flattens to styled runs → `<span>` markup. |
| `NSFont` | per-widget CSS (`font-family/size/weight/style`) | ✅ | `NSView.font`; `systemFont`/`boldSystemFont`/`monospacedSystemFont`/`init(name:size:)`. GTK styles text via CSS providers, not API calls. |
| `NSColor` as `textColor` | per-widget CSS (`color`) | ✅ | On `NSTextField`/`NSTextView`; same provider as the font (rebuilt together). |
| `NSOutlineView` | `GtkColumnView` + `GtkTreeListModel` + `GtkTreeExpander` | ✅ | AppKit-shaped `NSOutlineViewDataSource` (children/expandable/value by item). Items addressed by index paths ("0.2"): the tree create-func builds child path lists on expand; the API resolves paths back to data-source items. Column 0 carries native expand arrows. |
| `NSCollectionView` | `GtkGridView` (in a scroller, 3–4 columns) | ✅ | Count-only string-list model + one tile factory; `representedObjectForItemAt` supplies tile text (full `NSCollectionViewItem` view controllers are a later parity item). `selectionIndexes` (single) + `onSelectionChange`. |
| `NSToolbar` / `NSToolbarItem` | composed styled `GtkBox` (**Apple-look exception**) | ✅ | The one deliberate non-native look (Goal 2): light gradient strip, hairline bottom border, flat hover-highlighted buttons; flexible-space item; docks under the menu bar via `NSWindow.toolbar`. Delegate-based item management + customization sheet are later parity items. |
| `NSLayoutConstraint` / anchors | *(no GTK peer — pure solver)* | 🔄 | Auto Layout is resolved entirely in Swift and applied through the existing `setFrame` seam, so it's backend-agnostic (identical on GTK and in-memory). `LayoutSolver` turns active **equality** constraints into a linear system and solves by Gaussian elimination (RREF); under-constrained dimensions fall back to the current frame. Anchors: `leading/trailing/left/right/centerX` (X), `top/bottom/centerY` (Y), `width/height` (Dimension) with constant + multiplier. `translatesAutoresizingMaskIntoConstraints` picks solver-driven vs. fixed. Inequalities, priority tie-breaking, intrinsic-size hugging/compression, and live resize re-layout are later parity items. |

## Interop note: opaque vs. nominal GTK types

The C→Swift import treats some GTK widget structs as **nominal** types
(`UnsafeMutablePointer<GtkX>`) and others as **opaque** (`OpaquePointer`). This
must be checked per widget when binding a new control:

- **Nominal** (need a typed pointer / `as*` cast helper): `GtkWindow`,
  `GtkButton`, `GtkCheckButton`, `GtkFixed`, `GtkRange`, `GtkComboBox`,
  `GtkTextView`, `GtkTextBuffer`, `GtkFrame`, `GtkBox`, `GtkToggleButton`,
  `GMenuModel`, `GSimpleActionGroup`. Plain C structs (`GdkRGBA`,
  `GtkTextIter`) import as Swift structs.
- **Opaque** (functions take `OpaquePointer` directly): `GtkLabel`,
  `GtkEditable`, `GtkProgressBar`, `GtkDropDown`, `GtkComboBoxText`,
  `GtkPasswordEntry`, `GtkSearchEntry`, `GtkSpinButton`, `GtkLevelBar`,
  `GtkCalendar`, `GtkColorChooser`, `GtkNotebook`, `GtkScrolledWindow`,
  `GtkPaned`, `GMenu`, `GSimpleAction`, `GActionMap`, `GtkPicture`,
  `GtkStringList`, `GtkSingleSelection`, `GListModel`, `GtkListItemFactory`,
  `GtkColumnViewColumn`, `GtkListItem`, `GDateTime`, `GMainLoop`.
  (`GMenu` is opaque while `GMenuModel` is nominal — same family, split import.)

There is no pattern to which is which (`GtkSpinButton` is opaque while the
simpler `GtkButton` is nominal), so it must be checked per widget.

The compiler flags the wrong choice immediately (`cannot find type 'GtkX'` →
it's opaque; `cannot convert OpaquePointer to UnsafeMutablePointer<GtkX>` → it's
nominal), so binding a new control is a quick build-and-fix loop.

## Non-composited display fixups (XQuartz / Xvfb)

GTK4 popovers (menus, dropdowns) assume an alpha-composited display for their
drop shadow, rounded corners, and pointing arrow. Without a compositor the
transparent surface regions render **solid black** (the "thick black border"
seen over XQuartz). The GTK backend detects `gdk_display_is_composited() ==
false` at init and applies three fixups (composited displays keep the native
look):

1. CSS `popover { margin: 0; … }` — the root node's margin becomes unpainted
   surface insets (the last black band); zero it.
2. CSS `popover > contents { box-shadow: none; border-radius: 0; border: 1px
   solid … }` — replaces the shadow ring with a hairline border.
3. `gtk_popover_set_has_arrow(false)` on dropdown-internal popovers — the
   arrow's tail geometry is compiled into GTK and cannot be styled away.
4. Outside-click dismissal fallback — popovers normally auto-dismiss via a
   pointer grab, which doesn't take effect here, leaving menus stuck open. A
   capture-phase `GtkGestureClick` on each window pops down any visible
   popover in its subtree. Clicks inside a popover are on its own surface and
   never reach the handler, so item activation is unaffected.

Diagnosed by pixel-sampling captures (the band was exactly the popover
surface's top rows); each layer removed a slice of the black. The dismissal
fallback was verified the same way: a probe strip under the open dropdown went
0/8 white rows → 8/8 after an outside click.

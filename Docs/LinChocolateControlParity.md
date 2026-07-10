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
| `NSTabView` / `NSTabViewItem` | `GtkNotebook` | ✅ | Tabbed pages; `switch-page` → `indexOfSelectedTab` / `onSelectionChange`; programmatic `selectTabViewItem(at:)`. |
| `NSTableView` | `GtkColumnView` | ⏳ | |
| `NSToolbar` | hand-drawn (Apple-look exception) | ⏳ | Keeps the Apple look/feel per Goal 2's toolbar exception. |
| `NSAlert` | `AdwMessageDialog` / `GtkAlertDialog` | ⏳ | |

## Interop note: opaque vs. nominal GTK types

The C→Swift import treats some GTK widget structs as **nominal** types
(`UnsafeMutablePointer<GtkX>`) and others as **opaque** (`OpaquePointer`). This
must be checked per widget when binding a new control:

- **Nominal** (need a typed pointer / `as*` cast helper): `GtkWindow`,
  `GtkButton`, `GtkCheckButton`, `GtkFixed`, `GtkRange`, `GtkComboBox`,
  `GtkTextView`, `GtkTextBuffer`. Plain C structs (`GdkRGBA`, `GtkTextIter`)
  import as Swift structs.
- **Opaque** (functions take `OpaquePointer` directly): `GtkLabel`,
  `GtkEditable`, `GtkProgressBar`, `GtkDropDown`, `GtkComboBoxText`,
  `GtkPasswordEntry`, `GtkSearchEntry`, `GtkSpinButton`, `GtkLevelBar`,
  `GtkCalendar`, `GtkColorChooser`, `GDateTime`, `GMainLoop`.

There is no pattern to which is which (`GtkSpinButton` is opaque while the
simpler `GtkButton` is nominal), so it must be checked per widget.

The compiler flags the wrong choice immediately (`cannot find type 'GtkX'` →
it's opaque; `cannot convert OpaquePointer to UnsafeMutablePointer<GtkX>` → it's
nominal), so binding a new control is a quick build-and-fix loop.

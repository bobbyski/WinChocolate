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
| `NSSlider` | `GtkScale` (horizontal) | ✅ | `value-changed` → `doubleValue` / `onValueChange`. |
| `NSProgressIndicator` | `GtkProgressBar` | ✅ | Determinate; `doubleValue` → fraction over `[min,max]`. |
| `NSPopUpButton` | `GtkDropDown` | ✅ | `notify::selected` → `indexOfSelectedItem` / `onSelectionChange`. |
| `NSTextView` | `GtkTextView` | ⏳ | Multiline text. |
| `NSStepper` | `GtkSpinButton` | ⏳ | |
| `NSComboBox` | `GtkComboBox`/entry | ⏳ | Editable + list. |
| `NSTableView` | `GtkColumnView` | ⏳ | |
| `NSToolbar` | hand-drawn (Apple-look exception) | ⏳ | Keeps the Apple look/feel per Goal 2's toolbar exception. |
| `NSAlert` | `AdwMessageDialog` / `GtkAlertDialog` | ⏳ | |

## Interop note: opaque vs. nominal GTK types

The C→Swift import treats some GTK widget structs as **nominal** types
(`UnsafeMutablePointer<GtkX>`) and others as **opaque** (`OpaquePointer`). This
must be checked per widget when binding a new control:

- **Nominal** (need a typed pointer / `as*` cast helper): `GtkWindow`,
  `GtkButton`, `GtkCheckButton`, `GtkFixed`, `GtkRange`.
- **Opaque** (functions take `OpaquePointer` directly): `GtkLabel`,
  `GtkEditable`, `GtkProgressBar`, `GtkDropDown`, `GMainLoop`.

The compiler flags the wrong choice immediately (`cannot find type 'GtkX'` →
it's opaque; `cannot convert OpaquePointer to UnsafeMutablePointer<GtkX>` → it's
nominal), so binding a new control is a quick build-and-fix loop.

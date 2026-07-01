# View Creation Map

This note records where WinChocolate creates AppKit-style views and where those views become native Win32 windows. It is meant as a breadcrumb for future investigation of startup paint, toolbar rendering, and child-HWND flashing.

## Demo Startup

The main demo is built in `Demo/DemoApplication/main.swift`.

- `window` is created near the top of the file.
- Most demo controls are allocated as globals in the same file.
- The page switcher logic lives in `showDemoPage(_:)`.
- The final startup sequence is near the end of the file:
  - `window.contentView = contentView`
  - `showDemoPage(0)`
  - `updateFocusDisplay()`
  - `window.makeKeyAndOrderFront(nil)`

If controls appear before the window looks ready, this end-of-file sequence is the first place to check.

## Window Realization

`Sources/WinChocolate/Windows/NSWindow.swift` owns top-level window realization.

- `makeKeyAndOrderFront(_:)`
  - Calls `realizeNativePeer()`.
  - Marks the window main/key.
  - Calls `nativeBackend.showWindow(handle)`.

- `realizeNativePeer()`
  - Calls `nativeBackend.createWindow(...)`.
  - Installs window close/resize callbacks.
  - Adds the window to `NSApplication.shared.windows`.
  - Calls `installToolbarHost()`.
  - Calls `layoutToolbarAndContent()`.
  - Calls `contentView?.realizeNativePeer(in: nativeBackend, parent: handle)`.

- `installToolbarHost()`
  - Creates an `NSToolbarView` host when the window has a toolbar.
  - If the native window already exists, realizes the toolbar host as a child of the window.

- `layoutToolbarAndContent()`
  - Positions the toolbar host at the top.
  - Positions the content view below the toolbar.
  - Reloads toolbar items when the toolbar host is already native.

## View Hierarchy Realization

`Sources/WinChocolate/Views/NSView.swift` owns the generic view realization path.

- `realizeNativePeer(in:parent:)`
  - Returns early if the view already has a native handle.
  - Calls `createNativePeer(in:parent:)`.
  - Stores `nativeHandle` and `realizedBackend`.
  - Applies hidden/background/tooltip state.
  - Registers mouse/key callbacks.
  - Recursively realizes every subview.

- `createNativePeer(in:parent:)`
  - Default implementation calls `backend.createView(frame:parent:)`.
  - Control subclasses override this to request specific native controls.

This recursive realization is where a large existing Swift view tree becomes many Win32 child windows.

## Control Subclass Native Peers

Most control subclasses override `createNativePeer(in:parent:)` and call one method on `NativeControlBackend`.

Common examples:

- `Controls/NSButton.swift`
  - Calls `backend.createButton(...)`, `createCheckbox(...)`, or `createRadioButton(...)`.

- `Controls/NSTextField.swift`
  - Calls `backend.createTextField(...)`.

- `Controls/NSSecureTextField.swift`
  - Calls `backend.createSecureTextField(...)`.

- `Controls/NSTextView.swift`
  - Calls `backend.createTextView(...)`.

- `Controls/NSPopUpButton.swift`
  - Calls `backend.createPopUpButton(...)`.

- `Controls/NSComboBox.swift`
  - Calls `backend.createComboBox(...)`.

- `Controls/NSImageView.swift`
  - Calls `backend.createImageView(...)`.

- `Views/NSBox.swift`
  - Calls `backend.createBox(...)`.

- `Views/NSScrollView.swift`
  - Calls `backend.createScrollView(...)`.

- `Controls/NSTableView.swift`
  - Calls `backend.createTableView(...)`.

If one control type paints strangely, start in its `createNativePeer` override and then follow the backend method it calls.

## Toolbar Rendering

`Sources/WinChocolate/Windows/NSToolbar.swift` is the current toolbar implementation.

- `NSToolbar.runCustomizationPalette(_:)`
  - Creates the customize panel and its palette/default/toolbar-strip views.
  - Uses `NSToolbarCustomizationTile` for draggable tiles.

- `NSToolbarView`
  - Is the composed toolbar host view installed by `NSWindow`.
  - `createNativePeer(in:parent:)` uses the normal view path.
  - `reloadItems()` rebuilds its child views from the toolbar model.
  - Standard toolbar items currently use `NSToolbarItem.winCompositeView(...)`.
  - Custom toolbar items host the item's real `view`.

- `NSToolbarItem.winCompositeView(...)`
  - Creates the WinChocolate-specific composite representation for normal toolbar items.
  - Separators use `NSToolbarSeparatorView`.

Toolbar startup artifacts are likely in this area, especially if item views are created, reloaded, or invalidated after the window is shown.

## Native Backend Entry Points

`Sources/WinChocolate/Native/NativeControlBackend.swift` defines the abstraction.

`Sources/WinChocolate/Native/InMemoryNativeControlBackend.swift` records native requests for tests.

`Sources/WinChocolate/Native/Win32NativeControlBackend.swift` creates real HWNDs:

- `createWindow(...)`
  - Creates the top-level Win32 window with `CreateWindowExW`.

- `showWindow(_:)`
  - Calls `ShowWindow`.
  - Invalidates and updates the top-level window.

- `createView(...)`
  - Creates a custom `WinChocolateView` child HWND.

- `createButton(...)`, `createTextField(...)`, `createImageView(...)`, etc.
  - Create specific Win32 child HWNDs.

- `createChildWindow(...)`
  - Central helper used by almost every child-control creation method.
  - Calls `CreateWindowExW` for child windows.

When investigating visible construction, `createChildWindow(...)` is the choke point for child HWND creation.

## Current Paint/Startup Notes

Recent experiments showed:

- Creating the top-level window without `WS_VISIBLE` is safer and should remain.
- Moving demo initial page setup before `makeKeyAndOrderFront` is safer and should remain.
- `WM_SETREDRAW` around top-level creation made final rendering worse.
- `WS_EX_LAYERED` with alpha reveal made final rendering worse, especially around group-box/control backgrounds.
- `WS_EX_COMPOSITED` and `WS_CLIPCHILDREN` may reduce parent/child paint conflicts, but they do not solve the core flash alone.

The likely longer-term fix is architectural: reduce how many native child HWNDs are created during initial composition, or delay/native-batch expensive child creation behind a composed custom view.

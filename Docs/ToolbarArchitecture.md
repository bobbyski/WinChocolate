# Toolbar Architecture

WinChocolate now renders window toolbars with a composed AppKit-style view instead of the native Windows `ToolbarWindow32` control.

The project originally tried to bridge `NSToolbar` to `ToolbarWindow32`, but the models diverged too much around custom views. Native toolbar custom slots had to be represented as separator placeholders with separate child controls overlaid on top. That produced separator artifacts, z-order problems, and startup paint bugs. The live renderer now follows the Apple mental model more closely: the toolbar is a container view, and each visible item is represented by one child view in that container.

## Public Model

### `NSToolbar`

`NSToolbar` remains the AppKit-shaped model object. It owns:

- `items`: the ordered visible `NSToolbarItem` list.
- `itemStore`: known items by identifier for customization.
- `delegate`: allowed/default item identifiers and item creation.
- `itemsDidChange`: callback used by the host view to rebuild composed children.
- `visibilityDidChange`: callback used by the window to reserve or release toolbar space.

`NSToolbar` is not itself a native view. It describes toolbar state.

### `NSToolbarItem`

`NSToolbarItem` remains the per-item model. It can represent:

- A standard toolbar command item with label, image, enabled state, tooltip, and action.
- A structural item such as separator, fixed space, or flexible space.
- A custom view item through `view`, such as `NSPopUpButton` or `NSSearchField`.

For custom view items, `minSize` and `maxSize` define the desired composed item size.

## Live Renderer

### `NSToolbarView`

`NSToolbarView` is the window-owned toolbar host. `NSWindow` creates it when `window.toolbar` is set.

The native peer for `NSToolbarView` is now a plain WinChocolate view, created with `NativeControlBackend.createView`. It no longer creates a native `ToolbarWindow32` peer for the live window toolbar.

On reload, `NSToolbarView` removes its rendered children and rebuilds them from `toolbar.items`:

- Standard item: creates an `NSToolbarCompositeItemView`.
- Custom view item: hosts the item's actual `NSView`.
- Separator item: creates an `NSToolbarSeparatorView`.
- Fixed/flexible space: creates an empty `NSView` occupying layout space.

This makes each visible toolbar element self-contained in the composed view hierarchy. There is no native separator placeholder under a custom control.

### Layout

`NSToolbarView` computes item frames directly:

- Starts at `leadingPadding`.
- Uses `displayWidth(for:in:)` for fixed-width items.
- Divides remaining width across flexible space items.
- Vertically centers items in the toolbar strip.
- Uses each custom item's `minSize` / `maxSize`.

Because layout is owned by `NSToolbarView`, custom controls and standard items now share one coordinate system.

### Actions

Standard composed toolbar item views call `NSToolbarItem.performAction()`.

Custom view items keep their own control action behavior. `NSToolbarItem.performAction()` already prefers sending the custom control's action when `item.view` is an `NSControl`.

Enabled state is copied to composed buttons and custom control views during rebuild.

### Standard Item Painting

`NSToolbarItem.winCompositeView(showItem:showLabel:winLabelLocation:toolbarHeight:)` creates a transparent composite item view for normal command items. That view sends a small explicit render payload to the Win32 custom-view painter:

- label text
- image name
- whether the item image should be shown
- whether the label should be shown
- label position

The backend uses that payload to lay out the glyph and label separately. This avoids the earlier placeholder behavior where newline-delimited text doubled as both the visible label and image key, which made icon-only and label-only modes paint the wrong thing.

## Window Integration

`NSWindow` still owns toolbar docking and reserved content space:

1. `NSWindow.installToolbarHost()` creates or reuses an `NSToolbarView`.
2. The host is parented to the native window.
3. `layoutToolbarAndContent()` positions the toolbar at the top strip.
4. The content view is moved below the toolbar strip.
5. Toolbar visibility changes trigger window relayout.

The content reservation behavior did not change; only the toolbar renderer changed.

## Customization

The customization palette still uses the existing `NSToolbar` model and `NSToolbarCustomizationTile` views.

Drag/reorder/add/remove behavior continues to update the toolbar model through:

- `insertItem(withItemIdentifier:at:)`
- `removeItem(at:)`
- `setVisibleItemIdentifiers(_:)`
- `resetVisibleItemsToDefault()`

When the model changes, `itemsDidChange` causes the composed `NSToolbarView` to rebuild.

## Retired Native Toolbar Path

The Win32 backend still contains native toolbar support such as:

- `createToolbar`
- `setToolbarItems`
- `registerToolbarAction`
- `toolbarItemFrame`
- `NativeToolbarItem`

Those APIs are no longer used by the live `NSToolbarView` renderer. They remain temporarily as backend surface area and historical scaffolding until a cleanup pass removes or repurposes them.

## Why The Change Was Needed

The native toolbar bridge had an unavoidable mismatch:

- AppKit custom toolbar items are real views in toolbar layout.
- Windows `ToolbarWindow32` primarily wants buttons and separator slots.

The bridge reserved custom-view space by installing a native separator item, then positioning the actual control over that slot. This meant a single visual item had two native surfaces: a separator placeholder and a child control. The result was partial separator lines inside fields, startup invisibility until click, and repeated z-order/paint fixes that treated symptoms rather than the model mismatch.

The composed renderer removes the duplicate surface.

## Near-Term Polish Tasks

- Add hover, pressed, selected, disabled, and focus visuals matching classic AppKit toolbar behavior.
- Render item images instead of using image names as temporary icon-only text.
- Add overflow behavior for narrow windows.
- Remove unused native toolbar backend APIs once no tests or demos depend on them.

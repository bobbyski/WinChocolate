# AppKit Toolbar API Definition

This document defines the Apple AppKit toolbar API surface WinChocolate should mirror. It is intentionally about AppKit names, responsibilities, and behavior only. Windows implementation details belong in a later design document.

## Implementation Status (2026-07-06)

A concise map of the inventory below to WinChocolate's implementation. Everything here is contract-tested unless noted.

| Area | Status |
|---|---|
| `NSToolbar` model | **Implemented**: identifier, `init()`/`init(identifier:)`, items, `visibleItems` (overflow-aware), `displayMode`/`sizeMode`, `isVisible`, `allowsUserCustomization`, `selectedItemIdentifier` (validated against the selectable set), `customizationPaletteIsRunning`, `centeredItemIdentifiers` (stored), insert/remove by index or identifier, `validateVisibleItems()` (drives item validation). |
| `NSToolbarItem` model | **Implemented**: identifier, `label`/`paletteLabel`/`title`, `toolTip`, `image`, `view`, target/action + `onAction`, `isEnabled`, min/max size, `tag`, `menuFormRepresentation` (consumed by overflow), `visibilityPriority` (drives overflow), `autovalidates`, `isBordered` (renders as a native button), `validate()` via `NSToolbarItemValidation` on the target. |
| `NSToolbarDelegate` | **Implemented (complete)**: allowed/default/selectable identifiers, `toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)`, `toolbarWillAddItem`/`toolbarDidRemoveItem` (item under `userInfo["item"]`) plus `willAddItemNotification`/`didRemoveItemNotification` through `NotificationCenter.default`. |
| Standard identifiers | **Implemented**: space, flexible space, separator; `.print`/`.showColors`/`.showFonts`/`.customizeToolbar` synthesize built-in items with Mac behaviors; `.toggleSidebar` (label-only; app wires the action), sidebar/inspector tracking separators (render as gaps). Boundary: responder-chain `printDocument:`/`toggleSidebar:` need ObjC selector dispatch. |
| Autosave | **Implemented**: `configurationDictionary`/`setConfiguration(_:)` in the `TB *` dictionary shape, autosaved under `"NSToolbar Configuration <identifier>"` (UserDefaults) and restored on window attach. |
| Overflow | **Implemented**: lowest-`visibilityPriority` items collapse into a » chevron menu built from `menuFormRepresentation`/labels. Remaining: elastic shrink of custom-view items before overflow. |
| Customization sheet | **Implemented**: Apple-layout panel with drag insert/reorder/remove, default-set restore, duplicate rules, display-mode popup, palette dimming for in-toolbar items, drag preview + drop-position insertion indicator. Remaining: drag-to-the-real-toolbar (plan 6.13). |
| `NSToolbarItemGroup` | **Not implemented** (tracked in the plan as renderer/model depth). |
| `NSValidatedUserInterfaceItem`/`NSUserInterfaceValidations` | **Boundary**: the generalized command-validation protocols need ObjC selector dispatch; `NSToolbarItemValidation` covers the toolbar case. |

Reference surfaces:

- Apple Developer Documentation: `NSToolbar`
- Apple Developer Documentation: `NSToolbarItem`
- Apple Developer Documentation: `NSToolbarDelegate`
- Apple Developer Documentation: `NSToolbarItem.Identifier`
- Apple Developer Documentation: `NSToolbarItemGroup`

## Core Model

An AppKit toolbar is made of three primary API concepts:

| API | Role |
|---|---|
| `NSToolbar` | The toolbar model attached to a window. It owns visible item order, display behavior, customization policy, autosave, and delegate coordination. |
| `NSToolbarItem` | The model for one toolbar item. It owns identity, labels, image or custom view, action wiring, validation, sizing, and menu fallback. |
| `NSToolbarDelegate` | The provider that defines which item identifiers are allowed, which are default, which are selectable, and how item instances are created. |

The public API is model-first. A renderer displays the model, but the renderer does not define item identity, ordering, customization rules, or command behavior.

## Apple Type Structure

This section describes the AppKit type structure as protocols so WinChocolate can compare its implementation against Apple class-by-class. These protocols are documentation contracts first. They should become source-level tests or internal conformance checks only after the Apple SDK surface has been verified against headers or Swift interfaces.

### Known AppKit Protocol Relationships

| Apple Type | Kind | AppKit Structure |
|---|---|---|
| `NSToolbar` | Class | `NSObject` subclass. Owns toolbar state and delegates item creation/customization policy. |
| `NSToolbarDelegate` | Protocol | Object protocol used by `NSToolbar` to obtain allowed/default/selectable identifiers and item instances. |
| `NSToolbarItem` | Class | `NSObject` subclass. Represents one toolbar item and participates in command validation. |
| `NSToolbarItemGroup` | Class | `NSToolbarItem` subclass for grouped toolbar items. |
| `NSValidatedUserInterfaceItem` | Protocol | Command-validation protocol used by toolbar items and menu items. |
| `NSUserInterfaceValidations` | Protocol | Implemented by validation targets that can validate `NSValidatedUserInterfaceItem` values. |

### `NSToolbar` Shape Protocol

```swift
/// The AppKit model object that manages the toolbar attached to a window.
///
/// An `NSToolbar` owns the ordered item configuration, display preferences,
/// customization behavior, validation, and persistence policy for a toolbar.
protocol AppKitNSToolbarShape: AnyObject {
    /// The stable toolbar identifier, used to distinguish toolbar configurations
    /// and to key autosaved user customization.
    var identifier: NSToolbar.Identifier { get }

    /// The object that supplies toolbar items and customization identifier lists.
    var delegate: NSToolbarDelegate? { get set }

    /// The toolbar's current item objects in display order.
    var items: [NSToolbarItem] { get }

    /// The item objects currently visible to the user after display and overflow
    /// decisions have been applied.
    var visibleItems: [NSToolbarItem]? { get }

    /// A Boolean value indicating whether the toolbar is currently visible.
    var isVisible: Bool { get }

    /// Shows or hides the toolbar without discarding its configuration.
    func setVisible(_ shown: Bool)

    /// The toolbar-wide preference for showing item icons, labels, both, or the
    /// system default presentation.
    var displayMode: NSToolbar.DisplayMode { get set }

    /// The toolbar-wide preference for regular, small, or default item sizing.
    var sizeMode: NSToolbar.SizeMode { get set }

    /// The identifier of the selected toolbar item in toolbars that support
    /// selectable items.
    var selectedItemIdentifier: NSToolbarItem.Identifier? { get set }

    /// A Boolean value indicating whether the user may customize the toolbar.
    var allowsUserCustomization: Bool { get set }

    /// A Boolean value indicating whether the toolbar customization interface is
    /// currently active.
    var customizationPaletteIsRunning: Bool { get }

    /// Presents the toolbar customization interface.
    func runCustomizationPalette(_ sender: Any?)

    /// A Boolean value indicating whether user changes to the toolbar
    /// configuration are saved and restored automatically.
    var autosavesConfiguration: Bool { get set }

    /// A Boolean value indicating whether AppKit draws the separator between the
    /// toolbar and the window content area.
    var showsBaselineSeparator: Bool { get set }

    /// Inserts an item identified by `itemIdentifier` into the toolbar at `index`,
    /// asking the delegate for the item object when needed.
    func insertItem(withItemIdentifier itemIdentifier: NSToolbarItem.Identifier, at index: Int)

    /// Removes the item at the specified index from the toolbar.
    func removeItem(at index: Int)

    /// Revalidates the visible toolbar items using AppKit command-validation
    /// rules.
    func validateVisibleItems()
}
```

### `NSToolbarDelegate` Shape Protocol

```swift
/// The object that defines a toolbar's available, default, and selectable items
/// and creates item objects for identifiers.
protocol AppKitNSToolbarDelegateShape: AnyObject {
    /// Returns the toolbar item for an identifier.
    ///
    /// AppKit calls this when it needs an item for display or customization. The
    /// `flag` argument indicates whether the item is being inserted into the live
    /// toolbar or only represented elsewhere, such as in customization UI.
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem?

    /// Returns the identifiers that the user is allowed to place in the toolbar.
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Returns the identifiers that make up the toolbar's default configuration.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Returns the identifiers for toolbar items that can participate in toolbar
    /// selection.
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
}
```

### `NSToolbarItem` Shape Protocol

```swift
/// The AppKit model object for a single toolbar item.
///
/// An item owns its identity, labels, image or custom view, command wiring,
/// validation behavior, sizing constraints, and overflow/menu representation.
protocol AppKitNSToolbarItemShape: AnyObject, NSValidatedUserInterfaceItem {
    /// The stable identifier for this toolbar item.
    var itemIdentifier: NSToolbarItem.Identifier { get }

    /// The toolbar currently containing this item, if any.
    var toolbar: NSToolbar? { get }

    /// The primary label displayed for the item in the toolbar.
    var label: String { get set }

    /// The label displayed for the item in customization UI.
    var paletteLabel: String { get set }

    /// The help text shown for the item, typically as a tooltip.
    var toolTip: String? { get set }

    /// An integer tag used by target/action and validation code to identify the
    /// item.
    var tag: Int { get set }

    /// The target object that receives the item's action.
    var target: AnyObject? { get set }

    /// The selector sent when the item is activated.
    var action: Selector? { get set }

    /// The image displayed by icon-capable toolbar presentations.
    var image: NSImage? { get set }

    /// A custom view used as the item's toolbar presentation.
    var view: NSView? { get set }

    /// A menu item used to represent this toolbar item in menu or overflow
    /// contexts.
    var menuFormRepresentation: NSMenuItem? { get set }

    /// A Boolean value indicating whether the item can be activated.
    var isEnabled: Bool { get set }

    /// A Boolean value indicating whether AppKit automatically validates the
    /// item.
    var autovalidates: Bool { get set }

    /// Validates the item and updates its enabled state.
    func validate()

    /// The minimum size allowed for the item's toolbar presentation.
    var minSize: NSSize { get set }

    /// The maximum size allowed for the item's toolbar presentation.
    var maxSize: NSSize { get set }

    /// The priority AppKit uses when deciding which items remain visible as
    /// available toolbar space changes.
    var visibilityPriority: NSToolbarItem.VisibilityPriority { get set }
}
```

### WinChocolate `NSToolbarItem` Extension Shape

These members are not Apple AppKit API. They are WinChocolate extension points for rendering customization and drag feedback while keeping the base `NSToolbarItem` shape aligned with AppKit.

```swift
/// The WinChocolate-specific drag representation for a toolbar item.
enum WinToolbarDragRepresentation {
    /// Use an image as the drag representation.
    case image(NSImage)

    /// Use a view as the drag representation.
    case view(NSView)
}

/// The position of a toolbar item's label relative to its item image or view.
enum WinToolbarLabelPosition {
    /// Place the label below the item image or view.
    case below

    /// Place the label above the item image or view.
    case above

    /// Place the label to the left of the item image or view.
    case left

    /// Place the label to the right of the item image or view.
    case right
}

/// WinChocolate-specific toolbar-item rendering hooks.
protocol WinChocolateNSToolbarItemRenderingShape: AppKitNSToolbarItemShape {
    /// The image shown for this item in the toolbar customization palette.
    ///
    /// When this value is `nil`, the customization palette may fall back to the
    /// item's AppKit `image`, custom `view`, or label-based representation.
    var winImageForPallate: NSImage? { get set }

    /// The representation shown while this item is being dragged.
    ///
    /// Use `.image` for normal icon-like toolbar items and `.view` when the drag
    /// feedback should match a custom toolbar view.
    var winRenderForDrag: WinToolbarDragRepresentation? { get set }

    /// Creates the composed transparent view used to display this item in a
    /// toolbar.
    ///
    /// `showItem` controls whether the item image or custom view is included.
    /// `showLabel` controls whether the item's label is included.
    /// `winLabelLocation` places the label relative to the item representation,
    /// defaulting to `.below`.
    /// `toolbarHeight` is the available toolbar strip height the composed view
    /// should fit within.
    ///
    /// The returned view should be sized to fit the item content and should draw
    /// with a transparent background. Flexible space does not use this hook; it
    /// has a dedicated layout implementation. The containing toolbar view, not
    /// the individual item view, remains the primary drop target during toolbar
    /// customization so drops can land in empty toolbar space as well as over
    /// existing items.
    func winCompositeView(
        showItem: Bool,
        showLabel: Bool,
        winLabelLocation: WinToolbarLabelPosition = .below,
        toolbarHeight: CGFloat
    ) -> NSView
}
```

### `NSToolbarItemGroup` Shape Protocol

```swift
/// A toolbar item that groups multiple toolbar subitems under one item identity.
protocol AppKitNSToolbarItemGroupShape: AppKitNSToolbarItemShape {
    /// The toolbar items contained in the group.
    var subitems: [NSToolbarItem] { get set }

    /// The selection behavior used by the group.
    var selectionMode: NSToolbarItemGroup.SelectionMode { get set }

    /// The index of the selected subitem.
    var selectedIndex: Int { get set }
}
```

`NSToolbarItemGroup` should be treated as a toolbar item first. Group behavior is additive: it does not replace the base `NSToolbarItem` identity, validation, sizing, image/view, target/action, or customization contract.

### Validation Protocols

```swift
/// The common AppKit protocol for objects that can be validated as command UI
/// items, such as menu items and toolbar items.
protocol AppKitNSValidatedUserInterfaceItemShape: AnyObject {
    /// The command selector represented by the user-interface item.
    var action: Selector? { get }

    /// The integer tag associated with the user-interface item.
    var tag: Int { get }
}

/// The AppKit protocol implemented by objects that validate command UI items.
protocol AppKitNSUserInterfaceValidationsShape: AnyObject {
    /// Returns whether the command represented by `item` should be enabled.
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool
}
```

Toolbar item validation should use the same command-validation path as other AppKit command items. A toolbar item is a validated user-interface item; a target may opt into validation by implementing user-interface validation.

## `NSToolbar`

### Creation and Identity

```swift
class NSToolbar: NSObject
```

Required initializer:

```swift
init(identifier: NSToolbar.Identifier)
```

Required identity:

```swift
var identifier: NSToolbar.Identifier { get }
```

The identifier names the toolbar configuration. It is also the root identity used for saved toolbar configuration.

### Window Attachment

The toolbar is attached through `NSWindow.toolbar`:

```swift
var toolbar: NSToolbar?
```

The toolbar remains a model object. The window decides how to display it.

### Delegate

```swift
weak var delegate: NSToolbarDelegate?
```

The delegate supplies item identifiers and creates toolbar items. A toolbar without a delegate can only use items it already knows how to create.

### Items

```swift
var items: [NSToolbarItem] { get }
var visibleItems: [NSToolbarItem]? { get }
```

`items` represents the toolbar's current item order. `visibleItems` represents what is actually visible after display, overflow, and customization behavior.

Mutation:

```swift
func insertItem(withItemIdentifier itemIdentifier: NSToolbarItem.Identifier, at index: Int)
func removeItem(at index: Int)
```

Insertion asks the delegate to create an item for the identifier. Removal updates the current toolbar configuration.

### Visibility

```swift
var isVisible: Bool { get }
func setVisible(_ shown: Bool)
```

Visibility controls whether the toolbar is shown for the attached window. Hiding the toolbar does not destroy its configuration.

### Display and Size Modes

```swift
var displayMode: NSToolbar.DisplayMode
var sizeMode: NSToolbar.SizeMode
```

Display modes:

```swift
enum NSToolbar.DisplayMode {
    case `default`
    case iconAndLabel
    case iconOnly
    case labelOnly
}
```

Size modes:

```swift
enum NSToolbar.SizeMode {
    case `default`
    case regular
    case small
}
```

These are toolbar-wide preferences. Individual items still provide their own image, label, view, and sizing metadata.

### Customization

```swift
var allowsUserCustomization: Bool
var customizationPaletteIsRunning: Bool { get }
func runCustomizationPalette(_ sender: Any?)
```

When customization is allowed, the user can change the visible toolbar item set and order using AppKit's customization UI.

The customization UI is driven by delegate-provided allowed/default identifiers and each item's labels, image, view, and palette label.

### Autosave

```swift
var autosavesConfiguration: Bool
```

When enabled, user customization is persisted using the toolbar identifier. Restoring should preserve visible item order and any supported display configuration.

### Selection

```swift
var selectedItemIdentifier: NSToolbarItem.Identifier?
```

Selectable toolbar items use this to represent the current selected item. The delegate can define which identifiers are selectable.

### Validation

```swift
func validateVisibleItems()
```

Validation updates enabled/disabled state for visible items using AppKit validation rules.

### Appearance Flags

```swift
var showsBaselineSeparator: Bool
```

This controls whether the toolbar draws the baseline separator between the toolbar and window content.

### Notifications

The API includes notifications for item changes, including toolbar item add/remove events. WinChocolate should expose matching names where AppKit source compatibility needs them.

## `NSToolbarDelegate`

The delegate defines the toolbar's item universe.

Required item creation pattern:

```swift
func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
) -> NSToolbarItem?
```

Allowed identifiers:

```swift
func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
```

Default identifiers:

```swift
func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
```

Selectable identifiers:

```swift
func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
```

Optional lifecycle/customization callbacks should be added as source compatibility requires them. The important contract is that the delegate, not the renderer, decides what item identifiers exist and how they become `NSToolbarItem` instances.

## `NSToolbarItem`

### Creation and Identity

```swift
class NSToolbarItem: NSObject
```

Required initializer:

```swift
init(itemIdentifier: NSToolbarItem.Identifier)
```

Required identity:

```swift
var itemIdentifier: NSToolbarItem.Identifier { get }
var toolbar: NSToolbar? { get }
```

The item identifier is the stable semantic identity used for delegate creation, customization, autosave, validation, and standard item behavior.

### User-Facing Text

```swift
var label: String
var paletteLabel: String
var toolTip: String?
```

`label` is the normal toolbar label. `paletteLabel` is the label shown in the customization palette. `toolTip` is the hover/help text for the item.

### Command Metadata

```swift
var tag: Int
weak var target: AnyObject?
var action: Selector?
```

Toolbar items use the target/action pattern. Activating an item sends its action to the target, or through the responder chain when appropriate.

### Image, View, and Menu Representation

```swift
var image: NSImage?
var view: NSView?
var menuFormRepresentation: NSMenuItem?
```

An item can be image/label based, custom-view based, or represented in menus/overflow by `menuFormRepresentation`.

Custom view items are still `NSToolbarItem` instances. The custom view is the item's presentation, not a separate toolbar object.

### Enabled and Validation State

```swift
var isEnabled: Bool
var autovalidates: Bool
func validate()
```

Enabled state controls whether the item can be activated. Validation should follow AppKit command validation rules and update `isEnabled`.

### Sizing

```swift
var minSize: NSSize
var maxSize: NSSize
```

These constrain item presentation, especially for custom views.

### Visibility Priority

```swift
var visibilityPriority: NSToolbarItem.VisibilityPriority
```

Visibility priority participates in overflow decisions when the toolbar is too narrow.

Common priorities:

```swift
struct NSToolbarItem.VisibilityPriority {
    static let standard: NSToolbarItem.VisibilityPriority
    static let low: NSToolbarItem.VisibilityPriority
    static let high: NSToolbarItem.VisibilityPriority
    static let user: NSToolbarItem.VisibilityPriority
}
```

## Standard Item Identifiers

WinChocolate should define standard identifiers as semantic AppKit item identifiers, not renderer-specific placeholders.

Core standard identifiers:

```swift
extension NSToolbarItem.Identifier {
    static let separator: NSToolbarItem.Identifier
    static let space: NSToolbarItem.Identifier
    static let flexibleSpace: NSToolbarItem.Identifier
    static let showColors: NSToolbarItem.Identifier
    static let showFonts: NSToolbarItem.Identifier
    static let customizeToolbar: NSToolbarItem.Identifier
    static let print: NSToolbarItem.Identifier
}
```

Behavior:

| Identifier | Meaning |
|---|---|
| `separator` | Visual separator between toolbar items. |
| `space` | Fixed empty spacing item. |
| `flexibleSpace` | Empty spacing item that expands and contracts with available width. |
| `showColors` | Standard command item for showing the shared color panel. |
| `showFonts` | Standard command item for showing the shared font panel. |
| `customizeToolbar` | Standard command item that opens toolbar customization. |
| `print` | Standard command item for print behavior. |

Additional standard identifiers can be added when WinChocolate commits to that AppKit compatibility surface.

## Customization Semantics

Customization starts from these delegate arrays:

```swift
allowed identifiers
default identifiers
selectable identifiers
```

The user-visible customization UI should:

- Show allowed items in a palette.
- Show the current toolbar item order.
- Let users add allowed items.
- Let users remove removable visible items.
- Let users reorder visible items.
- Let users restore the default identifier list.
- Respect standard item duplicate rules.
- Use `paletteLabel`, `label`, `image`, and custom views for item presentation.
- Persist the customized configuration when `autosavesConfiguration` is enabled.

## Overflow Semantics

When the toolbar is too narrow:

- Flexible space contracts before normal items disappear.
- Items use visibility priority to decide what remains visible.
- Hidden items should remain accessible through an overflow/menu representation when supported.
- `menuFormRepresentation` is the item-level fallback for menu display.
- Custom views obey their `minSize` and `maxSize`.

## Validation Semantics

Toolbar item validation follows AppKit command validation:

- The toolbar can validate all visible items.
- Items with `autovalidates == true` should update automatically at appropriate times.
- Item validation updates enabled state.
- Target/action and responder-chain behavior should match the rest of the AppKit-shaped command system.

## Implementation Rule

Do not design the Windows toolbar implementation until this API contract is represented in WinChocolate source and tests. The renderer should be replaceable without changing application-facing toolbar code.

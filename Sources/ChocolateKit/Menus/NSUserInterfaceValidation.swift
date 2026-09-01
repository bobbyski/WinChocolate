// The generic validation protocol AppKit uses to decide whether a control that
// sends an action should be enabled.
//
// `NSMenuItemValidation` (Menus/NSMenu.swift) is the menu-specific half of the
// same idea and came first here. This is the general one: it is what
// `NSDocument` and `NSDocumentController` adopt, because a document has to be
// able to disable Save when nothing has changed and Revert when there is no
// file — and it must do so for a toolbar button as readily as for a menu item.

/// A user-interface element that sends an action, as seen by a validator.
///
/// Deliberately narrow: a validator needs the action, the sender's tag, and
/// nothing else. `NSMenuItem` and `NSToolbarItem` both satisfy it.
public protocol NSValidatedUserInterfaceItem: AnyObject {
    /// The action the item sends.
    var action: Selector? { get }

    /// The item's tag, for callers that distinguish several items sharing an
    /// action.
    var tag: Int { get }
}

/// Conformed to by action targets that decide their own items' enablement.
///
/// A target adopting this is asked before an item that would send it an action
/// is displayed. Returning false disables the item.
public protocol NSUserInterfaceValidations: AnyObject {
    /// Returns whether an item sending its action to this object should be
    /// enabled.
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool
}

// A menu item already carries everything a validator needs, so the conformance
// is a statement rather than an implementation. Declared here beside the
// protocol instead of in NSMenuItem.swift, because it exists to serve
// validation and reads as noise next to the item's own API.
extension NSMenuItem: NSValidatedUserInterfaceItem {}

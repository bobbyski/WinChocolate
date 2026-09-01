/// Adopted by objects that apply live font-panel changes — Apple's shape
/// since macOS 10.14, when `changeFont(_:)` moved off `NSResponder` onto this
/// protocol. The font manager sends `changeFont:` down the responder chain
/// and only adopters receive it.
public protocol NSFontChanging: AnyObject {
    /// Applies the font panel's current pick (convert the selection through
    /// the sender, as in AppKit).
    func changeFont(_ sender: NSFontManager?)
}

/// Adopted by objects that apply live color-panel changes — Apple's shape
/// since macOS 10.14, when `changeColor(_:)` moved off `NSResponder` onto
/// this protocol.
public protocol NSColorChanging: AnyObject {
    /// Applies the color panel's current color.
    func changeColor(_ sender: NSColorPanel?)
}

/// Base class for objects that participate in event dispatch.
///
/// AppKit routes keyboard and mouse input through a responder chain. This first
/// WinChocolate implementation preserves that shape and forwards unhandled
/// events to `nextResponder`.
open class NSResponder: NSObject {
    /// The next object in the responder chain.
    open weak var nextResponder: NSResponder?

    /// Attempts to perform an action, walking the responder chain on failure —
    /// AppKit's `tryToPerform(_:with:)`.
    ///
    /// Each link is offered the action three ways, in AppKit's order: the
    /// responder itself, then whatever it nominates through
    /// `supplementalTarget(forAction:sender:)`, then the next responder.
    @discardableResult
    open func tryToPerform(_ action: Selector, with object: Any?) -> Bool {
        if responds(to: action) {
            perform(action, with: object)
            return true
        }

        if let supplemental = supplementalTarget(forAction: action, sender: object) as? NSObject,
           supplemental.responds(to: action) {
            supplemental.perform(action, with: object)
            return true
        }

        return nextResponder?.tryToPerform(action, with: object) ?? false
    }

    /// An object this responder offers the responder chain on its behalf.
    ///
    /// This is the hinge the whole document architecture turns on. `NSDocument`
    /// is not an `NSResponder` and so cannot be a link in the chain — yet
    /// `saveDocument:` from a menu item with no target has to reach it. AppKit
    /// resolves that by having `NSWindowController` nominate its document here,
    /// so the chain reads:
    ///
    /// ```
    ///   view … → window → windowController ─(supplemental)→ document
    ///                                       ↘
    ///                                        → NSApplication → app delegate
    ///                                                        → NSDocumentController
    /// ```
    ///
    /// The base implementation nominates nothing.
    ///
    /// - Parameters:
    ///   - action: The selector being looked for.
    ///   - sender: Whatever is sending the action.
    /// - Returns: An object to try before moving on to `nextResponder`.
    open func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
        nil
    }

    /// The responder-chain action selectors every `NSResponder` carries
    /// (their base implementations forward along the chain, so performing one
    /// on any responder walks the chain exactly as AppKit's nil-target
    /// dispatch does).
    private static let winStandardActionSelectors: Set<String> = [
        "copy:", "cut:", "paste:",
        "moveUp:", "moveDown:",
    ]

    /// Responders handle the standard chain actions by selector name — this is
    /// what lets real AppKit `Selector`-based dispatch (menu items, controls,
    /// panels) reach `changeFont(_:)`, `copy(_:)`, … without an Objective-C
    /// runtime. Subclasses with their own action methods override and fall
    /// through to `super`.
    open override func responds(to aSelector: Selector?) -> Bool {
        guard let aSelector else {
            return false
        }

        // Font/color changes reach only adopters of the modern protocols —
        // Apple's shape since 10.14: `changeFont(_:)`/`changeColor(_:)` live
        // on `NSFontChanging`/`NSColorChanging`, not on `NSResponder`.
        if aSelector.name == "changeFont:" {
            return self is NSFontChanging || super.responds(to: aSelector)
        }
        if aSelector.name == "changeColor:" {
            return self is NSColorChanging || super.responds(to: aSelector)
        }
        if Self.winStandardActionSelectors.contains(aSelector.name) {
            return true
        }

        return super.responds(to: aSelector)
    }

    @discardableResult
    /// Dispatches supported responder-chain selectors before consulting the superclass.
    open override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        switch aSelector.name {
        case "changeFont:":
            if let changing = self as? NSFontChanging {
                changing.changeFont(object as? NSFontManager)
            } else {
                return super.perform(aSelector, with: object)
            }
        case "changeColor:":
            if let changing = self as? NSColorChanging {
                changing.changeColor(object as? NSColorPanel)
            } else {
                return super.perform(aSelector, with: object)
            }
        case "copy:":
            copy(object)
        case "cut:":
            cut(object)
        case "paste:":
            paste(object)
        case "moveUp:":
            moveUp(object)
        case "moveDown:":
            moveDown(object)
        default:
            return super.perform(aSelector, with: object)
        }
        return nil
    }

    /// Whether this responder can become first responder.
    open var acceptsFirstResponder: Bool {
        false
    }

    /// Called when the object is asked to become first responder.
    open func becomeFirstResponder() -> Bool {
        acceptsFirstResponder
    }

    /// Called when the object is asked to resign first responder.
    open func resignFirstResponder() -> Bool {
        true
    }

    /// Handles a left mouse button press.
    open func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    /// Handles a left mouse button release.
    open func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    /// Handles mouse movement.
    open func mouseMoved(with event: NSEvent) {
        nextResponder?.mouseMoved(with: event)
    }

    /// Handles mouse dragging with the left button down.
    open func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    /// Handles a right mouse button press.
    open func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    /// Handles a right mouse button release.
    open func rightMouseUp(with event: NSEvent) {
        nextResponder?.rightMouseUp(with: event)
    }

    /// Handles a tertiary (middle) mouse button press.
    open func otherMouseDown(with event: NSEvent) {
        nextResponder?.otherMouseDown(with: event)
    }

    /// Handles a tertiary (middle) mouse button release.
    open func otherMouseUp(with event: NSEvent) {
        nextResponder?.otherMouseUp(with: event)
    }

    /// Handles a scroll wheel movement.
    open func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    /// Copies the selection to the general pasteboard.
    ///
    /// Sent along the responder chain like AppKit's Edit-menu actions;
    /// responders with selections override this.
    open func copy(_ sender: Any?) {
        nextResponder?.copy(sender)
    }

    /// Deletes the selection after copying it to the general pasteboard.
    open func cut(_ sender: Any?) {
        nextResponder?.cut(sender)
    }

    /// Inserts the general pasteboard's contents at the selection.
    open func paste(_ sender: Any?) {
        nextResponder?.paste(sender)
    }

    /// Moves the insertion point up — one of AppKit's standard key-binding
    /// action methods. The base forwards along the responder chain; objects
    /// that handle it override (and demo action trampolines override it
    /// precisely because overriding an inherited method is `@objc`-free on every
    /// target, so the same source builds against real AppKit too).
    open func moveUp(_ sender: Any?) {
        nextResponder?.moveUp(sender)
    }

    /// Moves the insertion point down (see `moveUp(_:)`).
    open func moveDown(_ sender: Any?) {
        nextResponder?.moveDown(sender)
    }

    /// Handles a key press.
    open func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }

    /// Handles a key release.
    open func keyUp(with event: NSEvent) {
        nextResponder?.keyUp(with: event)
    }

    /// Handles a change to the keyboard modifier flags.
    open func flagsChanged(with event: NSEvent) {
        nextResponder?.flagsChanged(with: event)
    }

    /// Handles the cursor entering a tracking area.
    ///
    /// The tracking-area delivery machinery is item 3.21 (hover tracking); this
    /// override point exists so responders that implement it compile and can be
    /// wired up when tracking areas land.
    open func mouseEntered(with event: NSEvent) {
        nextResponder?.mouseEntered(with: event)
    }

    /// Handles the cursor leaving a tracking area (see `mouseEntered(with:)`).
    open func mouseExited(with event: NSEvent) {
        nextResponder?.mouseExited(with: event)
    }
}

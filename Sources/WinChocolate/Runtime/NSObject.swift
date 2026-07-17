/// Root class for WinChocolate objects.
///
/// AppKit's public API is class-heavy and often inherits from `NSObject`.
/// WinChocolate provides a small Swift-native root object so those inheritance
/// relationships can be represented on Windows without depending on Objective-C
/// runtime behavior.
open class NSObject {
    /// Creates a root object.
    public init() {}

    /// Identity equality, matching `NSObject.isEqual(_:)` (subclasses with
    /// value semantics override).
    open func isEqual(_ object: Any?) -> Bool {
        (object as? NSObject) === self
    }

    /// Identity hash, matching `NSObject.hash`.
    open var hash: Int {
        ObjectIdentifier(self).hashValue
    }

    /// The type name, matching `NSObject.description`'s common shape.
    open var description: String {
        String(describing: type(of: self))
    }

    // MARK: Selector dispatch (Phase 18.1)
    //
    // Apple's target/action fires through the Objective-C runtime: the sender
    // asks the target `respondsToSelector:` and then `performSelector:`s it.
    // Swift on Windows has no such runtime, so WinChocolate keeps the same
    // two-method surface — `responds(to:)` / `perform(_:with:)` — as *open,
    // overridable* methods. Framework classes that receive actions override
    // them with a selector-name switch, and application code can do the same
    // (a plain Swift override — no registration API). The base object claims
    // no selectors.
    //
    // Documented divergence: Apple's `perform(_:with:)` returns
    // `Unmanaged<AnyObject>!`; without the Objective-C runtime that type has
    // no meaning here, so WinChocolate returns `Any?`. Call sites that ignore
    // the result (the overwhelming case for action dispatch) are source-
    // compatible.

    /// Returns whether the receiver can handle a selector, matching
    /// `NSObject.responds(to:)`. The base implementation knows no selectors;
    /// subclasses that receive actions override this together with
    /// `perform(_:with:)`.
    open func responds(to aSelector: Selector?) -> Bool {
        _ = aSelector
        return false
    }

    /// Sends a selector with no argument, matching `NSObject.perform(_:)`.
    @discardableResult
    public func perform(_ aSelector: Selector) -> Any? {
        perform(aSelector, with: nil)
    }

    /// Sends a selector to the receiver, matching `NSObject.perform(_:with:)`.
    /// Subclasses override this with a name switch calling the real method.
    /// The base implementation does nothing and returns `nil` (AppKit would
    /// raise `doesNotRecognizeSelector:`; WinChocolate stays quiet so optional
    /// action paths degrade gracefully).
    @discardableResult
    open func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        _ = aSelector
        _ = object
        return nil
    }
}

/// `NSObject` is the root conformer to `NSObjectProtocol`, as in Foundation —
/// delegate protocols refine `NSObjectProtocol` (18.5), so conformers inherit
/// `NSObject`, exactly AppKit's requirement.
extension NSObject: NSObjectProtocol {}

extension NSObject: Equatable {
    /// Identity equality, matching `NSObject`'s default `isEqual(_:)`.
    public static func == (lhs: NSObject, rhs: NSObject) -> Bool {
        lhs === rhs
    }
}

extension NSObject: Hashable {
    /// Identity hash, matching `NSObject`'s default `hash`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

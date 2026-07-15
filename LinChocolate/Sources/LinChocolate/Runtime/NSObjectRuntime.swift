/// LinChocolate's `NSObject` — the selector-dispatch root the AppKit surface
/// needs on a platform with no Objective-C runtime.
///
/// This is the LinChocolate port of WinFoundation's `NSObject`: `Selector` is a
/// plain named value (`Runtime/Selector.swift`), and dynamic dispatch is these
/// two overridable methods. App code overrides them exactly as it would
/// override the ObjC-runtime versions on macOS — the shared demo's
/// `DemoActionTarget` is the canonical caller:
///
///     override func responds(to aSelector: Selector?) -> Bool { … }
///     override func perform(_ aSelector: Selector, with object: Any?) -> Any? { … }
///
/// Because LinChocolate imports Foundation, this declaration shadows
/// `Foundation.NSObject` for clients that import both — the same shadowing
/// WinChocolate relies on with WinFoundation on Windows.
open class NSObject {

    public init() {}

    /// Whether the receiver can handle `aSelector`. The base class knows no
    /// selectors; subclasses that install handlers override this.
    open func responds(to aSelector: Selector?) -> Bool {
        false
    }

    /// Sends `aSelector` to the receiver. The base class ignores it;
    /// subclasses that install handlers override this. Controls dispatch
    /// their `target`/`action` through here.
    @discardableResult
    open func perform(_ aSelector: Selector, with object: Any? = nil) -> Any? {
        nil
    }

    open var description: String {
        "\(type(of: self))"
    }
}

/// AppKit's responder-chain base. LinChocolate's chain is a slice — views
/// override `acceptsFirstResponder` and the event methods on `NSView` — but
/// the class must exist and sit between `NSObject` and `NSView`, as on Apple,
/// so app code can type against it (`updateFocusDisplay(_: NSResponder?)`).
open class NSResponder: NSObject {

    /// Whether the receiver is willing to become first responder.
    open var acceptsFirstResponder: Bool {
        false
    }

    /// The next responder up the chain, or nil at the top.
    open weak var nextResponder: NSResponder?
}

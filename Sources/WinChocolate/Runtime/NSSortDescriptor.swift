/// Sort descriptor compatible with AppKit table APIs.
///
/// This lightweight version stores the public sorting request. Actual model
/// sorting remains the application's responsibility until WinChocolate grows
/// more Foundation-compatible collection helpers on this Windows toolchain.
open class NSSortDescriptor: NSObject {
    /// Model key to sort by.
    open var key: String?

    /// Whether the sort is ascending.
    open var ascending: Bool

    /// Optional selector used by Cocoa callers for custom comparison.
    open var selector: Selector?

    /// Creates a sort descriptor.
    public init(key: String?, ascending: Bool) {
        self.key = key
        self.ascending = ascending
        self.selector = nil
        super.init()
    }

    /// Creates a sort descriptor with a selector.
    public init(key: String?, ascending: Bool, selector: Selector?) {
        self.key = key
        self.ascending = ascending
        self.selector = selector
        super.init()
    }

    /// Returns a descriptor with the ascending flag flipped.
    open var reversedSortDescriptor: NSSortDescriptor {
        NSSortDescriptor(key: key, ascending: !ascending, selector: selector)
    }
}

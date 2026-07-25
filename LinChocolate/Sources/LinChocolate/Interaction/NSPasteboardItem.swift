import Foundation

/// A type whose instances can be written to a pasteboard — Apple's
/// `NSPasteboardWriting`, in the reduced shape LinChocolate's pasteboard
/// needs: each writer contributes one string representation per type.
public protocol NSPasteboardWriting: AnyObject {
    /// The types this writer can provide.
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType]

    /// The property-list representation for `type` (a `String` here).
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any?
}

/// Strings write themselves as `.string`, as on Apple.
extension NSString: NSPasteboardWriting {
    /// Strings write themselves under `.string`.
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.string]
    }

    /// Returns the string value for the `.string` type, otherwise nil.
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        type == .string ? String(describing: self) : nil
    }
}

/// One item on a pasteboard, carrying its own type→value map. A multi-object
/// write produces one item per object (the format AppKit's writer-per-row
/// table drags produce and `acceptDrop` reads back).
public final class NSPasteboardItem: NSPasteboardWriting {

    private var values: [NSPasteboard.PasteboardType: String] = [:]

    /// Creates an empty pasteboard item; add values with `setString(_:forType:)`.
    public init() {}

    /// The types this item holds a value for.
    public var types: [NSPasteboard.PasteboardType] {
        Array(values.keys)
    }

    /// The item's string for `type`, or nil.
    public func string(forType type: NSPasteboard.PasteboardType) -> String? {
        values[type]
    }

    /// Stores `string` under `type`.
    @discardableResult
    public func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        values[type] = string
        return true
    }

    /// The types the item can supply values for.
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        types
    }

    /// The item's stored value (a String) for `type`, or nil.
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        values[type]
    }
}

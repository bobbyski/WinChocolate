import Foundation

/// AppKit-shaped drag operation mask (values match AppKit's bit layout).
public struct NSDragOperation: OptionSet, Sendable {
    /// The raw bit-mask value.
    public let rawValue: UInt
    /// Creates an operation set from raw bits.
    public init(rawValue: UInt) { self.rawValue = rawValue }
    /// No drag operation.
    public static let none = NSDragOperation([])
    /// Copy the dragged data to the destination.
    public static let copy = NSDragOperation(rawValue: 1)
    /// Create a link to the dragged data at the destination.
    public static let link = NSDragOperation(rawValue: 2)
    /// A generic drag operation.
    public static let generic = NSDragOperation(rawValue: 4)
    /// Move the dragged data to the destination.
    public static let move = NSDragOperation(rawValue: 16)
    /// The union of copy, link, generic, and move.
    public static let every: NSDragOperation = [.copy, .link, .generic, .move]
}

/// Information about a drag as it crosses / drops on a destination — AppKit's
/// `NSDraggingInfo`. Carries the drag pasteboard and the drop point (in the
/// destination view's AppKit coordinates).
public protocol NSDraggingInfo: AnyObject {
    /// The pasteboard carrying the dragged payload.
    var draggingPasteboard: NSPasteboard { get }
    /// The drop point in the destination view's AppKit coordinates.
    var draggingLocation: NSPoint { get }
    /// The operations the source is willing to perform.
    var draggingSourceOperationMask: NSDragOperation { get }
}

/// Concrete `NSDraggingInfo` the view builds when a drop arrives.
final class DraggingInfo: NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    let draggingLocation: NSPoint
    let draggingSourceOperationMask: NSDragOperation
    init(pasteboard: NSPasteboard, location: NSPoint, operation: NSDragOperation = .copy) {
        self.draggingPasteboard = pasteboard
        self.draggingLocation = location
        self.draggingSourceOperationMask = operation
    }
}

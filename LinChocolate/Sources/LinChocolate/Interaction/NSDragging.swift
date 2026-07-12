import Foundation

/// AppKit-shaped drag operation mask (values match AppKit's bit layout).
public struct NSDragOperation: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let none = NSDragOperation([])
    public static let copy = NSDragOperation(rawValue: 1)
    public static let link = NSDragOperation(rawValue: 2)
    public static let generic = NSDragOperation(rawValue: 4)
    public static let move = NSDragOperation(rawValue: 16)
    public static let every: NSDragOperation = [.copy, .link, .generic, .move]
}

/// Information about a drag as it crosses / drops on a destination — AppKit's
/// `NSDraggingInfo`. Carries the drag pasteboard and the drop point (in the
/// destination view's AppKit coordinates).
public protocol NSDraggingInfo: AnyObject {
    var draggingPasteboard: NSPasteboard { get }
    var draggingLocation: NSPoint { get }
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

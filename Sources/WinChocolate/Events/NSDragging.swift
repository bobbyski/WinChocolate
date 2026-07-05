import WinFoundation

/// Drag operations a source permits and a destination performs.
public struct NSDragOperation: OptionSet, Sendable {
    /// The raw option bits (AppKit-compatible values).
    public let rawValue: UInt

    /// Creates a drag operation set from raw bits.
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// The data can be copied.
    public static let copy = NSDragOperation(rawValue: 1)

    /// The data can be shared by link.
    public static let link = NSDragOperation(rawValue: 2)

    /// The operation is defined by the destination.
    public static let generic = NSDragOperation(rawValue: 4)

    /// The data can be moved.
    public static let move = NSDragOperation(rawValue: 16)

    /// Every operation.
    public static let every = NSDragOperation(rawValue: UInt.max)
}

/// Information about a drag in progress, matching AppKit's `NSDraggingInfo`.
public protocol NSDraggingInfo: AnyObject {
    /// The pasteboard carrying the dragged content.
    var draggingPasteboard: NSPasteboard { get }

    /// The cursor location in the destination view's coordinate space.
    var draggingLocation: NSPoint { get }

    /// The operations the source permits.
    var draggingSourceOperationMask: NSDragOperation { get }
}

/// The dragging info the framework hands to destination views.
final class WinDraggingInfo: NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    let draggingLocation: NSPoint
    let draggingSourceOperationMask: NSDragOperation

    init(content: NativeDropContent, location: NSPoint) {
        draggingPasteboard = WinDragPasteboard(content: content)
        draggingLocation = location
        draggingSourceOperationMask = [.copy, .move, .link, .generic]
    }
}

/// A pasteboard serving a drag's captured content instead of the system
/// clipboard, so `draggingPasteboard` reads see the dragged data.
final class WinDragPasteboard: NSPasteboard {
    private let content: NativeDropContent

    init(content: NativeDropContent) {
        self.content = content
        super.init()
    }

    override var types: [PasteboardType]? {
        var available: [PasteboardType] = []
        if content.text != nil {
            available.append(.string)
        }
        if !content.filePaths.isEmpty {
            available.append(.fileURL)
        }
        return available.isEmpty ? nil : available
    }

    override func string(forType dataType: PasteboardType) -> String? {
        switch dataType {
        case .string:
            return content.text
        case .fileURL:
            return content.filePaths.first.map { URL(fileURLWithPath: $0).absoluteString }
        default:
            return nil
        }
    }

    override var pasteboardItems: [NSPasteboardItem]? {
        if !content.filePaths.isEmpty {
            return content.filePaths.map { path in
                let item = NSPasteboardItem()
                item.setString(URL(fileURLWithPath: path).absoluteString, forType: .fileURL)
                return item
            }
        }
        guard let text = content.text else {
            return nil
        }
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        return [item]
    }

    override func readObjects(forClasses classes: [Any.Type], options: [String: Any]? = nil) -> [Any]? {
        var results: [Any] = []
        for readClass in classes {
            if readClass == URL.self {
                results.append(contentsOf: content.filePaths.map { URL(fileURLWithPath: $0) })
            } else if readClass == String.self, let text = content.text {
                results.append(text)
            }
        }
        return results.isEmpty ? nil : results
    }
}

/// One dragged item, matching AppKit's `NSDraggingItem` shape.
///
/// The pasteboard writer supplies the dragged content: a `String` drags text,
/// a file `URL` (or an `NSPasteboardItem` carrying one) drags a file.
open class NSDraggingItem: NSObject {
    /// The object providing the item's pasteboard representations.
    public let pasteboardWriter: Any

    /// The item's drag frame (stored; the classic backend shows the standard
    /// system drag cursor rather than a rendered image).
    open var draggingFrame: NSRect = .zero

    /// Creates a dragging item for a pasteboard writer.
    public init(pasteboardWriter: Any) {
        self.pasteboardWriter = pasteboardWriter
        super.init()
    }
}

/// The methods a dragging source implements, matching AppKit.
public protocol NSDraggingSource: AnyObject {
    /// The operations the source permits for a dragging session.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation
}

/// Where a dragging session's destination is.
public enum NSDraggingContext: Sendable {
    /// The destination is outside the application.
    case outsideApplication

    /// The destination is within the application.
    case withinApplication
}

/// A drag session begun by `NSView.beginDraggingSession`, matching AppKit's
/// shape. The classic backend runs the OLE drag synchronously, so the session
/// reports its outcome as soon as it is returned.
open class NSDraggingSession: NSObject {
    /// Whether the content was dropped on a target (vs the drag canceling).
    public internal(set) var winDropped = false

    /// The dragged items.
    public let draggingItems: [NSDraggingItem]

    init(items: [NSDraggingItem]) {
        self.draggingItems = items
        super.init()
    }
}

extension NSView {
    /// The types this view accepts for drops, when registered.
    public internal(set) var registeredDraggedTypes: [NSPasteboard.PasteboardType] {
        get { winRegisteredDraggedTypes }
        set { winRegisteredDraggedTypes = newValue }
    }

    /// Registers the view to receive native drops of the given types.
    ///
    /// The classic backend delivers plain text (`.string`) and file lists
    /// (`.fileURL`) — the platform's cross-application drag formats. The
    /// dragging methods (`draggingEntered`, `performDragOperation`, ...) run
    /// against a pasteboard carrying the dragged content.
    public func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {
        winRegisteredDraggedTypes = newTypes
        installDropTargetIfRealized()
    }

    /// Removes the view's drop registration.
    public func unregisterDraggedTypes() {
        winRegisteredDraggedTypes = []
        if let nativeHandle {
            realizedBackend?.unregisterDropTarget(for: nativeHandle)
        }
    }

    /// Whether dragged content matches the view's registered types.
    func acceptsDropContent(_ content: NativeDropContent) -> Bool {
        for type in winRegisteredDraggedTypes {
            if type == .string, content.text != nil {
                return true
            }
            if type == .fileURL, !content.filePaths.isEmpty {
                return true
            }
        }
        return false
    }

    /// Installs the backend drop target for a realized view.
    func installDropTargetIfRealized() {
        guard let nativeHandle, let realizedBackend, !winRegisteredDraggedTypes.isEmpty else {
            return
        }

        realizedBackend.registerDropTarget(for: nativeHandle, handler: NativeDropHandler(
            entered: { [weak self] content, location in
                guard let self, self.acceptsDropContent(content) else {
                    return false
                }
                let info = WinDraggingInfo(content: content, location: location)
                self.winActiveDragInfo = info
                return self.draggingEntered(info) != []
            },
            moved: { [weak self] location in
                guard let self, let info = self.winActiveDragInfo else {
                    return false
                }
                let moved = WinDraggingInfo(content: (info.draggingPasteboard as? WinDragPasteboard)?.winContent ?? NativeDropContent(text: nil, filePaths: []), location: location)
                self.winActiveDragInfo = moved
                return self.draggingUpdated(moved) != []
            },
            exited: { [weak self] in
                guard let self else {
                    return
                }
                self.draggingExited(self.winActiveDragInfo)
                self.winActiveDragInfo = nil
            },
            performed: { [weak self] content, location in
                guard let self, self.acceptsDropContent(content) else {
                    return false
                }
                let info = WinDraggingInfo(content: content, location: location)
                defer {
                    self.winActiveDragInfo = nil
                }
                guard self.prepareForDragOperation(info) else {
                    return false
                }
                let performed = self.performDragOperation(info)
                if performed {
                    self.concludeDragOperation(info)
                }
                return performed
            }
        ))
    }

    // MARK: - Dragging source

    /// Starts a drag with the given items, matching AppKit's API.
    ///
    /// The classic backend runs the platform drag loop synchronously and the
    /// returned session reports whether the content was dropped. Supported
    /// writers: `String` (text), file `URL`s, and `NSPasteboardItem`s carrying
    /// `.string`/`.fileURL` representations.
    @discardableResult
    public func beginDraggingSession(with items: [NSDraggingItem], event: NSEvent, source: NSDraggingSource) -> NSDraggingSession {
        let session = NSDraggingSession(items: items)
        _ = source.draggingSession(session, sourceOperationMaskFor: .outsideApplication)

        var text: String?
        var filePaths: [String] = []
        for item in items {
            switch item.pasteboardWriter {
            case let string as String:
                text = string
            case let url as URL where url.isFileURL:
                filePaths.append(url.path)
            case let pasteboardItem as NSPasteboardItem:
                if let itemText = pasteboardItem.string(forType: .string) {
                    text = itemText
                }
                if let urlString = pasteboardItem.string(forType: .fileURL), let url = URL(string: urlString), url.isFileURL {
                    filePaths.append(url.path)
                }
            default:
                break
            }
        }

        guard text != nil || !filePaths.isEmpty, let nativeHandle, let realizedBackend else {
            return session
        }
        session.winDropped = realizedBackend.performDrag(
            content: NativeDropContent(text: text, filePaths: filePaths),
            from: nativeHandle
        )
        return session
    }
}

extension WinDragPasteboard {
    /// The captured drag content, for handler continuation.
    var winContent: NativeDropContent {
        NativeDropContent(
            text: string(forType: .string),
            filePaths: (pasteboardItems ?? []).compactMap { item in
                guard let urlString = item.string(forType: .fileURL), let url = URL(string: urlString), url.isFileURL else {
                    return nil
                }
                return url.path
            }
        )
    }
}

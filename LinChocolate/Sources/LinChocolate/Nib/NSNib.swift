import Foundation

/// Interface Builder document loading — the LinChocolate port of WinChocolate's
/// `NSNib` (Phase 15). Parses `.xib` XML documents directly (the stable,
/// human-readable source format) rather than compiled binary `.nib` keyed
/// archives, so the same shared demo loads a xib on GTK exactly as on Win32.
///
/// Outlet wiring by name (`@IBOutlet`) needs a KVC/reflection layer Swift on
/// Linux doesn't provide, so the object graph is instantiated fully and apps
/// wire outlets through `winInstantiate` — identified-object lookup plus the
/// parsed connection records; control actions whose target resolves are applied
/// as `target`/`action`.

/// An Interface Builder document, matching AppKit's `NSNib`.
open class NSNib: NSObject {
    /// The name of a nib, matching AppKit's typealias.
    public typealias Name = String

    private let xibText: String?
    private let bundle: Bundle?

    /// Loads a nib by name from a bundle (searching `<name>.xib`). Passing `nil`
    /// searches the main bundle, then the working directory.
    public init?(nibNamed name: NSNib.Name, bundle: Bundle? = nil) {
        let searchBundles: [Bundle] = [bundle, Bundle.main, Bundle(path: ".")].compactMap { $0 }
        var found: String?
        for candidate in searchBundles {
            if let path = candidate.path(forResource: name, ofType: "xib") {
                found = path
                break
            }
        }
        guard let path = found, let text = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
            return nil
        }
        self.xibText = text
        self.bundle = bundle
        super.init()
    }

    /// Creates a nib from in-memory xib XML data, matching AppKit's shape.
    /// Parse problems surface as a `false` return from `instantiate`.
    public init(nibData: Data, bundle: Bundle? = nil) {
        self.xibText = String(decoding: nibData, as: UTF8.self)
        self.bundle = bundle
        super.init()
    }

    /// Instantiates the nib's object graph, matching AppKit's shape: top-level
    /// objects are appended to `topLevelObjects` and `owner` stands in for
    /// File's Owner. Returns whether instantiation succeeded.
    @discardableResult
    /// Apple's call shape: `var topLevel: NSArray?` + `&topLevel`. (On Darwin
    /// the parameter is an `AutoreleasingUnsafeMutablePointer<NSArray?>?`; an
    /// `inout NSArray?` accepts the same `&topLevel` argument, so one shared
    /// demo line compiles against both.)
    open func instantiate(withOwner owner: Any?, topLevelObjects: inout NSArray?) -> Bool {
        var objects: [Any]?
        let ok = instantiate(withOwner: owner, topLevelObjects: &objects)
        topLevelObjects = objects.map { NSArray(array: $0) }
        return ok
    }

    open func instantiate(withOwner owner: Any?, topLevelObjects: inout [Any]?) -> Bool {
        guard let instance = winInstantiate(withOwner: owner) else {
            return false
        }
        topLevelObjects = instance.topLevelObjects
        return true
    }

    /// Instantiates the nib's object graph and returns the rich result:
    /// top-level objects, every identified object, and the parsed outlet/action
    /// connections — the manual-wiring surface while automatic `@IBOutlet`
    /// binding awaits a KVC layer.
    open func winInstantiate(withOwner owner: Any? = nil) -> NibInstance? {
        guard let xibText, let document = NibXML.parse(xibText), document.name == "document" else {
            return nil
        }
        return NibDecoder(owner: owner).decode(document)
    }
}

extension Bundle {
    /// Loads a nib by name from this bundle, matching AppKit's shape.
    @discardableResult
    public func loadNibNamed(_ nibName: NSNib.Name, owner: Any?, topLevelObjects: inout [Any]?) -> Bool {
        guard let nib = NSNib(nibNamed: nibName, bundle: self) else {
            return false
        }
        return nib.instantiate(withOwner: owner, topLevelObjects: &topLevelObjects)
    }
}

/// One instantiated nib object graph.
public final class NibInstance {
    /// The top-level objects (views, windows, custom objects), in document order.
    public let topLevelObjects: [Any]

    /// Every instantiated object carrying an `id`, keyed by that xib id.
    public let objectsByID: [String: AnyObject]

    /// The parsed `<connections>` records, resolved against the graph.
    public let connections: [NibConnection]

    init(topLevelObjects: [Any], objectsByID: [String: AnyObject], connections: [NibConnection]) {
        self.topLevelObjects = topLevelObjects
        self.objectsByID = objectsByID
        self.connections = connections
    }

    /// The instantiated object with an xib `id`, or `nil`.
    public func object(withID id: String) -> AnyObject? {
        objectsByID[id]
    }

    /// Depth-first search of the top-level views for a view whose `identifier`
    /// (the Identity inspector's "Identifier" field) matches — the manual-wiring
    /// lookup apps use in place of outlets.
    public func view(withIdentifier identifier: String) -> NSView? {
        func search(_ view: NSView) -> NSView? {
            if view.identifier?.rawValue == identifier {
                return view
            }
            for subview in view.subviews {
                if let hit = search(subview) {
                    return hit
                }
            }
            return nil
        }
        for object in topLevelObjects {
            if let view = object as? NSView, let hit = search(view) {
                return hit
            }
            if let window = object as? NSWindow, let content = window.contentView, let hit = search(content) {
                return hit
            }
        }
        return nil
    }
}

/// One `<outlet>` or `<action>` connection parsed from the xib.
public struct NibConnection {
    public enum Kind: Equatable {
        /// An `<action selector=... target=.../>`: source fires selector at target.
        case action
        /// An `<outlet property=... destination=.../>`: source's property should
        /// reference destination (wired manually pending a KVC layer).
        case outlet
    }

    public let kind: Kind
    /// The selector name (actions) or property name (outlets).
    public let name: String
    /// The object the connection originates from (the control for actions).
    public private(set) weak var source: AnyObject?
    /// The resolved target (actions) or destination (outlets); File's Owner
    /// resolves to the instantiate owner.
    public private(set) weak var destination: AnyObject?

    init(kind: Kind, name: String, source: AnyObject?, destination: AnyObject?) {
        self.kind = kind
        self.name = name
        self.source = source
        self.destination = destination
    }
}

/// A stand-in for a xib `customObject` whose `customClass` can't be
/// instantiated without a reflection runtime: it keeps the graph's ids
/// resolvable and tells the app which class the document asked for.
public final class NibCustomObject: NSObject {
    /// The `customClass` the xib named, e.g. a view-controller subclass.
    public let customClassName: String
    /// The Interface Builder user label, when present.
    public let userLabel: String?

    init(customClassName: String, userLabel: String?) {
        self.customClassName = customClassName
        self.userLabel = userLabel
    }
}

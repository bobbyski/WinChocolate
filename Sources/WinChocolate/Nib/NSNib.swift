// NSNib.swift
// Interface Builder document loading (Phase 15).
//
// WinChocolate parses `.xib` XML documents directly — the human-readable
// source format — rather than compiled binary `.nib` keyed archives (plan
// 15's design decision: parsing the stable XML avoids reimplementing
// NSKeyedUnarchiver, and Windows-built apps carry their xibs as resources).
//
// Outlet wiring (`@IBOutlet` by name) needs KVC/reflection Swift-on-Windows
// does not provide (the same gap deferring Cocoa bindings, 12.1), so the
// first slice matches plan 15.4: the object graph is instantiated fully, and
// apps wire outlets through `WinNibInstance` — identified-object lookup plus
// the parsed connection records. Actions on controls whose target resolves
// (File's Owner or another nib object) are applied as `target`/`action`.

/// An Interface Builder document, matching AppKit's `NSNib`.
open class NSNib: NSObject {
    /// The name of a nib, matching AppKit's typealias.
    public typealias Name = String

    private let xibText: String?
    private let bundle: Bundle?

    /// Loads a nib by name from a bundle (searching `<name>.xib`).
    ///
    /// Passing `nil` searches the main bundle, then the working directory —
    /// covering bundle-less Windows executables whose resources sit beside
    /// the package.
    public init?(nibNamed name: NSNib.Name, bundle: Bundle? = nil) {
        let searchBundles: [Bundle] = [bundle, Bundle.main, Bundle(path: ".")].compactMap { $0 }
        var found: String?
        for candidate in searchBundles {
            if let path = candidate.path(forResource: name, ofType: "xib") {
                found = path
                break
            }
        }
        guard let path = found, let text = try? String(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        self.xibText = text
        self.bundle = bundle
        super.init()
    }

    /// Creates a nib from in-memory xib XML data, matching AppKit's shape.
    /// Parse problems surface as a `false` return from `instantiate`.
    public init(nibData: Data, bundle: Bundle? = nil) {
        self.xibText = String(decoding: nibData.array, as: UTF8.self)
        self.bundle = bundle
        super.init()
    }

    /// Instantiates the nib's object graph, matching AppKit's shape: the
    /// top-level objects are appended to `topLevelObjects` and the owner
    /// stands in for File's Owner. Returns whether instantiation succeeded.
    @discardableResult
    open func instantiate(withOwner owner: Any?, topLevelObjects: inout [Any]?) -> Bool {
        guard let instance = winInstantiate(withOwner: owner) else {
            return false
        }
        topLevelObjects = instance.topLevelObjects
        return true
    }

    /// Instantiates the nib's object graph and returns the rich result:
    /// top-level objects, every identified object, and the parsed outlet and
    /// action connections — the Windows-side wiring surface while automatic
    /// `@IBOutlet` binding awaits a KVC layer (plan 15.4).
    open func winInstantiate(withOwner owner: Any? = nil) -> WinNibInstance? {
        guard let xibText, let document = WinXML.parse(xibText), document.name == "document" else {
            return nil
        }
        return WinNibDecoder(owner: owner).decode(document)
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
public final class WinNibInstance {
    /// The top-level objects (views, windows, custom objects), in document order.
    public let topLevelObjects: [Any]

    /// Every instantiated object carrying an `id`, keyed by that xib id.
    public let objectsByID: [String: AnyObject]

    /// The parsed `<connections>` records, resolved against the graph.
    public let connections: [WinNibConnection]

    init(topLevelObjects: [Any], objectsByID: [String: AnyObject], connections: [WinNibConnection]) {
        self.topLevelObjects = topLevelObjects
        self.objectsByID = objectsByID
        self.connections = connections
    }

    /// The instantiated object with an xib `id`, or `nil`.
    public func object(withID id: String) -> AnyObject? {
        objectsByID[id]
    }

    /// Depth-first search of the top-level views for a view whose
    /// `identifier` (the Identity inspector's "Identifier" field) matches —
    /// the manual-wiring lookup apps use in place of outlets.
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
public struct WinNibConnection {
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

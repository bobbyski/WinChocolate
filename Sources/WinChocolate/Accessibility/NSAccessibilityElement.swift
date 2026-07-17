// NSAccessibilityElement.swift
// The shared accessibility-node protocol plus AppKit's NSAccessibilityElement,
// a lightweight element used to publish parts of a view that draw their own
// content (table rows/cells, outline rows) and therefore have no backing view.

/// The subset of AppKit's `NSAccessibilityProtocol` that both real views and
/// synthetic `NSAccessibilityElement`s implement. The accessibility tree walker
/// and the native UIA bridge consume elements through this protocol.
///
/// The protocol is deliberately *not* `@MainActor`: the framework builds in
/// Swift 5 mode with nonisolated views, and a `@MainActor` requirement would
/// make every conforming view (NSView and its whole subclass tree) infer
/// main-actor isolation, cascading isolation errors across the module. Callers
/// already run on the single UI thread.
public protocol NSAccessibilityProtocol: AnyObject {
    func isAccessibilityElement() -> Bool
    func accessibilityRole() -> NSAccessibilityRole?
    func accessibilitySubrole() -> NSAccessibilitySubrole?
    func accessibilityRoleDescription() -> String?
    func accessibilityLabel() -> String?
    func accessibilityTitle() -> String?
    func accessibilityValue() -> Any?
    func accessibilityHelp() -> String?
    func accessibilityFrame() -> NSRect
    func isAccessibilityEnabled() -> Bool
    func accessibilityChildren() -> [Any]?
}

/// A standalone accessibility element, matching AppKit's `NSAccessibilityElement`.
///
/// Views that render their own cells (the drawn `NSTableView`, `NSOutlineView`,
/// `NSCollectionView`, `NSBrowser`) vend these to describe rows and cells that
/// have no `NSView` of their own, so assistive technology can still navigate
/// them.
open class NSAccessibilityElement: NSAccessibilityProtocol {
    /// The element's frame in the coordinate space of its containing window.
    open var accessibilityFrameInParentSpace: NSRect = .zero
    private var storedRole: NSAccessibilityRole?
    private var storedSubrole: NSAccessibilitySubrole?
    private var storedLabel: String?
    private var storedTitle: String?
    private var storedValue: Any?
    private var storedHelp: String?
    private var storedRoleDescription: String?
    private var storedEnabled: Bool = true
    private var storedChildren: [NSAccessibilityProtocol] = []
    /// The element's parent element (weakly held to avoid retain cycles).
    open weak var winAccessibilityParent: AnyObject?

    public init() {}

    /// Convenience initializer mirroring AppKit's factory element.
    public static func element(withRole role: NSAccessibilityRole,
                               frame: NSRect,
                               label: String?,
                               parent: AnyObject?) -> NSAccessibilityElement {
        let element = NSAccessibilityElement()
        element.storedRole = role
        element.accessibilityFrameInParentSpace = frame
        element.storedLabel = label
        element.winAccessibilityParent = parent
        return element
    }

    open func setAccessibilityRole(_ role: NSAccessibilityRole?) { storedRole = role }
    open func setAccessibilitySubrole(_ subrole: NSAccessibilitySubrole?) { storedSubrole = subrole }
    open func setAccessibilityLabel(_ label: String?) { storedLabel = label }
    open func setAccessibilityTitle(_ title: String?) { storedTitle = title }
    open func setAccessibilityValue(_ value: Any?) { storedValue = value }
    open func setAccessibilityHelp(_ help: String?) { storedHelp = help }
    open func setAccessibilityRoleDescription(_ description: String?) { storedRoleDescription = description }
    open func setAccessibilityEnabled(_ enabled: Bool) { storedEnabled = enabled }

    /// Replaces the element's child elements.
    open func setAccessibilityChildren(_ children: [NSAccessibilityProtocol]) {
        storedChildren = children
        for case let child as NSAccessibilityElement in children {
            child.winAccessibilityParent = self
        }
    }

    /// Appends a child element.
    open func addAccessibilityChild(_ child: NSAccessibilityProtocol) {
        storedChildren.append(child)
        (child as? NSAccessibilityElement)?.winAccessibilityParent = self
    }

    // MARK: NSAccessibilityProtocol

    open func isAccessibilityElement() -> Bool { true }
    open func accessibilityRole() -> NSAccessibilityRole? { storedRole }
    open func accessibilitySubrole() -> NSAccessibilitySubrole? { storedSubrole }
    open func accessibilityRoleDescription() -> String? {
        storedRoleDescription ?? storedRole?.winDefaultRoleDescription
    }
    open func accessibilityLabel() -> String? { storedLabel }
    open func accessibilityTitle() -> String? { storedTitle }
    open func accessibilityValue() -> Any? { storedValue }
    open func accessibilityHelp() -> String? { storedHelp }
    open func accessibilityFrame() -> NSRect { accessibilityFrameInParentSpace }
    open func isAccessibilityEnabled() -> Bool { storedEnabled }
    open func accessibilityChildren() -> [Any]? {
        storedChildren.isEmpty ? nil : storedChildren
    }
}

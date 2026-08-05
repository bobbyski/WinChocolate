// NSAccessibilityTree.swift
// Conforms NSView to the accessibility protocol and provides a deterministic
// snapshot of the accessibility tree. The snapshot is what the contract tests
// assert against (no screen reader needed) and what the native UIA/WM_GETOBJECT
// bridge walks to answer provider queries.

extension NSView: NSAccessibilityProtocol {}

/// A serialized node of the accessibility tree — the shape assistive technology
/// (and the contract tests) see. Value type, so it is safe to capture and diff.
public struct WinAccessibilitySnapshot: Sendable {
    public var role: String
    public var subrole: String?
    public var roleDescription: String?
    public var label: String?
    public var title: String?
    public var value: String?
    public var help: String?
    public var isElement: Bool
    public var isEnabled: Bool
    public var frame: NSRect
    public var children: [WinAccessibilitySnapshot]

    /// The number of elements in this subtree (self if an element, plus
    /// descendants) — a convenient assertion target.
    public var elementCount: Int {
        (isElement ? 1 : 0) + children.reduce(0) { $0 + $1.elementCount }
    }

    /// Depth-first search for the first element with the given label.
    public func firstDescendant(labeled label: String) -> WinAccessibilitySnapshot? {
        if self.label == label { return self }
        for child in children {
            if let hit = child.firstDescendant(labeled: label) { return hit }
        }
        return nil
    }

    /// All elements in the subtree carrying the given role.
    public func descendants(role: NSAccessibilityRole) -> [WinAccessibilitySnapshot] {
        var out: [WinAccessibilitySnapshot] = []
        if self.role == role.rawValue { out.append(self) }
        for child in children { out.append(contentsOf: child.descendants(role: role)) }
        return out
    }
}

public func winMakeAccessibilitySnapshot(of element: NSAccessibilityProtocol) -> WinAccessibilitySnapshot {
    let childElements: [NSAccessibilityProtocol] = (element.accessibilityChildren() ?? [])
        .compactMap { $0 as? NSAccessibilityProtocol }
    return WinAccessibilitySnapshot(
        role: element.accessibilityRole()?.rawValue ?? NSAccessibilityRole.unknown.rawValue,
        subrole: element.accessibilitySubrole()?.rawValue,
        roleDescription: element.accessibilityRoleDescription(),
        label: element.accessibilityLabel(),
        title: element.accessibilityTitle(),
        value: element.accessibilityValue().map { String(describing: $0) },
        help: element.accessibilityHelp(),
        isElement: element.isAccessibilityElement(),
        isEnabled: element.isAccessibilityEnabled(),
        frame: element.accessibilityFrame(),
        children: childElements.map { winMakeAccessibilitySnapshot(of: $0) }
    )
}

extension NSView {
    /// The accessibility tree rooted at this view, as a value snapshot.
    public func winAccessibilitySnapshot() -> WinAccessibilitySnapshot {
        winMakeAccessibilitySnapshot(of: self)
    }
}

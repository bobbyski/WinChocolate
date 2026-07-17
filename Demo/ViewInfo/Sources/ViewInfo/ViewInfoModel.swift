import Foundation

/// Where something was found in the source.
struct SourceRef {
    let file: String
    let line: Int

    /// "main.swift:1706"
    var description: String { "\(file):\(line)" }
}

/// A property assigned on an object: `stepper.minValue = 0`.
struct PropertyAssignment {
    let name: String
    let value: String
    let ref: SourceRef
}

/// A configuration call made on an object: `stepper.setContentHuggingPriority(...)`.
struct ConfigurationCall {
    let name: String
    let arguments: String
    let ref: SourceRef
}

/// How an action is attached to a control.
enum ActionKind {
    /// A framework convenience closure: `control.onAction = { ... }`.
    case closure(property: String)
    /// Classic target/action: `control.action = #selector(foo)`.
    case selector(name: String)

    var label: String {
        switch self {
        case let .closure(property):
            return property
        case let .selector(name):
            return "#selector(\(name))"
        }
    }
}

/// An action attached to a control, with its body and what that body touches.
struct ActionInfo {
    let kind: ActionKind
    let ref: SourceRef

    /// The action's source, ready to drop in a fenced code block.
    let code: String

    /// Names of other declared objects referenced inside the action body.
    var accesses: [String] = []

    /// For selector actions, the target expression (`control.target = self`).
    var target: String?
}

/// A declared object — typically a view or control — and everything the source
/// does to it.
struct ObjectInfo {
    let name: String
    let type: String
    let ref: SourceRef

    /// The initializer expression, e.g. `NSStepper(frame: NSMakeRect(...))`.
    let initializer: String?

    /// Whether the declared type looks like a view/control rather than a plain
    /// value. Used to split the report into views and supporting objects.
    let isView: Bool

    var properties: [PropertyAssignment] = []
    var configurationCalls: [ConfigurationCall] = []
    var actions: [ActionInfo] = []

    /// The object this one was added to, e.g. via `contentView.addSubview(x)`.
    var addedTo: (parent: String, ref: SourceRef)?

    /// Children added to this object, in source order.
    var children: [String] = []
}

/// A free function that is wired up as a target/action selector.
struct ActionMethod {
    let name: String
    let signature: String
    let ref: SourceRef
    let code: String
    var accesses: [String] = []

    /// Controls whose `action` referenced this method.
    var wiredFrom: [String] = []
}

/// Everything ViewInfo found across the parsed files.
struct SourceReport {
    var files: [String] = []
    var objects: [ObjectInfo] = []
    var actionMethods: [ActionMethod] = []

    /// Objects that look like views/controls, in declaration order.
    var views: [ObjectInfo] { objects.filter(\.isView) }

    /// Views with at least one action attached.
    var viewsWithActions: [ObjectInfo] { views.filter { !$0.actions.isEmpty } }
}

/// Decides whether a declared type is a view/control worth reporting as UI.
enum ViewTypeHeuristic {
    private static let suffixes = [
        "View", "Control", "Button", "Field", "Slider", "Stepper", "Scroller",
        "Indicator", "Picker", "Box", "Well", "Menu", "MenuItem", "Window",
        "Toolbar", "ToolbarItem", "Cell", "Label", "Panel", "Alert", "Splitter"
    ]

    /// AppKit-shaped names (`NS…`) and anything whose name ends in a UI suffix.
    static func isView(type: String) -> Bool {
        let bare = type.trimmingCharacters(in: CharacterSet(charactersIn: "?!"))
        if bare.hasPrefix("NS") {
            return true
        }
        return suffixes.contains { bare.hasSuffix($0) }
    }
}


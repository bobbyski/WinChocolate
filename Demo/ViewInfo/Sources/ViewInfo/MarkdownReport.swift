import Foundation

/// Renders a ``SourceReport`` as markdown on stdout.
///
/// The shape is deliberately diff-friendly: one section per view, a table of the
/// properties it sets, then each action as a fenced code block followed by the
/// other controls that action touches. Run it against two implementations and
/// diff the output to spot a missing property, control, or action.
struct MarkdownReport {
    let report: SourceReport

    func render() -> String {
        var out: [String] = []
        out.append(header())
        out.append(hierarchySection())
        out.append(viewsSection())
        out.append(actionMethodsSection())
        out.append(supportingObjectsSection())
        return out.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: - Sections

    private func header() -> String {
        let views = report.views
        let propertyCount = views.reduce(0) { $0 + $1.properties.count }
        let actionCount = views.reduce(0) { $0 + $1.actions.count }

        return """
        # ViewInfo

        **Source:** \(report.files.joined(separator: ", "))

        | Metric | Count |
        |---|---:|
        | Views / controls | \(views.count) |
        | Properties set | \(propertyCount) |
        | Actions attached | \(actionCount) |
        | `@objc` action methods | \(report.actionMethods.count) |
        | Other declared objects | \(report.objects.count - views.count) |

        """
    }

    private func hierarchySection() -> String {
        let roots = report.views.filter { $0.addedTo == nil && !$0.children.isEmpty }
        guard !roots.isEmpty else {
            return ""
        }

        var lines = ["## View hierarchy", ""]
        for root in roots {
            appendTree(root.name, depth: 0, into: &lines, seen: [])
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func appendTree(_ name: String, depth: Int, into lines: inout [String], seen: Set<String>) {
        guard !seen.contains(name), let object = object(named: name) else {
            return
        }
        let indent = String(repeating: "  ", count: depth)
        lines.append("\(indent)- `\(object.name)` — \(object.type)")
        var nextSeen = seen
        nextSeen.insert(name)
        for child in object.children {
            appendTree(child, depth: depth + 1, into: &lines, seen: nextSeen)
        }
    }

    private func viewsSection() -> String {
        let views = report.views
        guard !views.isEmpty else {
            return ""
        }

        var lines = ["## Views & controls", ""]
        for view in views {
            lines.append(contentsOf: renderView(view))
        }
        return lines.joined(separator: "\n")
    }

    private func renderView(_ view: ObjectInfo) -> [String] {
        var lines: [String] = []
        lines.append("### `\(view.name)` — \(view.type)")
        lines.append("")
        lines.append("- **Declared:** \(view.ref.description)")
        if let initializer = view.initializer {
            lines.append("- **Init:** `\(singleLine(initializer))`")
        }
        if let addedTo = view.addedTo {
            lines.append("- **Added to:** `\(addedTo.parent)` (\(addedTo.ref.description))")
        }
        if !view.children.isEmpty {
            lines.append("- **Children:** \(view.children.map { "`\($0)`" }.joined(separator: ", "))")
        }
        lines.append("")

        if view.properties.isEmpty {
            lines.append("_No properties set._")
            lines.append("")
        } else {
            lines.append("#### Properties (\(view.properties.count))")
            lines.append("")
            lines.append("| Property | Value | Line |")
            lines.append("|---|---|---:|")
            for property in view.properties {
                lines.append("| `\(property.name)` | `\(escape(singleLine(property.value)))` | \(property.ref.line) |")
            }
            lines.append("")
        }

        if !view.configurationCalls.isEmpty {
            lines.append("#### Configuration calls (\(view.configurationCalls.count))")
            lines.append("")
            lines.append("| Call | Arguments | Line |")
            lines.append("|---|---|---:|")
            for call in view.configurationCalls {
                lines.append("| `\(call.name)` | `\(escape(singleLine(call.arguments)))` | \(call.ref.line) |")
            }
            lines.append("")
        }

        if !view.actions.isEmpty {
            lines.append("#### Actions (\(view.actions.count))")
            lines.append("")
            for action in view.actions {
                lines.append(contentsOf: renderAction(action, owner: view.name))
            }
        }

        return lines
    }

    private func renderAction(_ action: ActionInfo, owner: String) -> [String] {
        var lines: [String] = []
        lines.append("##### `\(owner).\(action.kind.label)` — \(action.ref.description)")
        if let target = action.target {
            lines.append("")
            lines.append("- **Target:** `\(target)`")
        }
        lines.append("")
        lines.append("```swift")
        lines.append(action.code)
        lines.append("```")
        lines.append("")
        lines.append(accessLine(action.accesses))
        lines.append("")
        return lines
    }

    private func actionMethodsSection() -> String {
        guard !report.actionMethods.isEmpty else {
            return ""
        }

        var lines = ["## `@objc` action methods", ""]
        for method in report.actionMethods {
            lines.append("### `\(method.signature)` — \(method.ref.description)")
            lines.append("")
            if !method.wiredFrom.isEmpty {
                lines.append("- **Wired from:** \(method.wiredFrom.map { "`\($0).action`" }.joined(separator: ", "))")
                lines.append("")
            }
            lines.append("```swift")
            lines.append(method.code)
            lines.append("```")
            lines.append("")
            lines.append(accessLine(method.accesses))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func supportingObjectsSection() -> String {
        let others = report.objects.filter { !$0.isView }
        guard !others.isEmpty else {
            return ""
        }

        var lines = ["## Other declared objects", ""]
        lines.append("| Name | Type | Properties | Line |")
        lines.append("|---|---|---:|---:|")
        for object in others {
            lines.append("| `\(object.name)` | \(object.type) | \(object.properties.count) | \(object.ref.line) |")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// The views/controls an action touches — the whole point of the report.
    private func accessLine(_ accesses: [String]) -> String {
        guard !accesses.isEmpty else {
            return "**Accesses:** _none_"
        }
        return "**Accesses:** " + accesses.map { name -> String in
            guard let object = object(named: name) else {
                return "`\(name)`"
            }
            return "`\(name)` (\(object.type))"
        }.joined(separator: ", ")
    }

    private func object(named name: String) -> ObjectInfo? {
        report.objects.first { $0.name == name }
    }

    private func singleLine(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
    }
}


import Foundation
import SwiftOperators
import SwiftParser
import SwiftSyntax

/// Walks parsed Swift and records declared objects, the properties set on them,
/// the actions attached to them, and what those actions touch.
///
/// ```text
/// let stepper = NSStepper(frame: ...)   -> ObjectInfo(name: "stepper", type: "NSStepper")
/// stepper.minValue = 0                  -> PropertyAssignment
/// stepper.onAction = { ... }            -> ActionInfo(.closure)
/// contentView.addSubview(stepper)       -> parent/child link
/// ```
///
/// Collection runs first across every file; `accesses` are resolved afterwards,
/// once all object names are known, so actions can reference views declared in
/// another file.
final class SourceCollector {
    private var report = SourceReport()
    private var objectIndex: [String: Int] = [:]

    /// Pending action bodies to resolve once every name is known.
    private struct PendingBody {
        let owner: String?
        let methodName: String?
        let node: Syntax
        let ignoring: Set<String>
    }
    private var pendingBodies: [PendingBody] = []

    /// Parses a file and folds its contents into the report.
    func add(file path: String) throws {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let name = (path as NSString).lastPathComponent
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: name, tree: tree)
        report.files.append(name)

        // SwiftParser leaves infix expressions as flat `SequenceExpr`s, so
        // `slider.minValue = 0` is only recognizable as an assignment after
        // operator folding. Folding preserves source positions, so the
        // converter built from the original tree still resolves line numbers.
        let folded = OperatorTable.standardOperators.foldAll(tree) { _ in }

        let visitor = DeclarationVisitor(file: name, converter: converter, collector: self)
        visitor.walk(folded)
    }

    /// Resolves cross-references and returns the finished report.
    func finish() -> SourceReport {
        let known = Set(objectIndex.keys)

        for pending in pendingBodies {
            let identifiers = IdentifierVisitor.identifiers(in: pending.node)
            let accesses = identifiers
                .filter { known.contains($0) }
                .filter { !pending.ignoring.contains($0) }
                .sorted()

            if let owner = pending.owner, let index = objectIndex[owner],
               var action = report.objects[index].actions.last {
                action.accesses = accesses.filter { $0 != owner }
                report.objects[index].actions[report.objects[index].actions.count - 1] = action
            } else if let methodName = pending.methodName,
                      let index = report.actionMethods.firstIndex(where: { $0.name == methodName }) {
                report.actionMethods[index].accesses = accesses
            }
        }

        return report
    }

    // MARK: - Recording

    func record(object: ObjectInfo) {
        guard objectIndex[object.name] == nil else {
            return // first declaration wins; shadowed locals are not the UI
        }
        objectIndex[object.name] = report.objects.count
        report.objects.append(object)
    }

    func record(property: PropertyAssignment, on owner: String) {
        guard let index = objectIndex[owner] else {
            return
        }
        report.objects[index].properties.append(property)
    }

    func record(call: ConfigurationCall, on owner: String) {
        guard let index = objectIndex[owner] else {
            return
        }
        report.objects[index].configurationCalls.append(call)
    }

    func record(action: ActionInfo, on owner: String, body: Syntax?, ignoring: Set<String>) {
        guard let index = objectIndex[owner] else {
            return
        }
        report.objects[index].actions.append(action)
        if let body {
            pendingBodies.append(PendingBody(owner: owner, methodName: nil, node: body, ignoring: ignoring))
        }
    }

    func record(target: String, on owner: String) {
        guard let index = objectIndex[owner], !report.objects[index].actions.isEmpty else {
            return
        }
        let last = report.objects[index].actions.count - 1
        report.objects[index].actions[last].target = target
    }

    func record(method: ActionMethod, body: Syntax?) {
        guard !report.actionMethods.contains(where: { $0.name == method.name }) else {
            return
        }
        report.actionMethods.append(method)
        if let body {
            pendingBodies.append(PendingBody(owner: nil, methodName: method.name, node: body, ignoring: []))
        }
    }

    func recordSelectorWiring(method: String, from owner: String) {
        guard let index = report.actionMethods.firstIndex(where: { $0.name == method }) else {
            return
        }
        if !report.actionMethods[index].wiredFrom.contains(owner) {
            report.actionMethods[index].wiredFrom.append(owner)
        }
    }

    func recordHierarchy(parent: String, child: String, ref: SourceRef) {
        if let childIndex = objectIndex[child] {
            report.objects[childIndex].addedTo = (parent, ref)
        }
        if let parentIndex = objectIndex[parent], !report.objects[parentIndex].children.contains(child) {
            report.objects[parentIndex].children.append(child)
        }
    }

    func isKnown(_ name: String) -> Bool {
        objectIndex[name] != nil
    }
}

/// Collects every identifier referenced inside a syntax node.
private final class IdentifierVisitor: SyntaxVisitor {
    private var found: Set<String> = []

    static func identifiers(in node: Syntax) -> Set<String> {
        let visitor = IdentifierVisitor(viewMode: .sourceAccurate)
        visitor.walk(node)
        return visitor.found
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        found.insert(node.baseName.text)
        return .visitChildren
    }
}

/// The main walk: declarations, assignments, calls, and `@objc` methods.
private final class DeclarationVisitor: SyntaxVisitor {
    private let file: String
    private let converter: SourceLocationConverter
    private unowned let collector: SourceCollector

    /// Property names that attach a closure action in this codebase.
    private static let closureActionProperties: Set<String> = ["onAction", "onChange", "onClick"]

    init(file: String, converter: SourceLocationConverter, collector: SourceCollector) {
        self.file = file
        self.converter = converter
        self.collector = collector
        super.init(viewMode: .sourceAccurate)
    }

    private func ref(_ node: some SyntaxProtocol) -> SourceRef {
        SourceRef(file: file, line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line)
    }

    // MARK: Declarations

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            let name = pattern.identifier.text
            let initializer = binding.initializer?.value
            let annotated = binding.typeAnnotation?.type.trimmedDescription
            let inferred = initializer.flatMap(Self.constructedTypeName)
            guard let type = annotated ?? inferred else {
                continue
            }

            collector.record(object: ObjectInfo(
                name: name,
                type: type,
                ref: ref(node),
                initializer: initializer?.trimmedDescription,
                isView: ViewTypeHeuristic.isView(type: type)
            ))
        }
        return .visitChildren
    }

    /// The type name from a constructor call, e.g. `NSStepper(frame:)` -> NSStepper.
    private static func constructedTypeName(_ expr: ExprSyntax) -> String? {
        guard let call = expr.as(FunctionCallExprSyntax.self) else {
            return nil
        }
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            return name.first?.isUppercase == true ? name : nil
        }
        return nil
    }

    // MARK: Assignments

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.operator.is(AssignmentExprSyntax.self),
              let member = node.leftOperand.as(MemberAccessExprSyntax.self),
              let base = member.base?.as(DeclReferenceExprSyntax.self) else {
            return .visitChildren
        }

        let owner = base.baseName.text
        guard collector.isKnown(owner) else {
            return .visitChildren
        }
        let property = member.declName.baseName.text
        let value = node.rightOperand.trimmedDescription
        let location = ref(node)

        if Self.closureActionProperties.contains(property),
           let closure = node.rightOperand.as(ClosureExprSyntax.self) {
            collector.record(
                action: ActionInfo(kind: .closure(property: property), ref: location, code: closure.trimmedDescription),
                on: owner,
                body: Syntax(closure.statements),
                ignoring: Self.closureParameterNames(closure)
            )
            return .skipChildren
        }

        if property == "action", let selector = Self.selectorName(node.rightOperand) {
            collector.record(
                action: ActionInfo(kind: .selector(name: selector), ref: location, code: value),
                on: owner,
                body: nil,
                ignoring: []
            )
            collector.recordSelectorWiring(method: selector, from: owner)
            return .skipChildren
        }

        if property == "target" {
            collector.record(target: value, on: owner)
            return .skipChildren
        }

        collector.record(property: PropertyAssignment(name: property, value: value, ref: location), on: owner)
        return .visitChildren
    }

    /// The bare method name inside `#selector(foo(_:))`.
    private static func selectorName(_ expr: ExprSyntax) -> String? {
        let text = expr.trimmedDescription
        guard text.hasPrefix("#selector(") else {
            return nil
        }
        let inner = text.dropFirst("#selector(".count).dropLast()
        let head = inner.split(separator: "(").first.map(String.init) ?? String(inner)
        return head.split(separator: ".").last.map(String.init)
    }

    private static func closureParameterNames(_ closure: ClosureExprSyntax) -> Set<String> {
        guard let signature = closure.signature else {
            return []
        }
        switch signature.parameterClause {
        case let .simpleInput(list):
            return Set(list.map(\.name.text))
        case let .parameterClause(clause):
            return Set(clause.parameters.map { $0.secondName?.text ?? $0.firstName.text })
        case .none:
            return []
        }
    }

    // MARK: Calls

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
              let base = member.base?.as(DeclReferenceExprSyntax.self) else {
            return .visitChildren
        }
        let owner = base.baseName.text
        guard collector.isKnown(owner) else {
            return .visitChildren
        }
        let method = member.declName.baseName.text

        if method == "addSubview" || method == "addArrangedSubview" || method == "addItem",
           let first = node.arguments.first?.expression.as(DeclReferenceExprSyntax.self) {
            collector.recordHierarchy(parent: owner, child: first.baseName.text, ref: ref(node))
            return .visitChildren
        }

        // Configuration calls read like properties (setX / configure / add…).
        if method.hasPrefix("set") || method.hasPrefix("add") || method.hasPrefix("insert") {
            let arguments = node.arguments.map(\.trimmedDescription).joined(separator: ", ")
            collector.record(call: ConfigurationCall(name: method, arguments: arguments, ref: ref(node)), on: owner)
        }
        return .visitChildren
    }

    // MARK: Action methods

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let isObjC = node.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "objc"
        }
        guard isObjC else {
            return .visitChildren
        }

        let name = node.name.text
        let code = node.trimmedDescription
        collector.record(
            method: ActionMethod(
                name: name,
                signature: "\(name)\(node.signature.trimmedDescription)",
                ref: ref(node),
                code: code
            ),
            body: node.body.map { Syntax($0.statements) }
        )
        return .visitChildren
    }
}


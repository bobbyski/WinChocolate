// WinNibDecoder.swift
// Instantiates a parsed `.xib` document into WinChocolate objects (plan 15.2),
// decodes constraint elements through the Phase 9 solver types (15.3), and
// resolves outlet/action connection records (15.4 first slice).
//
// Coordinates: xib frames are authored in AppKit's bottom-up space (a
// non-flipped superview), while WinChocolate lays out top-down. Each child's
// y is flipped against its parent's height at build time, so a xib authored
// on a Mac lands visually identical. Auto Layout attributes need no flip —
// `top`/`bottom` are visual, not coordinate-space, in both worlds.

/// A stand-in for a xib `customObject` whose `customClass` cannot be
/// instantiated without a reflection runtime: it keeps the graph's ids
/// resolvable and tells the app which class the document asked for.
public final class WinNibCustomObject: NSObject {
    /// The `customClass` the xib named, e.g. a view controller subclass.
    public let customClassName: String
    /// The Interface Builder user label, when present.
    public let userLabel: String?

    init(customClassName: String, userLabel: String?) {
        self.customClassName = customClassName
        self.userLabel = userLabel
    }
}

/// Builds the object graph for one nib instantiation.
final class WinNibDecoder {
    private let owner: AnyObject?
    private var objectsByID: [String: AnyObject] = [:]
    private var connections: [WinNibConnection] = []

    // Constraint elements wait until the whole graph exists so cross-view
    // item references resolve; each remembers the view that owned the
    // <constraints> block (the default firstItem).
    private var pendingConstraints: [(ownerView: NSView, element: WinXMLElement)] = []
    // Connection elements likewise resolve after every id is registered.
    private var pendingConnections: [(source: AnyObject, element: WinXMLElement)] = []

    init(owner: Any?) {
        self.owner = owner as AnyObject?
    }

    func decode(_ document: WinXMLElement) -> WinNibInstance? {
        guard let objects = document.firstChild(named: "objects") else {
            return nil
        }

        var topLevelObjects: [Any] = []
        for element in objects.children {
            switch element.name {
            case "customObject":
                decodePlaceholder(element)
            case "window":
                if let window = buildWindow(element) {
                    topLevelObjects.append(window)
                }
            case "menu", "dependencies":
                // Main-menu documents and tool metadata are out of the first
                // slice; skip without failing the load.
                continue
            default:
                if let view = buildView(element, parentHeight: nil) {
                    topLevelObjects.append(view)
                }
            }
        }

        resolvePendingConstraints()
        resolvePendingConnections()
        return WinNibInstance(
            topLevelObjects: topLevelObjects,
            objectsByID: objectsByID,
            connections: connections
        )
    }

    // MARK: Placeholders

    private func decodePlaceholder(_ element: WinXMLElement) {
        let id = element.attribute("id") ?? ""
        switch id {
        case "-2":
            // File's Owner: the instantiate owner stands in.
            if let owner {
                objectsByID[id] = owner
            }
        case "-1", "-3":
            // First Responder / Application placeholders resolve to nothing.
            break
        default:
            let stand = WinNibCustomObject(
                customClassName: element.attribute("customClass") ?? "NSObject",
                userLabel: element.attribute("userLabel")
            )
            objectsByID[id] = stand
        }
        if let connectionsElement = element.firstChild(named: "connections") {
            let source: AnyObject? = objectsByID[id]
            if let source {
                pendingConnections.append((source, connectionsElement))
            }
        }
    }

    // MARK: Windows

    private func buildWindow(_ element: WinXMLElement) -> NSWindow? {
        let contentRect = rect(from: element.firstChild(withKey: "contentRect"))
            ?? NSMakeRect(100, 100, 480, 300)

        var styleMask: NSWindow.StyleMask = []
        if let styleElement = element.firstChild(withKey: "styleMask") {
            if bool(styleElement.attribute("titled")) { styleMask.insert(.titled) }
            if bool(styleElement.attribute("closable")) { styleMask.insert(.closable) }
            if bool(styleElement.attribute("miniaturizable")) { styleMask.insert(.miniaturizable) }
            if bool(styleElement.attribute("resizable")) { styleMask.insert(.resizable) }
        } else {
            styleMask = [.titled, .closable, .miniaturizable, .resizable]
        }

        let window = NSWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: true)
        window.title = element.attribute("title") ?? ""

        if let contentElement = element.firstChild(withKey: "contentView"),
           let contentView = buildView(contentElement, parentHeight: nil) {
            window.contentView = contentView
        }

        register(element, as: window)
        return window
    }

    // MARK: Views and controls

    private func buildView(_ element: WinXMLElement, parentHeight: CGFloat?) -> NSView? {
        // A view's own frame: xib y is bottom-up within its parent, so flip
        // against the parent height once both are known. Top-level frames
        // stay as authored.
        let cocoaFrame = rect(from: element.firstChild(withKey: "frame")) ?? NSZeroRect
        var frame = cocoaFrame
        if let parentHeight {
            frame.origin.y = parentHeight - cocoaFrame.origin.y - cocoaFrame.size.height
        }

        guard let view = instantiateView(element, frame: frame) else {
            return nil
        }

        applyCommonAttributes(element, to: view)
        register(element, as: view)

        if let subviews = element.firstChild(named: "subviews") {
            for childElement in subviews.children {
                if let child = buildView(childElement, parentHeight: frame.size.height) {
                    view.addSubview(child)
                }
            }
        }

        if let constraintsElement = element.firstChild(named: "constraints") {
            pendingConstraints.append((view, constraintsElement))
        }
        if let connectionsElement = element.firstChild(named: "connections") {
            pendingConnections.append((view, connectionsElement))
        }
        return view
    }

    private func instantiateView(_ element: WinXMLElement, frame: NSRect) -> NSView? {
        switch element.name {
        case "button": return instantiateButton(element, frame: frame)
        case "textField": return instantiateTextField(element, frame: frame)
        case "slider": return instantiateSlider(element, frame: frame)
        case "popUpButton": return instantiatePopUpButton(element, frame: frame)
        case "comboBox": return instantiateComboBox(element, frame: frame)
        default:
            return instantiateContainerOrDisplayView(element, frame: frame)
        }
    }

    private func instantiateButton(_ element: WinXMLElement, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        guard let cell = element.firstChild(withKey: "cell") else { return button }
        switch cell.attribute("type") {
        case "check": button.setButtonType(.switch)
        case "radio": button.setButtonType(.radio)
        default: button.setButtonType(.momentaryPushIn)
        }
        button.title = cell.attribute("title") ?? ""
        if cell.attribute("state") == "on" { button.state = .on }
        if !bool(cell.attribute("enabled"), default: true) { button.isEnabled = false }
        return button
    }

    private func instantiateTextField(_ element: WinXMLElement, frame: NSRect) -> NSTextField {
        let field = NSTextField(frame: frame)
        guard let cell = element.firstChild(withKey: "cell") else { return field }
        field.stringValue = cell.attribute("title") ?? ""
        field.placeholderString = cell.attribute("placeholderString")
        field.isEditable = bool(cell.attribute("editable"))
        field.isSelectable = bool(cell.attribute("selectable"))
        let borderStyle = cell.attribute("borderStyle")
        field.isBordered = borderStyle != nil
        field.isBezeled = borderStyle == "bezel"
        field.drawsBackground = bool(cell.attribute("drawsBackground"))
        return field
    }

    private func instantiateSlider(_ element: WinXMLElement, frame: NSRect) -> NSSlider {
        let slider = NSSlider(frame: frame)
        guard let cell = element.firstChild(withKey: "cell") else { return slider }
        slider.minValue = double(cell.attribute("minValue")) ?? 0
        slider.maxValue = double(cell.attribute("maxValue")) ?? 100
        slider.doubleValue = double(cell.attribute("doubleValue")) ?? slider.minValue
        slider.isContinuous = bool(cell.attribute("continuous"))
        slider.isVertical = frame.size.height > frame.size.width
        return slider
    }

    private func instantiatePopUpButton(_ element: WinXMLElement, frame: NSRect) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: frame)
        guard let cell = element.firstChild(withKey: "cell"),
              let menu = cell.firstChild(withKey: "menu") ?? cell.firstChild(named: "menu"),
              let items = menu.firstChild(named: "items") else { return popup }
        var selectedTitle: String?
        for item in items.children(named: "menuItem") {
            let title = item.attribute("title") ?? ""
            popup.addItem(withTitle: title)
            if item.attribute("state") == "on" || item.attribute("id") == cell.attribute("selectedItem") {
                selectedTitle = title
            }
        }
        if let selectedTitle { popup.selectItem(withTitle: selectedTitle) }
        return popup
    }

    private func instantiateComboBox(_ element: WinXMLElement, frame: NSRect) -> NSComboBox {
        let combo = NSComboBox(frame: frame)
        combo.stringValue = element.firstChild(withKey: "cell")?.attribute("title") ?? ""
        return combo
    }

    private func instantiateContainerOrDisplayView(_ element: WinXMLElement, frame: NSRect) -> NSView {
        switch element.name {
        case "imageView":
            let imageView = NSImageView(frame: frame)
            if let imageName = element.firstChild(withKey: "cell")?.attribute("image") {
                imageView.image = NSImage(named: imageName)
            }
            return imageView
        case "progressIndicator":
            return instantiateProgressIndicator(element, frame: frame)
        case "box":
            return NSBox(title: element.attribute("title") ?? "", frame: frame)
        case "scrollView":
            return instantiateScrollView(element, frame: frame)
        default:
            return NSView(frame: frame)
        }
    }

    private func instantiateProgressIndicator(_ element: WinXMLElement, frame: NSRect) -> NSProgressIndicator {
        let indicator = NSProgressIndicator(frame: frame)
        indicator.minValue = double(element.attribute("minValue")) ?? 0
        indicator.maxValue = double(element.attribute("maxValue")) ?? 100
        indicator.isIndeterminate = bool(element.attribute("indeterminate"))
        if let value = double(element.attribute("doubleValue")) { indicator.doubleValue = value }
        return indicator
    }

    private func instantiateScrollView(_ element: WinXMLElement, frame: NSRect) -> NSScrollView {
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = bool(element.attribute("hasVerticalScroller"), default: true)
        scrollView.hasHorizontalScroller = bool(element.attribute("hasHorizontalScroller"))
        if let clip = element.firstChild(withKey: "contentView"),
           let documentElement = clip.firstChild(named: "subviews")?.children.first,
           let documentView = buildView(documentElement, parentHeight: nil) {
            scrollView.documentView = documentView
        }
        return scrollView
    }

    // MARK: Constraints (15.3)

    private func resolvePendingConstraints() {
        var decoded: [NSLayoutConstraint] = []
        for (ownerView, constraintsElement) in pendingConstraints {
            for element in constraintsElement.children(named: "constraint") {
                guard let firstAttribute = attribute(named: element.attribute("firstAttribute")) else {
                    continue
                }
                // A missing firstItem means the owning view constrains itself
                // (e.g. a bare width constraint).
                let firstItem: NSView? = element.attribute("firstItem")
                    .flatMap { objectsByID[$0] as? NSView } ?? ownerView
                let secondItem = element.attribute("secondItem").flatMap { objectsByID[$0] as? NSView }
                let secondAttribute = attribute(named: element.attribute("secondAttribute")) ?? .notAnAttribute

                let relation: NSLayoutConstraint.Relation
                switch element.attribute("relation") {
                case "greaterThanOrEqual": relation = .greaterThanOrEqual
                case "lessThanOrEqual": relation = .lessThanOrEqual
                default: relation = .equal
                }

                let constraint = NSLayoutConstraint(
                    item: firstItem as Any,
                    attribute: firstAttribute,
                    relatedBy: relation,
                    toItem: secondItem,
                    attribute: secondAttribute,
                    multiplier: multiplier(from: element.attribute("multiplier")),
                    constant: CGFloat(double(element.attribute("constant")) ?? 0)
                )
                if let priority = double(element.attribute("priority")) {
                    constraint.priority = NSLayoutConstraint.Priority(Float(priority))
                }
                constraint.identifier = element.attribute("identifier")
                register(element, as: constraint)
                decoded.append(constraint)
            }
        }
        // Activate as AppKit does on load; the Phase 9 solver applies them on
        // the next layout pass.
        NSLayoutConstraint.activate(decoded)
    }

}

private extension WinNibDecoder {
    static let constraintAttributes: [String: NSLayoutConstraint.Attribute] = [
        "left": .left, "right": .right, "top": .top, "bottom": .bottom,
        "leading": .leading, "trailing": .trailing,
        "width": .width, "height": .height,
        "centerX": .centerX, "centerY": .centerY,
        "baseline": .lastBaseline, "lastBaseline": .lastBaseline,
        "firstBaseline": .firstBaseline
    ]

    func applyCommonAttributes(_ element: WinXMLElement, to view: NSView) {
        if let identifier = element.attribute("identifier") {
            view.identifier = NSUserInterfaceItemIdentifier(identifier)
        }
        if bool(element.attribute("hidden")) { view.isHidden = true }
        if let tag = element.attribute("tag").flatMap({ Int($0) }) { view.tag = tag }
        if element.attribute("translatesAutoresizingMaskIntoConstraints") == "NO" {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        if let control = view as? NSControl, !bool(element.attribute("enabled"), default: true) {
            control.isEnabled = false
        }
        if let toolTip = element.attribute("toolTip") { view.toolTip = toolTip }
        if let maskElement = element.firstChild(withKey: "autoresizingMask") {
            view.autoresizingMask = autoresizingMask(from: maskElement)
        }
    }

    func autoresizingMask(from element: WinXMLElement) -> NSView.AutoresizingMask {
        let mappings: [(String, NSView.AutoresizingMask)] = [
            ("widthSizable", .width), ("heightSizable", .height),
            ("flexibleMinX", .minXMargin), ("flexibleMaxX", .maxXMargin),
            ("flexibleMinY", .maxYMargin), ("flexibleMaxY", .minYMargin)
        ]
        return mappings.reduce(into: NSView.AutoresizingMask()) { mask, mapping in
            if bool(element.attribute(mapping.0)) { mask.insert(mapping.1) }
        }
    }

    func register(_ element: WinXMLElement, as object: AnyObject) {
        if let id = element.attribute("id") { objectsByID[id] = object }
    }

    func attribute(named name: String?) -> NSLayoutConstraint.Attribute? {
        name.flatMap { Self.constraintAttributes[$0] }
    }

    /// IB multipliers appear as plain numbers ("0.5") or ratios ("3:4").
    func multiplier(from text: String?) -> CGFloat {
        guard let text else { return 1 }
        if text.contains(":") {
            let parts = text.split(separator: ":")
            if parts.count == 2,
               let numerator = Double(parts[0]),
               let denominator = Double(parts[1]),
               denominator != 0 {
                return CGFloat(numerator / denominator)
            }
            return 1
        }
        return CGFloat(Double(text) ?? 1)
    }

    // MARK: Connections (15.4 first slice)

    func resolvePendingConnections() {
        for (source, connectionsElement) in pendingConnections {
            for element in connectionsElement.children {
                switch element.name {
                case "action":
                    guard let selector = element.attribute("selector") else { continue }
                    let target = element.attribute("target").flatMap { resolveReference($0) }
                    connections.append(WinNibConnection(
                        kind: .action, name: selector, source: source, destination: target
                    ))
                    // Controls get their target/action applied directly, so an
                    // owner using WinChocolate's Swift-native dispatch (or a
                    // future selector runtime) sees the wiring AppKit would set.
                    if let control = source as? NSControl {
                        control.target = target
                        control.action = Selector(selector)
                    }
                case "outlet":
                    guard let property = element.attribute("property") else { continue }
                    let destination = element.attribute("destination").flatMap { resolveReference($0) }
                    connections.append(WinNibConnection(
                        kind: .outlet, name: property, source: source, destination: destination
                    ))
                default:
                    continue
                }
            }
        }
    }

    func resolveReference(_ id: String) -> AnyObject? {
        if id == "-2" { return owner }
        if id == "-1" || id == "-3" { return nil }
        return objectsByID[id]
    }

    // MARK: Attribute value helpers

    func rect(from element: WinXMLElement?) -> NSRect? {
        guard let element,
              let x = double(element.attribute("x")),
              let y = double(element.attribute("y")),
              let width = double(element.attribute("width")),
              let height = double(element.attribute("height")) else {
            return nil
        }
        return NSMakeRect(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height))
    }

    func double(_ text: String?) -> Double? {
        text.flatMap { Double($0) }
    }

    func bool(_ text: String?, default defaultValue: Bool = false) -> Bool {
        guard let text else { return defaultValue }
        return text == "YES"
    }
}

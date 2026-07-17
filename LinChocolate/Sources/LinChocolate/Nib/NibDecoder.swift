import Foundation

/// Instantiates a parsed `.xib` document into LinChocolate objects — the port of
/// WinChocolate's `WinNibDecoder`, adapted to LinChocolate's control constructors.
///
/// Coordinates: xib frames are authored in AppKit's bottom-up space (a
/// non-flipped superview), while a child is placed by its `frame.origin.y` from
/// the top once the shared demo opts into a top-left origin (`defaultIsFlipped`).
/// Each child's y is flipped against its parent's height at build time, so a xib
/// authored on a Mac lands visually identical.
final class NibDecoder {
    private let owner: AnyObject?
    private var objectsByID: [String: AnyObject] = [:]
    private var connections: [NibConnection] = []

    // Constraint / connection elements resolve after the whole graph exists, so
    // cross-view references (by id) are registered first.
    private var pendingConstraints: [(ownerView: NSView, element: NibXMLElement)] = []
    private var pendingConnections: [(source: AnyObject, element: NibXMLElement)] = []

    init(owner: Any?) {
        self.owner = owner as AnyObject?
    }

    func decode(_ document: NibXMLElement) -> NibInstance? {
        guard let objects = document.firstChild(named: "objects") else { return nil }

        var topLevelObjects: [Any] = []
        for element in objects.children {
            switch element.name {
            case "customObject":
                decodePlaceholder(element)
            case "window":
                if let window = buildWindow(element) { topLevelObjects.append(window) }
            case "menu", "dependencies":
                continue
            default:
                if let view = buildView(element, parentHeight: nil) { topLevelObjects.append(view) }
            }
        }

        resolvePendingConstraints()
        resolvePendingConnections()
        return NibInstance(
            topLevelObjects: topLevelObjects,
            objectsByID: objectsByID,
            connections: connections
        )
    }

    // MARK: Placeholders

    private func decodePlaceholder(_ element: NibXMLElement) {
        let id = element.attribute("id") ?? ""
        switch id {
        case "-2":
            if let owner { objectsByID[id] = owner }   // File's Owner
        case "-1", "-3":
            break                                        // First Responder / Application
        default:
            objectsByID[id] = NibCustomObject(
                customClassName: element.attribute("customClass") ?? "NSObject",
                userLabel: element.attribute("userLabel")
            )
        }
        if let connectionsElement = element.firstChild(named: "connections"),
           let source = objectsByID[id] {
            pendingConnections.append((source, connectionsElement))
        }
    }

    // MARK: Windows

    private func buildWindow(_ element: NibXMLElement) -> NSWindow? {
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

    private func buildView(_ element: NibXMLElement, parentHeight: CGFloat?) -> NSView? {
        let cocoaFrame = rect(from: element.firstChild(withKey: "frame")) ?? NSZeroRect
        var frame = cocoaFrame
        if let parentHeight {
            frame.origin.y = parentHeight - cocoaFrame.origin.y - cocoaFrame.size.height
        }

        guard let view = instantiateView(element, frame: frame) else { return nil }

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

    private func instantiateView(_ element: NibXMLElement, frame: NSRect) -> NSView? {
        let cell = element.firstChild(withKey: "cell")
        switch element.name {
        case "button":
            let button = NSButton(frame: frame)
            if let cell {
                switch cell.attribute("type") {
                case "check": button.setButtonType(.switchButton)
                case "radio": button.setButtonType(.radioButton)
                default: button.setButtonType(.momentaryPushIn)
                }
                button.title = cell.attribute("title") ?? ""
                if cell.attribute("state") == "on" { button.state = .on }
                if bool(cell.attribute("enabled"), default: true) == false { button.isEnabled = false }
            }
            return button

        case "textField":
            let field = NSTextField(frame: frame)
            if let cell {
                field.stringValue = cell.attribute("title") ?? ""
                field.placeholderString = cell.attribute("placeholderString")
                field.isEditable = bool(cell.attribute("editable"))
                field.isSelectable = bool(cell.attribute("selectable"))
                let borderStyle = cell.attribute("borderStyle")
                field.isBordered = borderStyle != nil
                field.isBezeled = borderStyle == "bezel"
                field.drawsBackground = bool(cell.attribute("drawsBackground"))
            }
            return field

        case "slider":
            let slider = NSSlider(frame: frame)
            if let cell {
                slider.minValue = double(cell.attribute("minValue")) ?? 0
                slider.maxValue = double(cell.attribute("maxValue")) ?? 100
                slider.doubleValue = double(cell.attribute("doubleValue")) ?? slider.minValue
                slider.isContinuous = bool(cell.attribute("continuous"))
                slider.isVertical = frame.size.height > frame.size.width
            }
            return slider

        case "popUpButton":
            let popup = NSPopUpButton(frame: frame)
            if let cell,
               let menu = cell.firstChild(withKey: "menu") ?? cell.firstChild(named: "menu"),
               let items = menu.firstChild(named: "items") {
                var selectedTitle: String?
                for item in items.children(named: "menuItem") {
                    let title = item.attribute("title") ?? ""
                    popup.addItem(withTitle: title)
                    if item.attribute("state") == "on" || item.attribute("id") == cell.attribute("selectedItem") {
                        selectedTitle = title
                    }
                }
                if let selectedTitle { popup.selectItem(withTitle: selectedTitle) }
            }
            return popup

        case "comboBox":
            let combo = NSComboBox(frame: frame)
            if let cell { combo.stringValue = cell.attribute("title") ?? "" }
            return combo

        case "imageView":
            let imageView = NSImageView(frame: frame)
            if let cell, let imageName = cell.attribute("image") {
                imageView.image = NSImage(named: imageName)
            }
            return imageView

        case "progressIndicator":
            let indicator = NSProgressIndicator(frame: frame)
            indicator.minValue = double(element.attribute("minValue")) ?? 0
            indicator.maxValue = double(element.attribute("maxValue")) ?? 100
            indicator.isIndeterminate = bool(element.attribute("indeterminate"))
            if let value = double(element.attribute("doubleValue")) { indicator.doubleValue = value }
            return indicator

        case "box":
            return NSBox(title: element.attribute("title") ?? "", frame: frame)

        case "scrollView":
            let scrollView = NSScrollView(frame: frame)
            scrollView.hasVerticalScroller = bool(element.attribute("hasVerticalScroller"), default: true)
            scrollView.hasHorizontalScroller = bool(element.attribute("hasHorizontalScroller"))
            if let clip = element.firstChild(withKey: "contentView"),
               let documentElement = clip.firstChild(named: "subviews")?.children.first,
               let documentView = buildView(documentElement, parentHeight: nil) {
                scrollView.documentView = documentView
            }
            return scrollView

        case "customView", "view":
            return NSView(frame: frame)

        default:
            // Unmapped IB classes degrade to a plain view of the right frame so
            // the rest of the document still loads.
            return NSView(frame: frame)
        }
    }

    private func applyCommonAttributes(_ element: NibXMLElement, to view: NSView) {
        if let identifier = element.attribute("identifier") {
            view.identifier = NSUserInterfaceItemIdentifier(identifier)
        }
        if bool(element.attribute("hidden")) {
            view.isHidden = true
        }
        if element.attribute("translatesAutoresizingMaskIntoConstraints") == "NO" {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        if let button = view as? NSButton, bool(element.attribute("enabled"), default: true) == false {
            button.isEnabled = false
        }
        if let toolTip = element.attribute("toolTip") {
            view.toolTip = toolTip
        }
    }

    private func register(_ element: NibXMLElement, as object: AnyObject) {
        if let id = element.attribute("id") { objectsByID[id] = object }
    }

    // MARK: Constraints

    private func resolvePendingConstraints() {
        var decoded: [NSLayoutConstraint] = []
        for (ownerView, constraintsElement) in pendingConstraints {
            for element in constraintsElement.children(named: "constraint") {
                guard let firstAttribute = attribute(named: element.attribute("firstAttribute")) else { continue }
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
                    item: firstItem,
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
                decoded.append(constraint)
            }
        }
        NSLayoutConstraint.activate(decoded)
    }

    private func attribute(named name: String?) -> NSLayoutConstraint.Attribute? {
        switch name {
        case "left": return .left
        case "right": return .right
        case "top": return .top
        case "bottom": return .bottom
        case "leading": return .leading
        case "trailing": return .trailing
        case "width": return .width
        case "height": return .height
        case "centerX": return .centerX
        case "centerY": return .centerY
        default: return nil    // baselines unsupported in this slice
        }
    }

    /// IB multipliers appear as plain numbers ("0.5") or ratios ("3:4").
    private func multiplier(from text: String?) -> CGFloat {
        guard let text else { return 1 }
        if text.contains(":") {
            let parts = text.split(separator: ":")
            if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                return CGFloat(n / d)
            }
            return 1
        }
        return CGFloat(Double(text) ?? 1)
    }

    // MARK: Connections

    private func resolvePendingConnections() {
        for (source, connectionsElement) in pendingConnections {
            for element in connectionsElement.children {
                switch element.name {
                case "action":
                    guard let selector = element.attribute("selector") else { continue }
                    let target = element.attribute("target").flatMap { resolveReference($0) }
                    connections.append(NibConnection(
                        kind: .action, name: selector, source: source, destination: target
                    ))
                    // Apply target/action directly so an owner sees the wiring
                    // AppKit would set (native dispatch stays on `onAction`).
                    if let button = source as? NSButton {
                        button.target = target
                        button.action = Selector(selector)
                    }
                case "outlet":
                    guard let property = element.attribute("property") else { continue }
                    let destination = element.attribute("destination").flatMap { resolveReference($0) }
                    connections.append(NibConnection(
                        kind: .outlet, name: property, source: source, destination: destination
                    ))
                default:
                    continue
                }
            }
        }
    }

    private func resolveReference(_ id: String) -> AnyObject? {
        if id == "-2" { return owner }
        if id == "-1" || id == "-3" { return nil }
        return objectsByID[id]
    }

    // MARK: Attribute value helpers

    private func rect(from element: NibXMLElement?) -> NSRect? {
        guard let element,
              let x = double(element.attribute("x")),
              let y = double(element.attribute("y")),
              let width = double(element.attribute("width")),
              let height = double(element.attribute("height")) else {
            return nil
        }
        return NSMakeRect(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height))
    }

    private func double(_ text: String?) -> Double? { text.flatMap { Double($0) } }

    private func bool(_ text: String?, default defaultValue: Bool = false) -> Bool {
        guard let text else { return defaultValue }
        return text == "YES"
    }
}

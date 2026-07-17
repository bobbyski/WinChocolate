// Demo-local convenience: loads DemoNibPanel and wires its controls — ONE
// implementation for all three targets, whose only `#if` is the import
// selection below (the demo's rule).
//
// The wiring model is identifier lookup, pure AppKit: every control in
// DemoNibPanel.xib carries an Identity-inspector identifier, the panel is
// instantiated through Apple's `NSNib` API with a nil owner, and the demo
// resolves each control by walking the instantiated view tree comparing
// `NSView.identifier` — the manual-wiring pattern AppKit apps use in place of
// outlets. No File's-Owner controller, no `@IBOutlet`/`@IBAction`, so nothing
// here needs the ObjC runtime and the same source compiles everywhere.
//
// (The xib still declares owner outlets/actions from its Interface Builder
// history; with a nil owner AppKit skips them — messages to nil — and the
// Chocolate readers resolve connections against a nil owner to nothing. The
// demo wires the same behaviors through `onAction` below instead.)

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor private var demoNibIncrementCount = 0

/// Depth-first search for the view carrying `name` as its Identity-inspector
/// identifier — the manual-wiring lookup, over Apple's exact
/// `NSUserInterfaceItemIdentifier` type on every target.
@MainActor
private func demoNibView(_ name: String, under root: NSView) -> NSView? {
    if root.identifier == NSUserInterfaceItemIdentifier(name) {
        return root
    }
    for subview in root.subviews {
        if let found = demoNibView(name, under: subview) {
            return found
        }
    }
    return nil
}

/// Loads `DemoNibPanel` into `nibPage` and wires its controls by identifier.
@MainActor
func installDemoNibPanel() {
    // AppKit instantiates only COMPILED nibs (run-mac.sh runs ibtool over the
    // xib); the Chocolate frameworks read the Interface Builder XML directly.
    // Same code path: take the compiled document when present, the source
    // document otherwise — a file-presence check, not a platform check.
    var nibPath = demoResourcePath(named: "DemoNibPanel", ofType: "nib")
    if !FileManager.default.fileExists(atPath: nibPath) {
        nibPath = demoResourcePath(named: "DemoNibPanel", ofType: "xib")
    }
    guard let nibData = try? Data(contentsOf: URL(fileURLWithPath: nibPath)) else {
        nibStatusLabel.stringValue = "DemoNibPanel not found at \(nibPath)."
        return
    }

    var topLevel: NSArray?
    let nib = NSNib(nibData: nibData, bundle: nil)
    guard nib.instantiate(withOwner: nil, topLevelObjects: &topLevel),
          let panel = (topLevel as? [Any])?.compactMap({ $0 as? NSView }).first else {
        nibStatusLabel.stringValue = "DemoNibPanel failed to instantiate."
        return
    }

    panel.frame = NSMakeRect(24, 52, panel.frame.size.width, panel.frame.size.height)
    nibPage.addSubview(panel)

    // The Increment button bumps the count label beside it.
    let countLabel = demoNibView("nibCountLabel", under: panel) as? NSTextField
    if let button = demoNibView("nibButton", under: panel) as? NSButton {
        button.onAction = { _ in
            demoNibIncrementCount += 1
            countLabel?.stringValue = "\(demoNibIncrementCount)"
            statusLabel.stringValue = "Nib button clicked (count \(demoNibIncrementCount)) — resolved by its xib identifier"
        }
    }

    if let slider = demoNibView("nibSlider", under: panel) as? NSSlider {
        slider.onAction = { control in
            statusLabel.stringValue = "Nib slider: \((control as? NSSlider)?.doubleValue ?? 0)"
        }
    }

    // Show Values reads the live controls back through the same identifier
    // lookups — edit the field, toggle the checkbox, drag the slider, then
    // show again.
    if let showButton = demoNibView("nibShowButton", under: panel) as? NSButton {
        showButton.onAction = { _ in
            let field = demoNibView("nibField", under: panel) as? NSTextField
            let check = demoNibView("nibCheck", under: panel) as? NSButton
            let slider = demoNibView("nibSlider", under: panel) as? NSSlider
            let popup = demoNibView("nibPopup", under: panel) as? NSPopUpButton
            let alert = NSAlert()
            alert.messageText = "Values read through xib identifiers"
            alert.informativeText = """
            nibField: "\(field?.stringValue ?? "?")"
            nibCheck: \(check?.state == .on ? "on" : "off")
            nibSlider: \(slider?.doubleValue ?? 0)
            nibPopup: \(popup?.titleOfSelectedItem ?? "?")
            nibCountLabel: \(countLabel?.stringValue ?? "?")

            All five controls were resolved by the identifiers the xib declares — the same lookup on every target.
            """
            _ = alert.runModal()
            statusLabel.stringValue = "Values popup shown — five controls resolved by xib identifier"
        }
    }

    let wired = ["nibButton", "nibShowButton", "nibSlider", "nibField", "nibCheck", "nibPopup", "nibCountLabel"]
        .filter { demoNibView($0, under: panel) != nil }
    nibStatusLabel.stringValue = "Instantiated \((topLevel as? [Any])?.count ?? 0) top-level object(s) from \(nibPath.hasSuffix("nib") ? "the compiled nib" : "the xib"); \(wired.count)/7 controls resolved by identifier: \(wired.joined(separator: ", "))"
}

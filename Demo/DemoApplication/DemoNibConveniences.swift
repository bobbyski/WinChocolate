// Demo-local convenience: loads DemoNibPanel and wires its controls, kept
// AppKit-compatible. On macOS it uses real @IBOutlet/@IBAction auto-binding via
// DemoNibPanelController, which the Objective-C runtime resolves during
// instantiate(withOwner:topLevelObjects:) — genuine standalone AppKit. On
// WinChocolate/LinChocolate, which have no ObjC runtime (so @IBOutlet/@IBAction
// cannot compile at all), the same wiring is read back from the xib's
// <outlet>/<action> connection records. The single AppKit-vs-Chocolate #if here
// is the sanctioned kind — the same basis as the action trampolines in
// DemoConveniences.swift — and the AppKit branch is genuine standalone Cocoa.

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(WinChocolate) || canImport(LinChocolate)

/// Stands in for the xib's `DemoNibPanelController` File's Owner: the xib's
/// `<outlet>` connections resolve against this object, and the demo reads the
/// controls back through those records (the 15.4 wiring model).
final class DemoNibOwner {}
@MainActor private let demoNibOwner = DemoNibOwner()
@MainActor private var demoNibIncrementCount = 0

/// Loads `DemoNibPanel.xib` into `nibPage` and wires its controls by reading the
/// xib's connection records — the Windows/Linux path, which has no ObjC runtime.
@MainActor
func installDemoNibPanel() {
    let xibPath = demoResourcePath(named: "DemoNibPanel", ofType: "xib")
    guard let xibData = try? Data(contentsOf: URL(fileURLWithPath: xibPath)) else {
        nibStatusLabel.stringValue = "DemoNibPanel.xib not found at \(xibPath)."
        return
    }
    let nib = NSNib(nibData: xibData)
    guard let instance = nib.winInstantiate(withOwner: demoNibOwner),
          let panel = instance.topLevelObjects.compactMap({ $0 as? NSView }).first else {
        nibStatusLabel.stringValue = "DemoNibPanel.xib failed to instantiate."
        return
    }
    panel.frame = NSMakeRect(24, 52, panel.frame.size.width, panel.frame.size.height)
    nibPage.addSubview(panel)

    // Manual outlet wiring through the xib identifiers.
    let countLabel = instance.view(withIdentifier: "nibCountLabel") as? NSTextField
    if let button = instance.view(withIdentifier: "nibButton") as? NSButton {
        button.onAction = { _ in
            demoNibIncrementCount += 1
            countLabel?.stringValue = "\(demoNibIncrementCount)"
            statusLabel.stringValue = "Nib button clicked (count \(demoNibIncrementCount)) — action \(button.action?.name ?? "?") wired from the xib"
        }
    }
    if let slider = instance.view(withIdentifier: "nibSlider") as? NSSlider {
        slider.onAction = { control in
            statusLabel.stringValue = "Nib slider: \((control as? NSSlider)?.doubleValue ?? 0)"
        }
    }

    // The Show Outlet Values button reads the live control values back through
    // the xib's <outlet> connections on File's Owner — the outlet half of the
    // wiring model (the Increment button proves the action half). No identifier
    // lookup here: every control below is resolved from the outlet records.
    let ownerOutlets = instance.connections.filter { $0.kind == .outlet && $0.source === demoNibOwner }
    func nibOutlet(_ property: String) -> AnyObject? {
        ownerOutlets.first { $0.name == property }?.destination
    }
    if let showButton = instance.view(withIdentifier: "nibShowButton") as? NSButton {
        showButton.onAction = { _ in
            let field = nibOutlet("nameField") as? NSTextField
            let check = nibOutlet("check") as? NSButton
            let slider = nibOutlet("slider") as? NSSlider
            let popup = nibOutlet("popup") as? NSPopUpButton
            let count = nibOutlet("countLabel") as? NSTextField
            let alert = NSAlert()
            alert.messageText = "Values read through xib outlets"
            alert.informativeText = """
            nameField: "\(field?.stringValue ?? "?")"
            check: \(check?.state == .on ? "on" : "off")
            slider: \(slider?.doubleValue ?? 0)
            popup: \(popup?.titleOfSelectedItem ?? "?")
            countLabel: \(count?.stringValue ?? "?")

            All five controls were resolved from the <outlet> connections the xib declares on File's Owner — edit the field, toggle the checkbox, drag the slider, then show again.
            """
            _ = alert.runModal()
            statusLabel.stringValue = "Outlet popup shown — \(ownerOutlets.count) outlets resolved from the xib"
        }
    }

    let actionWirings = instance.connections.filter { $0.kind == .action }
    nibStatusLabel.stringValue = "Instantiated \(instance.topLevelObjects.count) top-level object(s), \(instance.objectsByID.count) identified objects, \(actionWirings.count) action connection(s): \(actionWirings.map { $0.name }.joined(separator: ", ")); \(ownerOutlets.count) outlet(s) on File's Owner: \(ownerOutlets.map { $0.name }.joined(separator: ", "))"
}

#else

// macOS: Apple's automatic @IBOutlet/@IBAction binding. File's Owner in the xib
// is customClass="DemoNibPanelController" with five <outlet> connections and two
// <action>s; AppKit resolves every one through the Objective-C runtime during
// instantiate(withOwner:topLevelObjects:) — this class only has to declare them.
final class DemoNibPanelController: NSObject {
    @IBOutlet weak var nameField: NSTextField?
    @IBOutlet weak var check: NSButton?
    @IBOutlet weak var slider: NSSlider?
    @IBOutlet weak var popup: NSPopUpButton?
    @IBOutlet weak var countLabel: NSTextField?

    var increments = 0

    @IBAction func increment(_ sender: Any?) {
        increments += 1
        countLabel?.stringValue = "\(increments)"
        MainActor.assumeIsolated {
            statusLabel.stringValue = "Nib button clicked (count \(increments)) — action increment: wired from the xib"
        }
    }

    @IBAction func showValues(_ sender: Any?) {
        // Reads the live controls straight off the outlets AppKit bound — the
        // outlet half of the wiring model, exactly as the Windows/Linux branch
        // does through records.
        MainActor.assumeIsolated {
            let alert = NSAlert()
            alert.messageText = "Values read through xib outlets"
            alert.informativeText = """
            nameField: "\(nameField?.stringValue ?? "?")"
            check: \(check?.state == .on ? "on" : "off")
            slider: \(slider?.doubleValue ?? 0)
            popup: \(popup?.titleOfSelectedItem ?? "?")
            countLabel: \(countLabel?.stringValue ?? "?")

            All five controls were bound automatically from the <outlet> connections the xib declares on File's Owner — edit the field, toggle the checkbox, drag the slider, then show again.
            """
            _ = alert.runModal()
            statusLabel.stringValue = "Outlet popup shown — 5 outlets bound automatically by AppKit"
        }
    }
}

@MainActor private let demoNibOwner = DemoNibPanelController()

/// Loads the COMPILED `DemoNibPanel.nib` into `nibPage` and lets AppKit auto-bind
/// the controller's @IBOutlet/@IBAction connections.
@MainActor
func installDemoNibPanel() {
    // AppKit loads the COMPILED nib (run-mac.sh runs ibtool over the xib).
    let nibPath = demoResourcePath(named: "DemoNibPanel", ofType: "nib")
    guard let nibData = try? Data(contentsOf: URL(fileURLWithPath: nibPath)) else {
        nibStatusLabel.stringValue = "DemoNibPanel.nib not found at \(nibPath) — run-mac.sh compiles it from the xib with ibtool."
        return
    }
    var topLevel: NSArray?
    let nib = NSNib(nibData: nibData, bundle: nil)
    guard nib.instantiate(withOwner: demoNibOwner, topLevelObjects: &topLevel),
          let panel = (topLevel as? [Any])?.compactMap({ $0 as? NSView }).first else {
        nibStatusLabel.stringValue = "DemoNibPanel.nib failed to instantiate."
        return
    }
    panel.frame = NSMakeRect(24, 52, panel.frame.size.width, panel.frame.size.height)
    nibPage.addSubview(panel)
    let bound = [demoNibOwner.nameField, demoNibOwner.check, demoNibOwner.slider,
                 demoNibOwner.popup, demoNibOwner.countLabel].compactMap { $0 }.count
    nibStatusLabel.stringValue = "Instantiated \((topLevel as? [Any])?.count ?? 0) top-level object(s); \(bound)/5 outlets and 2 actions (increment:, showValues:) bound automatically by AppKit from the xib's connections."
}

#endif

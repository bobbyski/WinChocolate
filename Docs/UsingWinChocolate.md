# Using WinChocolate — one AppKit app, running on Windows

WinChocolate is an **AppKit-compatibility framework**: you write an ordinary
AppKit/Foundation app, and the *only* thing that changes to run it on Windows
(or Linux, via LinChocolate) is the **import header**. The promise is literally
"change the imports to run your app."

This guide covers the three things you actually have to know to make a real,
interactive app compile and run everywhere from a single source:

1. [The conditional import](#1-the-conditional-import--the-only-if) — the one and
   only `#if`.
2. [Actions](#2-actions--a-closure-onaction-over-real-targetaction) — a closure
   `onAction`, and how to get past the `@objc` / `#selector` problem.
3. [Outlets](#3-outlets--resolving-nib-controls-without-iboutlet) — wiring nib
   controls without `@IBOutlet`.

Plus a [bonus section](#4-bonus-delegate-closures-text-change-selection-double-click)
on delegate closures (text change, selection, double-click), which use the same
trick, and a closing note on [why this is legal](#5-the-rule--why-this-compiles-on-real-appkit-too).

Everything below is real code, taken from the demo apps in this repo
(`Demo/DemoApplication/DemoConveniences.swift`, `DemoNibConveniences.swift`).

---

## 1. The conditional import — the only `#if`

Your app source is shared verbatim across macOS, Windows and Linux. The single
conditional selects which framework the file is written against:

```swift
#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif
```

That is the *entire* platform seam. Every other line in the file runs once and
means the same thing on each target.

**Import exactly one framework per branch — not its Foundation partner too.**
Each framework re-exports the Foundation half you need:

- `import WinChocolate` also gives you `WinFoundation` (it is `@_exported`),
- `import AppKit` also gives you `Foundation`,
- `import LinChocolate` also gives you its Foundation.

So write `Date`, `URL`, `Data`, `Timer`, `NSObject`, `NSView`, `NSButton`, … with
no extra import. (Importing `WinFoundation` *alongside* `WinChocolate` pulls a
second `Timer`/`Date` into scope and makes them ambiguous — don't.)

**Rule of thumb:** a file that is shared across targets may contain **no other
`#if`** than the import switch above. If you find yourself reaching for
`#if os(Windows)` in app logic, stop — the two sections below exist precisely so
you don't have to.

---

## 2. Actions — a closure `onAction` over real `target`/`action`

### The problem

AppKit wires a control's action with the Objective-C runtime:

```swift
// Real AppKit — compiles on macOS, NOT on Windows/Linux.
@objc func activate(_ sender: Any?) { … }        // @objc: unsupported off Apple
button.target = self
button.action = #selector(activate(_:))          // #selector: does not compile
```

On the Windows/Linux Swift toolchains there is **no Objective-C runtime**, so
`@objc` and `#selector(...)` do not compile, and there is no runtime to resolve a
string selector `"activate:"` back to a method. A closure-first app needs another
way to receive actions — *without inventing a Windows-only API* (that would break
the "one source" promise).

### The insight

You don't need `@objc` if you **override a method that is already `@objc`**.
Overriding an inherited Objective-C method is implicitly `@objc` on Darwin — no
attribute appears in your source — and it's a plain Swift override that the
Chocolate frameworks dispatch through `NSResponder.perform(_:with:)`.

`NSResponder` already declares Apple's standard key-binding action methods
(`moveUp(_:)`, `moveDown(_:)`, … — no-op `(Any?) -> Void` methods that exist for
exactly this kind of selector dispatch). So the trampoline **subclasses
`NSResponder` and overrides two of them**, and a control's `action` is set to
those real selectors:

- macOS: the ObjC runtime dispatches `moveUp:` to the override.
- WinChocolate/LinChocolate: `NSResponder.perform(Selector("moveUp:"), with:)`
  routes the string selector to the same override by name.

One source, no platform seam.

### The trampoline

```swift
/// Receives a sender's real action selectors and forwards each to a stored
/// closure. One trampoline per sender (AppKit controls have a single `target`,
/// so `action` and `doubleAction` both land here, distinguished by selector).
final class DemoActionTarget: NSResponder {
    /// Keeps each sender's trampoline alive (targets are held weakly, as AppKit does).
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoActionTarget] = [:]

    /// Selector name → closure.
    var handlers: [String: @MainActor (Any?) -> Void] = [:]

    static func trampoline(for sender: NSObject) -> DemoActionTarget {
        if let existing = retained[ObjectIdentifier(sender)] {
            return existing
        }
        let created = DemoActionTarget()
        retained[ObjectIdentifier(sender)] = created
        return created
    }

    // Actions always arrive on the main thread, so hopping onto the main actor
    // here is a statement of fact, not a workaround. Note: NO `@objc` — these
    // are OVERRIDES of inherited @objc methods, which is implicitly @objc on Darwin.
    override func moveUp(_ sender: Any?) {
        nonisolated(unsafe) let sent = sender
        nonisolated(unsafe) let handler = handlers["moveUp:"]
        MainActor.assumeIsolated { handler?(sent) }
    }

    override func moveDown(_ sender: Any?) {
        nonisolated(unsafe) let sent = sender
        nonisolated(unsafe) let handler = handlers["moveDown:"]
        MainActor.assumeIsolated { handler?(sent) }
    }

    static let fireSelector = Selector(("moveUp:"))        // primary action
    static let doubleFireSelector = Selector(("moveDown:")) // double-click action
}
```

> **Why `moveUp:`/`moveDown:`?** They just need to be *inherited, `@objc`,
> `(Any?) -> Void` action selectors that nothing else will send this object.*
> The trampoline never joins a responder chain, so it never receives a real
> arrow-key `moveUp:`. Any two such selectors work; these are convenient.

### The `onAction` closure property

Setting `onAction` points the control's **real** `target`/`action` at the
trampoline:

```swift
extension NSControl {
    /// A closure action wired through the control's REAL `target`/`action`.
    @MainActor var onAction: (@MainActor (NSControl) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }
            let trampoline = DemoActionTarget.trampoline(for: self)
            trampoline.handlers["moveUp:"] = { [weak self] sender in
                if let control = (sender as? NSControl) ?? self {
                    newValue(control)
                }
            }
            target = trampoline
            action = DemoActionTarget.fireSelector
        }
    }
}
```

The identical shape works for `NSMenuItem` and `NSToolbarItem` (they also have
`target`/`action`) — just change the sender type in the extension.

### Using it

```swift
let button = NSButton(title: "Bump", frame: NSMakeRect(24, 24, 120, 32))
button.onAction = { _ in
    bumps += 1
    bumpsLabel.stringValue = "Bumps: \(bumps)"
}
content.addSubview(button)
```

A click on macOS goes: ObjC runtime → `moveUp:` override → your closure.
On Windows it goes: native click → framework `sendAction` →
`NSResponder.perform("moveUp:")` → the same override → your closure. You wrote it
once.

### Calling a named function or method

`onAction` is just a `(@MainActor (NSControl) -> Void)?`, so instead of an inline
closure you can hand it a **function or method** — the AppKit "the action calls a
method" shape, closure-first:

```swift
// A free function whose signature matches — assign it directly:
@MainActor func handleClick(_ sender: NSControl) {
    bumps += 1
    bumpsLabel.stringValue = "Bumps: \(bumps)"
}
button.onAction = handleClick

// A method on your controller (capture self weakly, as a target is held weakly):
button.onAction = { [weak self] sender in self?.rowTapped(sender) }

// A zero-argument function — ignore the sender:
button.onAction = { _ in refreshEverything() }

// Wire many controls to one handler and branch on the sender inside it:
for item in toolbarItems { item.onAction = handleToolbarAction }
```

### If you want the literal `target` / `action` = a method

Prefer AppKit's raw `target`/`action` pointing at a real method on your own
object (no `onAction` sugar)? Use the **same inherited-override trick** the
trampoline uses — override a standard action selector so the method is
selector-reachable with no `@objc`, and set `action` to that real selector:

```swift
/// Your own action target. Subclass NSResponder and override a standard action
/// method — an override of an inherited @objc method needs no attribute in
/// source, so it compiles (and dispatches) on every target.
final class ButtonHandler: NSResponder {
    override func moveUp(_ sender: Any?) {   // the action method — no @objc
        // … your action body …
    }
}

let handler = ButtonHandler()                // keep a strong reference: `target` is weak
button.target = handler
button.action = Selector("moveUp:")          // string selector; resolves on every target
```

On macOS the ObjC runtime sends `moveUp:` to `handler`; on Windows/Linux
`NSResponder.perform(Selector("moveUp:"), with:)` does. This is exactly what
`onAction` does internally — reach for it directly when you want a named action
method on a dedicated controller rather than the closure sugar. (The same applies
to `doubleAction`; use a second inherited selector such as `moveDown:`.)

---

## 3. Outlets — resolving nib controls without `@IBOutlet`

### The problem

`@IBOutlet` and `@IBAction` are `@objc`-backed and bound through the ObjC runtime
/ KVC during nib loading — none of which exists on Windows. A `DemoNibController`
with `@IBOutlet weak var nameField: NSTextField?` simply does not compile off
Apple.

### The approach

Instantiate the nib the normal AppKit way, then **find each control by its
Identity-inspector identifier** (`NSView.identifier`) — the manual-wiring pattern
AppKit apps have always been able to use in place of outlets. It's pure AppKit,
so the same code compiles on every target. Give each control an identifier in
Interface Builder (the Identity inspector's *Identifier* field); the demo's xib
uses `nibButton`, `nibField`, `nibCheck`, `nibSlider`, `nibPopup`, `nibCountLabel`,
`nibShowButton`.

The lookup is a depth-first search over the instantiated view tree:

```swift
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
```

Loading + wiring, all with real AppKit `NSNib`:

```swift
@MainActor
func installDemoNibPanel() {
    // AppKit instantiates only COMPILED nibs (run-mac.sh runs ibtool over the
    // xib); the Chocolate frameworks read the Interface Builder XML directly.
    // Same code path: take the compiled document when present, the source xib
    // otherwise — a file-presence check, not a platform check.
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

    // "Outlets": resolve each control by identifier instead of @IBOutlet.
    let countLabel = demoNibView("nibCountLabel", under: panel) as? NSTextField
    if let button = demoNibView("nibButton", under: panel) as? NSButton {
        // "Actions": wire it with the onAction closure from Section 2.
        button.onAction = { _ in
            demoNibIncrementCount += 1
            countLabel?.stringValue = "\(demoNibIncrementCount)"
        }
    }
    if let slider = demoNibView("nibSlider", under: panel) as? NSSlider {
        slider.onAction = { control in
            statusLabel.stringValue = "Nib slider: \((control as? NSSlider)?.doubleValue ?? 0)"
        }
    }
}
```

> **Note on `NSArray`.** `NSNib.instantiate(withOwner:topLevelObjects:)` takes an
> `inout NSArray?` out-parameter, matching AppKit's signature. WinFoundation
> aliases `NSArray = [Any]`, so `topLevel as? [Any]` bridges the same way on
> every target.
>
> **Note on the resource.** macOS loads a *compiled* `.nib` (Xcode/`ibtool`
> produces it); the Chocolate frameworks parse the `.xib` XML directly. The
> file-presence check above picks whichever is present — no `#if`.

So: **identifiers replace outlets, `onAction` replaces `@IBAction`.** No ObjC
runtime is touched, and the source is identical on Apple.

---

## 4. Bonus: delegate closures (text change, selection, double-click)

Controls that notify a *delegate* rather than fire a `target`/`action` (text
fields, tables, outlines, collections) use the same auto-exposure rule from
Section 2 — conforming an `NSObject` subclass to an Objective-C delegate protocol
auto-exposes its methods on Darwin, and the Chocolate frameworks declare the same
protocols as plain Swift. So a tiny delegate class forwards the one callback to a
closure:

```swift
/// A real NSTextFieldDelegate that forwards controlTextDidChange(_:) to a closure.
final class DemoTextChangeDelegate: NSObject, NSTextFieldDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoTextChangeDelegate] = [:]
    let handler: @MainActor (NSTextField) -> Void
    init(handler: @escaping @MainActor (NSTextField) -> Void) { self.handler = handler }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            nonisolated(unsafe) let sender = field
            nonisolated(unsafe) let handler = self.handler
            MainActor.assumeIsolated { handler(sender) }
        }
    }
}

extension NSTextField {
    /// An edit-change closure installed as the field's REAL delegate.
    @MainActor var onTextChanged: (@MainActor (NSTextField) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoTextChangeDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
                delegate = nil
                return
            }
            let d = DemoTextChangeDelegate(handler: newValue)
            DemoTextChangeDelegate.retained[ObjectIdentifier(self)] = d
            delegate = d
        }
    }
}
```

The demo ships the same pattern for `NSTableView.onSelectionChanged`,
`NSOutlineView.onOutlineSelectionChanged`, `NSCollectionView.onSelectionChanged`,
and `NSTextView.onTextChanged`. A **double-click** rides the trampoline's second
selector (`doubleAction` → `moveDown:`):

```swift
extension NSTableView {
    /// A double-click closure wired through the table's REAL doubleAction/target.
    @MainActor var onDoubleAction: (@MainActor (NSTableView) -> Void)? {
        get { nil }
        set {
            guard let newValue else { doubleAction = nil; return }
            let trampoline = DemoActionTarget.trampoline(for: self)
            trampoline.handlers["moveDown:"] = { [weak self] sender in
                if let table = (sender as? NSTableView) ?? self { newValue(table) }
            }
            target = trampoline
            doubleAction = DemoActionTarget.doubleFireSelector
        }
    }
}
```

Constraint (same as any hand-written AppKit target/delegate): a control using one
of these closures must not also need a different delegate.

---

## 5. The rule — why this compiles on real AppKit too

Put all of Section 2–4 in one **conveniences file** that's compiled into every
target (`DemoConveniences.swift` is exactly this). That file:

- carries **only** the import `#if` from Section 1 — no `#if os(Windows)`, no
  `@objc`-vs-`perform` branch;
- is **valid AppKit**: every construct (subclassing `NSResponder`, overriding
  `moveUp:`, conforming to `NSTextFieldDelegate`, `NSView.identifier`,
  `NSNib.instantiate`) compiles and behaves correctly on macOS against the real
  frameworks. On Apple the ObjC runtime does the dispatch; on the Chocolate
  frameworks `perform(_:with:)` / plain Swift protocol conformance does. The
  *source* is the same.

Your **app logic** (`main.swift` and friends) then reads like plain AppKit —
`button.onAction = { … }`, `demoNibView("nameField", under: panel)` — with the
sugar defined once in the conveniences file. That's the whole trick: the ObjC-only
mechanisms (`@objc`, `#selector`, `@IBOutlet`, `@IBAction`) never appear in your
source; they're replaced by *inherited-method overrides*, *string selectors*, and
*identifier lookups* — all of which are legitimate AppKit that happens to also
work with no Objective-C runtime.

> **The one anticipated exception:** KVO / KVC / Cocoa Bindings are Apple
> Objective-C-runtime technologies with no Windows equivalent. If a future need
> forces a per-backend seam there, it stays inside a conveniences file like this
> one — never in shared app logic.

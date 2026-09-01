// Demo-local convenience: a closure `onAction` that maps to a control's REAL
// `target`/`action`, plus framed initializers.
//
// The frameworks deliberately have no closure actions, so this sugar lives with
// the demo — which is what keeps ChocolateNoteDemo buildable against real Apple
// AppKit, the control group the other renderers are measured against.
//
// Everything here is built on primitives real AppKit has. Nothing in this file
// may reach for framework-only surface; if the demo needs something AppKit does
// not offer, that is a finding about the framework, not a licence to shim.
//
// This file is the SAME source in every Chocolate's copy of the demo.

#if canImport(TUIChocolate)
import TUIChocolate
#elseif os(WASI)
import WASMChocolate
#elseif os(Linux)
import LinChocolate
#elseif os(Windows)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

/// Holds a control's closure action and exposes it to target/action.
final class NoteDemoActionTarget: NSObject {
    /// Trampolines are retained here, keyed by their control, because a control
    /// holds its `target` weakly.
    @MainActor static var retained: [ObjectIdentifier: NoteDemoActionTarget] = [:]

    var handler: (@MainActor () -> Void)?

    // Real AppKit is the only target with an Objective-C runtime to dispatch
    // through. The `!canImport(TUIChocolate)` half matters: a terminal build is
    // also `os(macOS)`, but its `NSObject` is a plain Swift class, so `@objc`
    // and `#selector` would have nothing to attach to.
    #if os(macOS) && !canImport(TUIChocolate)
    @objc func fire(_ sender: Any?) {
        nonisolated(unsafe) let block = handler
        MainActor.assumeIsolated { block?() }
    }
    static let selector = #selector(NoteDemoActionTarget.fire(_:))
    #else
    // Everywhere else: the same dispatch without a runtime — the framework
    // sends the selector through `perform(_:with:)`, which this overrides by
    // name.
    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "fire:" || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "fire:" else {
            return super.perform(aSelector, with: object)
        }
        // Actions arrive on the UI thread, so assuming the main actor here is a
        // statement of fact.
        let block = handler
        MainActor.assumeIsolated { block?() }
        return nil
    }
    static let selector = Selector("fire:")
    #endif
}

extension NSControl {
    /// A closure action wired through the control's real `target`/`action`.
    @MainActor var onAction: (@MainActor () -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                NoteDemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }
            let trampoline = NoteDemoActionTarget.retained[ObjectIdentifier(self)] ?? {
                let created = NoteDemoActionTarget()
                NoteDemoActionTarget.retained[ObjectIdentifier(self)] = created
                return created
            }()
            trampoline.handler = newValue
            target = trampoline
            action = NoteDemoActionTarget.selector
        }
    }
}

extension NSButton {
    /// A titled button at an explicit frame (real `NSButton(title:target:action:)`
    /// plus a frame).
    @MainActor convenience init(title: String, frame: NSRect) {
        self.init(title: title, target: nil, action: nil)
        self.frame = frame
    }
}

extension NSTextField {
    /// A label at an explicit frame (real `labelWithString:` plus a frame).
    @MainActor convenience init(labelWithString string: String, frame: NSRect) {
        self.init(labelWithString: string)
        self.frame = frame
    }
}

extension NSMenuItem {
    /// A closure action wired through the item's real `target`/`action`.
    ///
    /// Separate from `NSControl.onAction` because `NSMenuItem` is not an
    /// `NSControl` — on Apple or here.
    @MainActor var onAction: (@MainActor () -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                NoteDemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }
            let trampoline = NoteDemoActionTarget.retained[ObjectIdentifier(self)] ?? {
                let created = NoteDemoActionTarget()
                NoteDemoActionTarget.retained[ObjectIdentifier(self)] = created
                return created
            }()
            trampoline.handler = newValue
            target = trampoline
            action = NoteDemoActionTarget.selector
        }
    }

    /// A menu item carrying a closure, at a key equivalent.
    @MainActor convenience init(title: String,
                                keyEquivalent: String,
                                handler: @escaping @MainActor () -> Void) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        self.onAction = handler
    }

    /// A menu item that sends a bare selector to whatever the responder chain
    /// finds — the shape every document action uses.
    ///
    /// No target on purpose. That is the whole point of the File menu in a
    /// document app: `saveDocument:` is answered by whichever document is in
    /// front, and the menu never has to know which.
    @MainActor convenience init(title: String,
                                selectorName: String,
                                keyEquivalent: String,
                                modifiers: NSEvent.ModifierFlags = [.command]) {
        self.init(title: title, action: Selector(selectorName), keyEquivalent: keyEquivalent)
        self.keyEquivalentModifierMask = modifiers
        self.target = nil
    }
}

extension NSMenu {
    /// Adds a separator, matching AppKit's factory spelling.
    @MainActor func addSeparator() {
        addItem(NSMenuItem.separator())
    }
}

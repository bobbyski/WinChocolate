// Demo-local convenience: a closure `onAction` that maps to a control's REAL
// `target`/`action`, plus framed initializers.
//
// The frameworks deliberately have no closure actions, so this sugar lives with
// the demo — which is what keeps CounterDemo buildable against real Apple
// AppKit, the control group the other renderers are measured against.
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
final class CounterDemoActionTarget: NSObject {
    /// Trampolines are retained here, keyed by their control, because a control
    /// holds its `target` weakly.
    @MainActor static var retained: [ObjectIdentifier: CounterDemoActionTarget] = [:]

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
    static let selector = #selector(CounterDemoActionTarget.fire(_:))
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
                CounterDemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }
            let trampoline = CounterDemoActionTarget.retained[ObjectIdentifier(self)] ?? {
                let created = CounterDemoActionTarget()
                CounterDemoActionTarget.retained[ObjectIdentifier(self)] = created
                return created
            }()
            trampoline.handler = newValue
            target = trampoline
            action = CounterDemoActionTarget.selector
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

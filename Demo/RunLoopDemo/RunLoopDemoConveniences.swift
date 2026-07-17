// Demo-local convenience: a closure `onAction` that maps to a control's REAL
// `target`/`action`, plus framed initializers. All of it is AppKit-compatible —
// on macOS the closure is dispatched by the Objective-C runtime through a
// genuine `@objc` action method and `#selector`; on WinChocolate/LinChocolate,
// which have no ObjC runtime, the framework routes the same selector through
// `NSObject.perform(_:with:)`, which this trampoline overrides by name. The one
// `#if` here does the only thing the rule allows: switch between AppKit and the
// Chocolate frameworks. (Same arrangement as DemoApplication/DemoConveniences.)

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

/// Holds a control's closure action and exposes it to target/action.
final class RunLoopDemoActionTarget: NSObject {
    /// Trampolines are retained here, keyed by their control, because a control
    /// holds its `target` weakly.
    @MainActor static var retained: [ObjectIdentifier: RunLoopDemoActionTarget] = [:]

    var handler: (@MainActor () -> Void)?

    #if canImport(AppKit) && !canImport(WinChocolate) && !canImport(LinChocolate)
    // Real AppKit: a genuine Objective-C action method the runtime dispatches.
    @objc func fire(_ sender: Any?) {
        nonisolated(unsafe) let block = handler
        MainActor.assumeIsolated { block?() }
    }
    static let selector = #selector(RunLoopDemoActionTarget.fire(_:))
    #else
    // WinChocolate/LinChocolate: the same dispatch without an ObjC runtime —
    // the framework sends the selector through `perform(_:with:)`.
    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "fire:" || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "fire:" else {
            return super.perform(aSelector, with: object)
        }
        // Actions arrive on the UI thread; the unsafe copy hops the @MainActor
        // handler across the nonisolated override, as DemoConveniences does.
        nonisolated(unsafe) let block = handler
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
                RunLoopDemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }
            let trampoline = RunLoopDemoActionTarget.retained[ObjectIdentifier(self)] ?? {
                let created = RunLoopDemoActionTarget()
                RunLoopDemoActionTarget.retained[ObjectIdentifier(self)] = created
                return created
            }()
            trampoline.handler = newValue
            target = trampoline
            action = RunLoopDemoActionTarget.selector
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

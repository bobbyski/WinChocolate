// Phase 16 — macOS cross-check shims.
//
// On Windows this file is empty: the demo's conveniences (`onAction`,
// `onDoubleAction`, `onTextChanged`, …) are WinChocolate API. On macOS the
// demo builds against the real AppKit, and this file re-expresses those
// conveniences over target/action so the *same demo source* runs on both —
// the whole point of the cross-check is comparing renderings of an
// identical app. The shim set grows with 16.2 as more of main.swift is
// brought under the seam; it is compile-verified on a Mac (the Windows CI
// only proves the Windows side unaffected).
#if os(macOS)
import AppKit

/// Bridges AppKit's target/action to the closure-based `onAction` the demo
/// uses throughout (WinChocolate's Swift-native convenience).
final class DemoActionTrampoline: NSObject {
    static var trampolines: [ObjectIdentifier: DemoActionTrampoline] = [:]
    let handler: (NSControl) -> Void

    init(handler: @escaping (NSControl) -> Void) {
        self.handler = handler
    }

    @objc func fire(_ sender: NSControl) {
        handler(sender)
    }
}

extension NSControl {
    /// WinChocolate's closure action, expressed over target/action.
    var onAction: ((NSControl) -> Void)? {
        get { DemoActionTrampoline.trampolines[ObjectIdentifier(self)]?.handler }
        set {
            guard let newValue else {
                DemoActionTrampoline.trampolines.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }
            let trampoline = DemoActionTrampoline(handler: newValue)
            DemoActionTrampoline.trampolines[ObjectIdentifier(self)] = trampoline
            target = trampoline
            action = #selector(DemoActionTrampoline.fire(_:))
        }
    }
}
#endif

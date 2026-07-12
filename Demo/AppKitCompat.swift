// AppKit compatibility shim — active ONLY when the demo is built against real
// Apple AppKit (not WinChocolate/LinChocolate). It re-adds the AppKit-shaped
// ergonomic conveniences both frameworks provide (frame-based initializers,
// closure actions, a few helper properties) on top of Apple's own types, so the
// single shared demo source compiles unmodified against genuine AppKit — the
// ground-truth compatibility proof (WinChocolate plan: AppKit target).
#if canImport(AppKit) && !canImport(WinChocolate) && !canImport(LinChocolate)
import AppKit

// MARK: - Frame-based initializers (WinChocolate/LinChocolate convenience)

public extension NSButton {
    convenience init(title: String, frame: NSRect) {
        self.init(frame: frame); self.title = title; self.bezelStyle = .rounded
    }
    convenience init(checkboxWithTitle title: String, frame: NSRect) {
        self.init(checkboxWithTitle: title, target: nil, action: nil); self.frame = frame
    }
    convenience init(radioWithTitle title: String, frame: NSRect) {
        self.init(radioButtonWithTitle: title, target: nil, action: nil); self.frame = frame
    }
}

public extension NSTextField {
    convenience init(string: String, frame: NSRect) {
        self.init(frame: frame); self.stringValue = string
    }
    convenience init(labelWithString string: String, frame: NSRect) {
        self.init(labelWithString: string); self.frame = frame
    }
}
#endif
